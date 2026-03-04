# Workflow Kit

Claude Code 기반 워크플로우 자동화 키트입니다.

**전부 설정하지 않아도 됩니다.** 필요한 기능만 골라서 사용하세요.

## 기능 카탈로그

| 기능 | 설정 필요 | 상세 |
|-----|----------|------|
| Mac 답변 알림 | 없음 (훅 등록만) | [features/mac-notification/](features/mac-notification/) |
| Claude 사용량 모니터 | SwiftBar 설치 | [features/claude-usage-monitor/](features/claude-usage-monitor/) |
| 코드 작성 표준/규칙 | 없음 (자동 적용) | `.claude/rules/` |
| Jira/Confluence 워크플로우 | Atlassian MCP | [features/jira-confluence-workflow/](features/jira-confluence-workflow/) |
| Slack 워크플로우 봇 | Slack 앱 + 토큰 | [features/slack-bot/](features/slack-bot/) |
| AWS 인프라 모니터 | AWS CLI | [features/aws-infra-monitor/](features/aws-infra-monitor/) |

→ 전체 설명: **[features/README.md](features/README.md)**

---

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
- **Claude Usage**: Claude Code 5시간 세션 사용량 실시간 모니터링
  - 메뉴바에 게이지(`▁▃▅▇█`) + 사용률(%) 표시, 사용량에 따라 색상 변화
  - 드롭다운: 메시지 수 / 세션 시간 / 리셋까지 남은 시간 / 토큰 breakdown
  - 경험적 캘리브레이션 지원: 실제 `/usage` 값으로 한도 역산 자동 적용
  - 세션 경계 자동 감지 (90분 이상 비활성 = 새 세션)

---

## 빠른 시작

```bash
git clone <repo-url>
cd workflow-kit
claude
```

Claude Code 실행 후 슬래시 커맨드로 설정 마법사를 실행합니다:

```
/kit-setup
```

설정할 기능을 선택하면 필요한 값을 단계별로 안내합니다. 수동 설정이 필요하면 각 기능의 `features/{기능명}/README.md`를 참조하세요.

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
├── features/                    # 기능 카탈로그
│   ├── README.md                # 전체 기능 목록 및 설치 가이드
│   ├── mac-notification/        # Mac 답변 알림 훅
│   ├── claude-usage-monitor/    # SwiftBar 사용량 모니터
│   ├── jira-confluence-workflow/ # Jira/Confluence 워크플로우
│   ├── slack-bot/               # Slack 워크플로우 봇
│   └── aws-infra-monitor/       # AWS 인프라 모니터
│
├── hooks/                       # Claude Code 훅 스크립트
│   ├── README.md                # 설치 방법 안내
│   └── notify-on-stop.sh        # 답변 완료 시 Mac 알림
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
    ├── infra-snapshot.5s.sh     # 스냅샷 서비스 상태 관리
    ├── claude-usage.30s.sh      # Claude Code 세션 usage 모니터링
    └── scripts/
        └── calibrate-claude-usage.sh  # usage 캘리브레이션 (한도 역산)
```

## 연동 대상

연동 대상은 `.claude.local.md`에서 설정합니다:

| 항목 | 설정 위치 | 설명 |
|------|-----------|------|
| Jira 프로젝트 | `.claude.local.md` | 프로젝트 키 (예: MYPROJECT) |
| Confluence 스페이스 | `.claude.local.md` | 스페이스 키 (예: TEAM) |
| Atlassian 사이트 | `.claude.local.md` | 사이트 URL (예: your-company.atlassian.net) |
