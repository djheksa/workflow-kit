# workflow-kit 기능 카탈로그

클론 후 전부 설정하지 않아도 된다. 필요한 기능만 골라서 사용.

---

## 즉시 사용 가능 (설정 불필요)

| 기능 | 설명 | 난이도 | 상세 |
|-----|------|--------|------|
| Mac 답변 알림 | Claude 답변 완료 시 데스크탑 알림 | ⭐ 쉬움 | [features/mac-notification/](mac-notification/) |
| Claude 사용량 모니터 | SwiftBar 메뉴바에서 5시간 세션 사용률 확인 | ⭐ 쉬움 | [features/claude-usage-monitor/](claude-usage-monitor/) |
| 코드 작성 표준 | 보안/멱등성/동시성 규칙 Claude에 자동 적용 | ⭐ 쉬움 (자동) | `.claude/rules/coding-standards.md` |
| Confluence 규칙 | 문서 수정 시 기존 스타일 보존 원칙 자동 적용 | ⭐ 쉬움 (자동) | `.claude/rules/confluence.md` |

## 설정 필요

| 기능 | 요구사항 | 난이도 | 상세 |
|-----|----------|--------|------|
| Jira/Confluence 워크플로우 | Atlassian MCP + `.claude.local.md` | ⭐⭐ 보통 | [features/jira-confluence-workflow/](jira-confluence-workflow/) |
| Slack 워크플로우 봇 | Slack 앱 토큰 + `bot/.env` | ⭐⭐⭐ 복잡 | [features/slack-bot/](slack-bot/) |
| AWS 인프라 모니터 | AWS CLI + SwiftBar + IAM 권한 | ⭐⭐⭐ 복잡 | [features/aws-infra-monitor/](aws-infra-monitor/) |

---

## 빠른 시작

### 1단계: 설정 파일 복사 (Jira/Confluence/Slack 연동 시 필요)

```bash
cp .claude.local.md.example .claude.local.md
# 파일을 열어 프로젝트 경로, Atlassian 계정 정보 입력
```

### 2단계: 원하는 기능 활성화

각 기능 디렉토리의 README.md에 설치 방법이 있다.

```bash
# 예: Mac 답변 알림 활성화
cat features/mac-notification/README.md

# 예: Claude 사용량 모니터 활성화
cat features/claude-usage-monitor/README.md
```

---

## 기능 간 의존성

```
Slack 워크플로우 봇
  └── Jira 티켓 생성 (워크플로우 1)
        └── AI 분석 + Confluence 문서 (워크플로우 2)

Claude 사용량 모니터  ← 독립 기능
Mac 답변 알림        ← 독립 기능
AWS 인프라 모니터    ← 독립 기능
코드 작성 표준       ← 독립 기능 (자동 적용)
```
