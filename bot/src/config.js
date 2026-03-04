const fs = require('fs');
const path = require('path');

function loadEnv() {
  const envPath = path.join(__dirname, '..', '.env');
  if (!fs.existsSync(envPath)) {
    console.error('.env 파일이 없습니다. .env.example을 복사하여 .env를 생성하세요:');
    console.error('  cp .env.example .env');
    process.exit(1);
  }

  const content = fs.readFileSync(envPath, 'utf-8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const eqIndex = trimmed.indexOf('=');
    if (eqIndex === -1) continue;

    const key = trimmed.substring(0, eqIndex);
    const value = trimmed.substring(eqIndex + 1);

    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

function validateEnv(required) {
  for (const key of required) {
    if (!process.env[key]) {
      console.error(`필수 환경 변수 누락: ${key}`);
      console.error('.env 파일을 확인하세요.');
      process.exit(1);
    }
  }
}

loadEnv();
validateEnv(['SLACK_BOT_TOKEN', 'SLACK_APP_TOKEN', 'ATLASSIAN_SITE', 'JIRA_PROJECT_KEY']);

module.exports = {
  slack: {
    botToken: process.env.SLACK_BOT_TOKEN,
    appToken: process.env.SLACK_APP_TOKEN,
    channelId: process.env.SLACK_CHANNEL_ID || null,
    triggerEmoji: process.env.TRIGGER_EMOJI || 'robot_face',
  },
  atlassian: {
    site: process.env.ATLASSIAN_SITE,
    browseUrl: `https://${process.env.ATLASSIAN_SITE}/browse`,
    wikiUrl: `https://${process.env.ATLASSIAN_SITE}/wiki`,
  },
  jira: {
    projectKey: process.env.JIRA_PROJECT_KEY,
  },
  claude: {
    workDir: process.env.CLAUDE_WORK_DIR || process.cwd(),
    maxTurnsTicket: parseInt(process.env.CLAUDE_MAX_TURNS_TICKET) || 25,
    maxTurnsAnalysis: parseInt(process.env.CLAUDE_MAX_TURNS_ANALYSIS) || 25,
  },
};
