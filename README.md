# Workflow Kit

Claude Code 기반 워크플로우 자동화 도구입니다.

## 주요 기능

### Slack Bot — 자동 워크플로우 트리거

Slack 채널을 감시하여 Claude Code(`claude -p`)를 자동 호출하는 브릿지 봇입니다.

- **티켓 자동 생성**: Slack Workflow Form 메시지 감지 → 파싱 → Jira 티켓 생성 → 스레드에 결과 회신
- **AI 코드 분석**: 티켓 메시지에 🤖 이모지 추가 → 코드베이스 분석 → Confluence 문서 생성 → Jira 티켓 연결
- 순차 처리 큐로 Claude API rate limit 방지
- macOS 네이티브 알림 (처리 시작/완료/실패)

### Claude Code 워크플로우 규칙

`CLAUDE.md`에 정의된 워크플로우를 Claude Code가 읽고 실행합니다. 봇 없이 수동으로도 사용 가능합니다.

- **워크플로우 1**: 요청 → Jira 티켓 생성 + Slack DM 알림
- **워크플로우 2**: 티켓 기반 코드 분석 → Confluence 문서 생성 + Jira 상태 전환
- **워크플로우 3**: 티켓 없이 코드베이스 단독 분석
- 서브 에이전트 전략 내장 (Haiku 수집 → Sonnet 분석 → Opus 판단)

### AWS 인프라 스냅샷

AWS CLI로 12개 서비스 정보를 주기적으로 로컬 파일에 수집합니다.

- ECS, Route53, ALB, CloudFront, Nginx, CodeBuild, RDS, ElastiCache, S3, ECR, SES, Parameter Store
- `/tmp/infra-snapshot.md`에 마크다운 테이블로 덤프
- Claude Code가 인프라 관련 질문에 답할 때 참조 데이터로 활용
- AWS 읽기 전용 API만 사용 (추가 비용 없음)

### SwiftBar 메뉴바 플러그인

macOS 메뉴바에서 각 서비스의 상태 확인 및 제어가 가능합니다.

- **Workflow Bot**: 실행 상태, 가동 시간, 최근 처리 내역, 시작/중지/재시작
- **Infra Snapshot**: 수집 상태, 스냅샷 나이, 수동 수집 트리거, 서비스 제어

---

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

## 프로젝트 구조

```
workflow-kit/
├── CLAUDE.md                    # 워크플로우 정의서 (Claude Code 규칙)
├── .claude.local.md.example     # 사용자별 설정 템플릿
├── .claude/rules/               # 실행 규칙 (Confluence, 에이전트 전략)
│
├── bot/                         # Slack Bot
│   ├── src/handlers/            # 메시지/이모지 이벤트 핸들러
│   ├── src/services/            # 파서, Claude 실행기, 알림
│   └── scripts/                 # 시작/중지/재시작 스크립트
│
├── infra-snapshot/              # AWS 인프라 스냅샷 수집기
│   ├── snapshot.sh              # 12개 AWS 서비스 정보 수집
│   └── scripts/                 # 서비스 제어 스크립트
│
└── swiftbar/                    # macOS 메뉴바 플러그인
    ├── workflow-bot.5s.sh       # 봇 상태 관리
    └── infra-snapshot.5s.sh     # 스냅샷 서비스 상태 관리
```

## 연동 대상

연동 대상은 `.claude.local.md`에서 설정합니다:

| 항목 | 설정 위치 | 설명 |
|------|-----------|------|
| Jira 프로젝트 | `.claude.local.md` | 프로젝트 키 (예: MYPROJECT) |
| Confluence 스페이스 | `.claude.local.md` | 스페이스 키 (예: TEAM) |
| Atlassian 사이트 | `.claude.local.md` | 사이트 URL (예: your-company.atlassian.net) |
