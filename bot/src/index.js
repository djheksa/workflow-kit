const fs = require('fs');
const path = require('path');
const { App } = require('@slack/bolt');
const config = require('./config');

// Slack App 초기화 (Socket Mode)
const app = new App({
  token: config.slack.botToken,
  appToken: config.slack.appToken,
  socketMode: true,
});

// handlers/ 디렉토리의 모든 핸들러를 자동 등록
const handlersDir = path.join(__dirname, 'handlers');
const handlerFiles = fs.readdirSync(handlersDir).filter((f) => f.endsWith('.js'));

for (const file of handlerFiles) {
  const handler = require(path.join(handlersDir, file));
  // register 함수가 있으면 호출
  if (typeof handler.register === 'function') {
    handler.register(app, config);
    console.log(`  핸들러 등록: ${file}`);
  }
}

// 시작
(async () => {
  await app.start();

  // Socket Mode 연결 모니터링
  const socketClient = app.receiver?.client;
  if (socketClient) {
    socketClient.on('connected', () => {
      console.log('[socket] 연결됨');
    });
    socketClient.on('connecting', () => {
      console.log('[socket] 재연결 시도 중...');
    });
    socketClient.on('disconnected', () => {
      console.warn('[socket] 연결 끊김 — 자동 재연결 대기');
    });
    socketClient.on('error', (err) => {
      console.error(`[socket] 오류: ${err.message}`);
    });
    socketClient.on('close', () => {
      console.warn('[socket] WebSocket 종료');
    });
  }

  console.log('========================================');
  console.log('Workflow Bot 시작됨');
  console.log(`  채널 ID: ${config.slack.channelId || '(미설정 - 모든 채널 감시)'}`);
  console.log(`  분석 트리거 이모지: :${config.slack.triggerEmoji}:`);
  console.log(`  Claude 작업 디렉토리: ${config.claude.workDir}`);
  console.log(`  등록된 핸들러: ${handlerFiles.length}개`);
  console.log('========================================');
})();
