const { isFormMessage, parseFormMessage, buildTicketPrompt } = require('./parser');
const claude = require('./claude');

const SCAN_HOURS = parseInt(process.env.STARTUP_SCAN_HOURS) || 24;
const SCAN_LIMIT = parseInt(process.env.STARTUP_SCAN_LIMIT) || 100;

/**
 * 봇 시작 시 미처리 Form 메시지 스캔 및 재처리
 *
 * 판단 기준: Form 메시지인데 ticket 이모지가 없고 스레드에 티켓 번호도 없음
 */
async function scanUnprocessed(client, config) {
  const channelId = config.slack.channelId;
  const projectKey = config.jira.projectKey;
  const ticketPattern = new RegExp(`${projectKey}-\\d+`);

  if (!channelId) {
    console.log('[startup] SLACK_CHANNEL_ID 미설정, 스캔 건너뜀');
    return;
  }

  console.log(`[startup] 미처리 메시지 스캔 시작 (최근 ${SCAN_HOURS}시간, 최대 ${SCAN_LIMIT}개)`);

  const oldest = Math.floor(Date.now() / 1000) - SCAN_HOURS * 3600;
  let messages = [];
  try {
    const result = await client.conversations.history({
      channel: channelId,
      oldest: String(oldest),
      limit: SCAN_LIMIT,
    });
    messages = result.messages || [];
  } catch (err) {
    console.error(`[startup] 채널 메시지 조회 실패: ${err.message}`);
    return;
  }

  // Form 메시지 + ticket 이모지 없는 것만 필터
  const candidates = [];
  for (const msg of messages) {
    if (!msg.text || !isFormMessage(msg.text)) continue;
    if (msg.thread_ts && msg.thread_ts !== msg.ts) continue; // 스레드 답글 제외

    const reactionNames = (msg.reactions || []).map((r) => r.name);
    if (reactionNames.includes('ticket')) continue; // 이미 처리됨

    candidates.push(msg);
  }

  if (candidates.length === 0) {
    console.log('[startup] 미처리 메시지 없음');
    return;
  }

  // 스레드까지 확인해서 실제 미처리 걸러내기
  const unprocessed = [];
  for (const msg of candidates) {
    let hasTicket = false;
    try {
      const replies = await client.conversations.replies({ channel: channelId, ts: msg.ts });
      hasTicket = (replies.messages || []).some((r) => ticketPattern.test(r.text || ''));
    } catch (_) {}

    if (!hasTicket) {
      unprocessed.push(msg);
    }
  }

  if (unprocessed.length === 0) {
    console.log('[startup] 미처리 메시지 없음 (스레드 확인 후)');
    return;
  }

  console.log(`[startup] 미처리 메시지 ${unprocessed.length}개 발견, 재처리 시작`);

  for (const msg of unprocessed) {
    const parsed = parseFormMessage(msg.text);
    if (!parsed || !parsed.title) continue;

    console.log(`[startup] 재처리: "${parsed.title}" (ts=${msg.ts})`);

    // x 이모지 제거 + 처리 중 이모지
    try { await client.reactions.remove({ channel: channelId, timestamp: msg.ts, name: 'x' }); } catch (_) {}
    try { await client.reactions.add({ channel: channelId, timestamp: msg.ts, name: 'hourglass_flowing_sand' }); } catch (_) {}

    try {
      const prompt = buildTicketPrompt(parsed, {
        jiraProjectKey: config.jira.projectKey,
        atlassianSite: config.atlassian.site,
        slackChannel: channelId,
        slackTs: msg.ts,
      });
      await claude.runTicketCreation(prompt);

      try {
        await client.reactions.remove({ channel: channelId, timestamp: msg.ts, name: 'hourglass_flowing_sand' });
        await client.reactions.add({ channel: channelId, timestamp: msg.ts, name: 'ticket' });
      } catch (_) {}

      console.log(`[startup] 재처리 완료: "${parsed.title}"`);
    } catch (err) {
      console.error(`[startup] 재처리 실패: "${parsed.title}" — ${err.message}`);
      try {
        await client.reactions.remove({ channel: channelId, timestamp: msg.ts, name: 'hourglass_flowing_sand' });
        await client.reactions.add({ channel: channelId, timestamp: msg.ts, name: 'x' });
      } catch (_) {}
    }
  }

  console.log('[startup] 스캔 완료');
}

module.exports = { scanUnprocessed, SCAN_HOURS, SCAN_LIMIT };
