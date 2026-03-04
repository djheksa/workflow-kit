const { isFormMessage, parseFormMessage, buildTicketPrompt } = require('../services/parser');
const { runTicketCreation } = require('../services/claude');
const { notify } = require('../services/notify');

/**
 * 메시지 핸들러
 * 대상 채널의 Slack Workflow Form 메시지를 감지하여 티켓 생성
 */
function register(app, config) {
  const targetChannelId = config.slack.channelId;

  app.event('message', async ({ event, client, logger }) => {
    logger.info(`[메시지 수신] channel=${event.channel} subtype=${event.subtype || 'none'} text=${event.text?.substring(0, 50) || '(없음)'}`);

    // 수정된 메시지, 스레드 답글은 무시 (봇 메시지는 Workflow Form일 수 있으므로 허용)
    if (event.subtype && event.subtype !== 'bot_message') return;
    if (event.thread_ts && event.thread_ts !== event.ts) return;

    // 대상 채널인지 확인 (채널 ID로 비교)
    if (targetChannelId && event.channel !== targetChannelId) return;

    // Form 메시지인지 확인
    const text = event.text || '';
    if (!isFormMessage(text)) return;

    logger.info(`Form 메시지 감지: ${event.ts}`);

    // 파싱
    const parsed = parseFormMessage(text);
    if (!parsed || !parsed.title) {
      logger.warn('Form 파싱 실패, 건너뜀');
      return;
    }

    // 처리 중 표시 (이모지)
    try {
      await client.reactions.add({
        channel: event.channel,
        timestamp: event.ts,
        name: 'hourglass_flowing_sand',
      });
    } catch (err) {
      logger.debug(`이모지 추가 실패 (무시): ${err.message}`);
    }

    // Claude 실행 (스레드 댓글 + DM까지 Claude가 직접 처리)
    try {
      const prompt = buildTicketPrompt(parsed, {
        jiraProjectKey: config.jira.projectKey,
        atlassianSite: config.atlassian.site,
        slackChannel: event.channel,
        slackTs: event.ts,
      });
      logger.info(`claude -p 실행: 티켓 생성 (${parsed.title})`);

      await runTicketCreation(prompt);

      // 처리 완료 이모지
      try {
        await client.reactions.remove({ channel: event.channel, timestamp: event.ts, name: 'hourglass_flowing_sand' });
        await client.reactions.add({ channel: event.channel, timestamp: event.ts, name: 'ticket' });
      } catch (err) {
        logger.debug(`이모지 변경 실패 (무시): ${err.message}`);
      }

      notify('Workflow Bot', `티켓 생성 완료`);
      logger.info(`티켓 생성 완료: ${parsed.title}`);
    } catch (err) {
      notify('Workflow Bot', `티켓 생성 실패: ${err.message.substring(0, 100)}`);
      logger.error(`티켓 생성 실패: ${err.message}`);

      // 에러 이모지 (스코프 없으면 무시)
      try {
        await client.reactions.remove({ channel: event.channel, timestamp: event.ts, name: 'hourglass_flowing_sand' });
        await client.reactions.add({ channel: event.channel, timestamp: event.ts, name: 'x' });
      } catch (err) {
        logger.debug(`에러 이모지 변경 실패 (무시): ${err.message}`);
      }

      // 스레드에 에러 회신
      try {
        await client.chat.postMessage({
          channel: event.channel,
          thread_ts: event.ts,
          text: `티켓 생성 중 오류가 발생했습니다: ${err.message}`,
        });
      } catch (err) {
        logger.debug(`에러 회신 실패 (무시): ${err.message}`);
      }
    }
  });
}

module.exports = { register };
