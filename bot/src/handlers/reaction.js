const { buildAnalysisPrompt } = require('../services/parser');
const { runAnalysis } = require('../services/claude');
const { notify } = require('../services/notify');

/**
 * 이모지 반응 핸들러
 * 🤖 이모지가 추가되면 분석 워크플로우 실행
 */
function register(app, config) {
  const targetChannelId = config.slack.channelId;
  const triggerEmoji = config.slack.triggerEmoji;

  app.event('reaction_added', async ({ event, client, logger }) => {
    // 트리거 이모지가 아니면 무시
    if (event.reaction !== triggerEmoji) return;

    // 대상 채널인지 확인 (채널 ID로 비교)
    if (targetChannelId && event.item.channel !== targetChannelId) return;

    const messageTs = event.item.ts;
    const channelId = event.item.channel;
    const triggeredByUserId = event.user;

    logger.info(`🤖 이모지 감지: user=${triggeredByUserId}, message=${messageTs}`);

    // 이모지 추가한 사용자 정보 조회
    let triggeredByName = triggeredByUserId;
    try {
      const userInfo = await client.users.info({ user: triggeredByUserId });
      triggeredByName = userInfo.user.real_name || userInfo.user.name;
    } catch (err) {
      logger.warn(`사용자 정보 조회 실패: ${err.message}`);
    }

    // 스레드에서 티켓 번호 찾기 (Bot이 회신한 {PROJECT_KEY}-XXX)
    const projectKey = config.jira.projectKey;
    const ticketPattern = new RegExp(`${projectKey}-\\d+`);
    let ticketKey = null;
    try {
      const replies = await client.conversations.replies({
        channel: channelId,
        ts: messageTs,
      });

      for (const reply of replies.messages || []) {
        const match = reply.text?.match(ticketPattern);
        if (match) {
          ticketKey = match[0];
          break;
        }
      }
    } catch (err) {
      logger.error(`스레드 조회 실패: ${err.message}`);
    }

    if (!ticketKey) {
      await client.chat.postMessage({
        channel: channelId,
        thread_ts: messageTs,
        text: '이 메시지에 연결된 Jira 티켓을 찾을 수 없습니다. 먼저 티켓이 생성되어야 합니다.',
      });
      return;
    }

    // 이미 분석이 진행 중인지 확인 (⏳ 이모지 존재 여부)
    try {
      const reactions = await client.reactions.get({
        channel: channelId,
        timestamp: messageTs,
      });

      const hasHourglass = reactions.message?.reactions?.some(
        (r) => r.name === 'hourglass_flowing_sand'
      );
      if (hasHourglass) {
        logger.info('이미 분석 진행 중, 건너뜀');
        return;
      }
    } catch (err) {
      logger.debug(`이모지 조회 실패 (무시): ${err.message}`);
    }

    // 처리 중 표시
    try {
      await client.reactions.add({
        channel: channelId,
        timestamp: messageTs,
        name: 'hourglass_flowing_sand',
      });
    } catch (err) {
      logger.debug(`이모지 추가 실패 (무시): ${err.message}`);
    }

    // Claude 분석 실행
    try {
      const prompt = buildAnalysisPrompt(ticketKey, triggeredByName);
      logger.info(`claude -p 실행: 분석 (${ticketKey})`);

      const result = await runAnalysis(prompt);

      // Confluence 문서 링크 추출
      const wikiUrlEscaped = config.atlassian.wikiUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const confluenceMatch = result.result?.match(
        new RegExp(`${wikiUrlEscaped}/[^\\s)]+`)
      );
      const confluenceLink = confluenceMatch ? confluenceMatch[0] : null;

      // 스레드에 결과 회신
      let replyText = `*${ticketKey}* 분석이 완료되었습니다.`;
      if (confluenceLink) {
        replyText += `\n분석 문서: ${confluenceLink}`;
      }

      await client.chat.postMessage({
        channel: channelId,
        thread_ts: messageTs,
        text: replyText,
      });

      // 처리 완료 이모지
      await client.reactions.remove({
        channel: channelId,
        timestamp: messageTs,
        name: 'hourglass_flowing_sand',
      });
      await client.reactions.add({
        channel: channelId,
        timestamp: messageTs,
        name: 'robot_face',
      });

      notify('Workflow Bot', `${ticketKey} 분석 완료`);
      logger.info(`분석 완료: ${ticketKey}`);
    } catch (err) {
      notify('Workflow Bot', `${ticketKey} 분석 실패: ${err.message.substring(0, 100)}`);
      logger.error(`분석 실패: ${err.message}`);

      try {
        await client.reactions.remove({
          channel: channelId,
          timestamp: messageTs,
          name: 'hourglass_flowing_sand',
        });
        await client.reactions.add({
          channel: channelId,
          timestamp: messageTs,
          name: 'x',
        });
      } catch (err) {
        logger.debug(`에러 이모지 변경 실패 (무시): ${err.message}`);
      }

      await client.chat.postMessage({
        channel: channelId,
        thread_ts: messageTs,
        text: `분석 중 오류가 발생했습니다: ${err.message}`,
      });
    }
  });
}

module.exports = { register };
