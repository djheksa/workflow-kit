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

    // Claude 실행
    try {
      const prompt = buildTicketPrompt(parsed);
      logger.info(`claude -p 실행: 티켓 생성 (${parsed.title})`);

      const result = await runTicketCreation(prompt);

      // 티켓 번호 추출 (프로젝트 키 기반 동적 매칭)
      const projectKey = config.jira.projectKey;
      const ticketPattern = new RegExp(`${projectKey}-\\d+`);
      const ticketMatch = result.result?.match(ticketPattern);
      const ticketKey = ticketMatch ? ticketMatch[0] : null;

      // 스레드에 결과 회신
      let replyText = '';
      if (ticketKey) {
        replyText = `티켓 생성 완료: ${ticketKey}\n${config.atlassian.browseUrl}/${ticketKey}`;
      } else {
        replyText = `티켓 생성이 완료되었습니다.\n\n${result.result?.substring(0, 500) || '(결과 없음)'}`;
      }

      await client.chat.postMessage({
        channel: event.channel,
        thread_ts: event.ts,
        text: replyText,
      });

      // 처리 완료 이모지 (스코프 없으면 무시)
      try {
        await client.reactions.remove({ channel: event.channel, timestamp: event.ts, name: 'hourglass_flowing_sand' });
        await client.reactions.add({ channel: event.channel, timestamp: event.ts, name: 'ticket' });
      } catch (err) {
        logger.debug(`이모지 변경 실패 (무시): ${err.message}`);
      }

      notify('Workflow Bot', `티켓 생성 완료: ${ticketKey || '(번호 미확인)'}`);
      logger.info(`티켓 생성 완료: ${ticketKey || '(번호 미확인)'}`);
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
