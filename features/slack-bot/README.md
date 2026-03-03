# Slack 워크플로우 봇

Slack 메시지를 감지하여 자동으로 Jira 티켓을 생성하거나 AI 분석을 실행한다.

## 기능

- **Slack Workflow Form 감지**: 특정 채널에 Form 메시지 게시 → 자동 티켓 생성
- **이모지 트리거**: 기존 메시지에 🤖 이모지 추가 → 자동 AI 분석
- **SwiftBar 상태 표시**: 메뉴바에서 봇 실행 상태 확인 + 시작/중지 제어

## 요구사항

- Node.js 18+
- Slack 앱 (Socket Mode 사용)
- Jira/Confluence 워크플로우 기능 설정 완료 (선행 조건)

## 설치

### 1. Slack 앱 생성

1. https://api.slack.com/apps 에서 새 앱 생성
2. Socket Mode 활성화
3. Event Subscriptions에서 구독:
   - `message.channels`
   - `reaction_added`
4. Bot Token Scopes:
   - `chat:write`, `reactions:read`, `reactions:write`
   - `im:write` (DM 발송)
   - `users:read`, `users:read.email`
5. Bot Token (`xoxb-...`)과 App-Level Token (`xapp-...`) 복사

### 2. 환경변수 설정

```bash
cp bot/.env.example bot/.env
```

`bot/.env` 필수 항목:

```
SLACK_BOT_TOKEN=xoxb-...
SLACK_APP_TOKEN=xapp-...
ATLASSIAN_SITE=your-company.atlassian.net
JIRA_PROJECT_KEY=MYPROJECT
```

### 3. 의존성 설치

```bash
cd bot && npm install
```

### 4. SwiftBar 플러그인 설치 (선택)

```bash
ln -s "$(pwd)/swiftbar/workflow-bot.5s.sh" ~/SwiftBar/workflow-bot.5s.sh
```

메뉴바에서 봇 시작/중지/재시작 가능.

### 5. 봇 시작

```bash
bash bot/scripts/start-bot.sh
```

## 트리거 형식

### Slack Workflow Form

```
📋 요청사항
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
유형 :  기능 추가
제목 : 기능명
우선순위 : 🟡 보통
관련 화면 : 화면명
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
상세 설명
...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
요청자 : @홍길동
담당자 : @이한상
```

### 이모지 트리거

생성된 티켓 메시지에 🤖 이모지 추가 → AI 분석 자동 시작
