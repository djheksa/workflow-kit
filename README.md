# Workflow Kit

Claude Code를 사용한 요청 분석 및 티켓 생성 워크플로우 도구입니다.

## 빠른 시작

1. 이 저장소를 클론합니다
   ```bash
   git clone <repo-url>
   cd workflow-kit
   ```
2. 로컬 설정 파일을 생성합니다
   ```bash
   cp .claude.local.md.example .claude.local.md
   ```
3. `.claude.local.md`를 열어 자신의 환경에 맞게 수정합니다
   - 백엔드/프론트엔드 프로젝트 경로
   - Atlassian 사이트 URL 및 이메일
   - Jira 프로젝트 키, Confluence 스페이스 키
4. Atlassian MCP를 설정합니다 (아래 참조)
5. (봇 사용 시) 봇 환경변수를 설정합니다
   ```bash
   cd bot
   cp .env.example .env
   # .env 파일을 열어 필수 값 입력
   ```
6. 해당 디렉토리에서 Claude Code를 실행합니다
   ```bash
   claude
   ```

## 사전 요구사항

- Claude Code 설치
- Atlassian MCP 설정 (Jira/Confluence 연동)
- Slack MCP 설정 (알림 발송)

자세한 설정 방법은 [CLAUDE.md](./CLAUDE.md)를 참조하세요.

## 봇 환경변수 (Slack Bot 사용 시)

`bot/.env.example`을 `bot/.env`로 복사한 후 아래 필수 값을 입력하세요:

| 환경변수 | 필수 | 설명 |
|---------|------|------|
| `SLACK_BOT_TOKEN` | O | Slack Bot Token (`xoxb-...`) |
| `SLACK_APP_TOKEN` | O | Slack App-Level Token (`xapp-...`, Socket Mode용) |
| `ATLASSIAN_SITE` | O | Atlassian 사이트 URL (예: `your-company.atlassian.net`) |
| `JIRA_PROJECT_KEY` | O | Jira 프로젝트 키 (예: `MYPROJECT`) |
| `SLACK_CHANNEL_ID` | - | 감시할 Slack 채널 ID |
| `TRIGGER_EMOJI` | - | 분석 트리거 이모지 (기본: `robot_face`) |
| `CLAUDE_WORK_DIR` | - | `claude -p` 실행 시 작업 디렉토리 |
| `CLAUDE_MAX_TURNS_TICKET` | - | 티켓 생성 최대 턴 수 (기본: 15) |
| `CLAUDE_MAX_TURNS_ANALYSIS` | - | 분석 최대 턴 수 (기본: 25) |

## 파일 구조

| 파일 | 용도 | Git 추적 |
|------|------|---------|
| `CLAUDE.md` | 워크플로우 정의, 템플릿 | O |
| `.claude.local.md.example` | 로컬 설정 템플릿 | O |
| `.claude.local.md` | 사용자별 로컬 설정 (경로, 계정, 프로젝트 키) | X |
| `.claude/rules/confluence.md` | Confluence 문서 작업 규칙 | O |
| `.claude/rules/agent-strategy.md` | 에이전트 모델 전략 | O |
| `.claude/settings.local.json` | Claude Code 권한 설정 | X |

## 워크플로우

### 1. 요청 분석 → 티켓/문서 생성

```
요청 분석해줘

요청 유형: 버그
제목: 계약 상태 변경 시 오류 발생
설명: ...
우선순위: 높음
관련 화면: 계약관리
요청자: 홍길동
```

### 2. 코드베이스 분석

```
코드 분석해줘

분석 대상: 계약 상태 일괄 변경 기능
분석 범위: 백엔드
```

## 연동 대상

연동 대상은 `.claude.local.md`에서 설정합니다:

| 항목 | 설정 위치 | 설명 |
|------|-----------|------|
| Jira 프로젝트 | `.claude.local.md` | 프로젝트 키 (예: MYPROJECT) |
| Confluence 스페이스 | `.claude.local.md` | 스페이스 키 (예: TEAM) |
| Atlassian 사이트 | `.claude.local.md` | 사이트 URL (예: your-company.atlassian.net) |
