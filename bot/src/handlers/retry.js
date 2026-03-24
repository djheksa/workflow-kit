const { isFormMessage, parseFormMessage, buildTicketPrompt } = require('../services/parser');
const { runTicketCreation } = require('../services/claude');
const { notify } = require('../services/notify');

const RETRY_EMOJI = process.env.RETRY_EMOJI || 'arrows_counterclockwise';

/**
 * 재시도 핸들러
 * 🔄 이모지가 추가되면 티켓 미생성 Form 메시지를 재처리
 */
function register(app, config) {
  const targetChannelId = config.slack.channelId;
  const projectKey = config.jira.projectKey;
  const ticketPattern = new RegExp(`${projectKey}-\\d+`);

  app.event('reaction_added', async ({ event, client, logger }) => {
    if (event.reaction !== RETRY_EMOJI) return;
    if (targetChannelId && event.item.channel !== targetChannelId) return;

    const messageTs = event.item.ts;
    const channelId = event.item.channel;

    logger.info(`🔄 재시도 이모지 감지: message=${messageTs}`);

    // 메시지 원문 조회
    let messageText = null;
    try {
      const history = await client.conversations.history({
        channel: channelId,
        latest: messageTs,
        oldest: messageTs,
        inclusive: true,
        limit: 1,
      });
      messageText = history.messages?.[0]?.text;
    } catch (err) {
      logger.error(`메시지 조회 실패: ${err.message}`);
      return;
    }

    // Form 메시지인지 확인
    if (!messageText || !isFormMessage(messageText)) {
      await client.chat.postMessage({
        channel: channelId,
        thread_ts: messageTs,
        text: '이 메시지는 티켓 Form 메시지가 아닙니다.',
      });
      return;
    }

    // ticket 이모지 있으면 이미 생성됨
    try {
      const reactions = await client.reactions.get({ channel: channelId, timestamp: messageTs });
      const names = reactions.message?.reactions?.map((r) => r.name) || [];
      if (names.includes('ticket')) {
        await client.chat.postMessage({
          channel: channelId,
          thread_ts: messageTs,
          text: '이미 Jira 티켓이 생성된 메시지입니다.',
        });
        return;
      }
    } catch (err) {
      logger.debug(`이모지 조회 실패 (무시): ${err.message}`);
    }

    // 스레드에 티켓 번호 있는지 확인
    try {
      const replies = await client.conversations.replies({ channel: channelId, ts: messageTs });
      const alreadyExists = (replies.messages || []).some((r) => ticketPattern.test(r.text));
      if (alreadyExists) {
        await client.chat.postMessage({
          channel: channelId,
          thread_ts: messageTs,
          text: '이미 Jira 티켓이 생성된 메시지입니다. (스레드에서 티켓 번호 확인됨)',
        });
        return;
      }
    } catch (err) {
      logger.debug(`스레드 조회 실패 (무시): ${err.message}`);
    }

    // 파싱
    const parsed = parseFormMessage(messageText);
    if (!parsed || !parsed.title) {
      logger.warn('Form 파싱 실패');
      await client.chat.postMessage({
        channel: channelId,
        thread_ts: messageTs,
        text: 'Form 메시지 파싱에 실패했습니다.',
      });
      return;
    }

    // 재시도 이모지 제거 + x 이모지 제거 + 처리 중 이모지
    try { await client.reactions.remove({ channel: channelId, timestamp: messageTs, name: RETRY_EMOJI }); } catch (_) {}
    try { await client.reactions.remove({ channel: channelId, timestamp: messageTs, name: 'x' }); } catch (_) {}
    try { await client.reactions.add({ channel: channelId, timestamp: messageTs, name: 'hourglass_flowing_sand' }); } catch (_) {}

    // 티켓 생성
    try {
      const prompt = buildTicketPrompt(parsed, {
        jiraProjectKey: config.jira.projectKey,
        atlassianSite: config.atlassian.site,
        slackChannel: channelId,
        slackTs: messageTs,
      });
      logger.info(`claude -p 실행: 티켓 재생성 (${parsed.title})`);
      await runTicketCreation(prompt);

      try {
        await client.reactions.remove({ channel: channelId, timestamp: messageTs, name: 'hourglass_flowing_sand' });
        await client.reactions.add({ channel: channelId, timestamp: messageTs, name: 'ticket' });
      } catch (_) {}

      notify('Workflow Bot', `티켓 재생성 완료: ${parsed.title}`);
      logger.info(`티켓 재생성 완료: ${parsed.title}`);
    } catch (err) {
      notify('Workflow Bot', `티켓 재생성 실패: ${err.message.substring(0, 100)}`);
      logger.error(`티켓 재생성 실패: ${err.message}`);
      try {
        await client.reactions.remove({ channel: channelId, timestamp: messageTs, name: 'hourglass_flowing_sand' });
        await client.reactions.add({ channel: channelId, timestamp: messageTs, name: 'x' });
      } catch (_) {}
      await client.chat.postMessage({
        channel: channelId,
        thread_ts: messageTs,
        text: `티켓 재생성 중 오류가 발생했습니다: ${err.message}`,
      });
    }
  });
}

module.exports = { register, RETRY_EMOJI };
