---
description: workflow-kit 초기 설정 마법사. 설정할 기능을 선택하고 단계별로 설정한다.
---

workflow-kit 초기 설정을 시작한다. 아래 절차를 정확히 따를 것.

## 사전 확인

먼저 현재 프로젝트 절대 경로를 Bash로 확인한다: `pwd`

---

## 1단계: 기능 선택

AskUserQuestion을 사용하여 설정할 기능을 선택받는다 (multiSelect: true).

질문: "어떤 기능을 설정할까요? (복수 선택 가능)"

선택지:
- `Mac 답변 알림` — Claude 응답 완료 시 macOS 알림 표시 (설정 30초, 요구사항: macOS)
- `Claude 사용량 모니터` — 메뉴바에서 5시간 세션 사용률 확인 (요구사항: SwiftBar)
- `Jira/Confluence 워크플로우` — 티켓 생성 + Confluence 문서 자동화 (요구사항: Atlassian 계정 + MCP)
- `Slack 워크플로우 봇` — Slack Form 감지 → 자동 티켓 생성/분석 (선행: Jira/Confluence 설정 완료)
- `AWS 인프라 모니터` — AWS 현황 스냅샷 자동 수집 (요구사항: AWS CLI + SwiftBar)

---

## 2단계: 기능별 설정

선택된 기능을 순서대로 설정한다. 각 기능은 독립적으로 실행한다.

### Mac 답변 알림

**목표:** `~/.claude/settings.json`에 아래 3가지 훅을 모두 등록한다.

| 훅 이벤트 | matcher | 스크립트 | 동작 |
|----------|---------|---------|------|
| Stop | (없음) | `notify-on-stop.sh` | 답변 완료 알림 |
| Notification | `elicitation_dialog` | `notify-on-permission.sh` | 승인 필요 알림 |
| Notification | `permission_prompt` | `notify-on-permission.sh` | 권한 요청 알림 |
| PreToolUse | `AskUserQuestion` | `notify-on-permission.sh` | 질문 알림 |
| PostToolUse | `Task` | `agent-log.sh` | 에이전트 실행 결과 로그 기록 |

**절차:**

1. `~/.claude/settings.json` 파일 읽기 (없으면 `{}` 로 시작)
2. 각 훅에 `notify-on-stop.sh` 또는 `notify-on-permission.sh`가 이미 등록되어 있는지 확인
3. 없는 훅만 추가 (기존 훅 배열은 덮어쓰지 말고 항목만 추가):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [{"type": "command", "command": "bash {경로}/hooks/notify-on-stop.sh"}]
      }
    ],
    "Notification": [
      {
        "matcher": "elicitation_dialog",
        "hooks": [{"type": "command", "command": "bash {경로}/hooks/notify-on-permission.sh"}]
      },
      {
        "matcher": "permission_prompt",
        "hooks": [{"type": "command", "command": "bash {경로}/hooks/notify-on-permission.sh"}]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [{"type": "command", "command": "bash {경로}/hooks/notify-on-permission.sh"}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Task",
        "hooks": [{"type": "command", "command": "bash {경로}/hooks/agent-log.sh"}]
      }
    ]
  }
}
```
(`{경로}`는 1단계에서 확인한 프로젝트 절대 경로로 대체)

4. 파일 저장
5. `chmod +x hooks/notify-on-stop.sh hooks/notify-on-permission.sh hooks/agent-log.sh` 실행
6. 완료 메시지 출력

---

### Claude 사용량 모니터

**목표:** SwiftBar 플러그인 심볼릭 링크를 생성한다.

1. `~/SwiftBar` 폴더 존재 여부 확인 (`ls ~/SwiftBar 2>/dev/null`)
2. 폴더가 없으면:
   - SwiftBar 설치 방법 안내 출력:
     ```
     SwiftBar가 설치되지 않았습니다.
     brew install --cask swiftbar
     설치 후 SwiftBar 실행 → 플러그인 폴더로 ~/SwiftBar 선택
     ```
   - AskUserQuestion: "SwiftBar 설치 완료 후 계속할까요?"
     - 계속: 다음으로 진행
     - 취소: 이 기능 건너뜀
3. `~/SwiftBar/claude-usage.30s.sh` 이미 존재하면 "이미 설치됨" 출력 후 건너뜀
4. 심볼릭 링크 생성:
   ```bash
   ln -s "{프로젝트_절대경로}/swiftbar/claude-usage.30s.sh" ~/SwiftBar/claude-usage.30s.sh
   ```
5. 완료 메시지 출력

---

### Jira/Confluence 워크플로우

**목표:** `.claude.local.md` 파일과 `~/.claude.json`의 Atlassian MCP 설정을 완료한다.

#### A. `.claude.local.md` 설정

1. `.claude.local.md` 파일이 이미 존재하면:
   - AskUserQuestion: "`.claude.local.md`가 이미 있습니다. 어떻게 할까요?"
     - `기존 파일 유지` — 건너뜀
     - `덮어써서 새로 설정`
2. 없거나 덮어쓰기 선택 시 AskUserQuestion으로 정보 수집:
   - "Atlassian 사이트 URL (예: company.atlassian.net)"
   - "Atlassian 계정 이메일"
   - "Jira 프로젝트 키 (예: MYPROJECT)"
   - "Confluence 스페이스 키 (예: TEAM)"
3. AskUserQuestion: "코드 분석에 사용할 경로를 입력하세요."
   - "백엔드 프로젝트 절대 경로 (없으면 비워두기)"
   - "프론트엔드 프로젝트 절대 경로 (없으면 비워두기)"
4. `.claude.local.md` 파일 생성 (빈 경로는 `/경로/없음` 대신 공란으로):

```markdown
# 사용자별 로컬 설정

## 프로젝트 경로

| 프로젝트 | 경로 |
|---------|------|
| 백엔드 | {백엔드_경로} |
| 프론트엔드 | {프론트엔드_경로} |

## Atlassian 계정 정보

| 항목 | 값 |
|------|-----|
| 이메일 | {이메일} |
| Atlassian 사이트 | {사이트} |

## Jira / Confluence 설정

| 항목 | 값 | 설명 |
|------|-----|------|
| Jira 프로젝트 키 | {jira_key} | Jira 프로젝트 키 |
| Confluence 스페이스 키 | {confluence_key} | Confluence 스페이스 키 |
| 분석 문서 폴더 | 🤖 AI Analysis | 분석 문서가 저장될 폴더 경로 |
```

#### B. Atlassian MCP 설정

1. `~/.claude.json` 파일 읽기 (없으면 `{}` 로 시작)
2. `mcpServers.atlassian` 키가 이미 있으면:
   - AskUserQuestion: "Atlassian MCP가 이미 설정되어 있습니다. 덮어쓸까요?"
     - 덮어쓰기 / 유지
3. 없거나 덮어쓰기 선택 시 AskUserQuestion:
   - "Atlassian API 토큰 (https://id.atlassian.com/manage-profile/security/api-tokens 에서 발급)"
4. `~/.claude.json`의 `mcpServers` 에 추가:
   ```json
   "atlassian": {
     "command": "npx",
     "args": ["-y", "@anthropic/mcp-atlassian"],
     "env": {
       "ATLASSIAN_SITE": "{사이트}",
       "ATLASSIAN_USER_EMAIL": "{이메일}",
       "ATLASSIAN_API_TOKEN": "{토큰}"
     }
   }
   ```
5. 완료 메시지 출력

#### C. Slack MCP 설정

Jira/Confluence 워크플로우에서 담당자/요청자에게 DM을 발송할 때 Slack MCP가 필요하다.

1. `~/.claude.json` 읽기 (이미 읽었으면 재사용)
2. `mcpServers.slack` 키가 이미 있으면:
   - AskUserQuestion: "Slack MCP가 이미 설정되어 있습니다. 덮어쓸까요?"
     - 덮어쓰기 / 유지
3. 없거나 덮어쓰기 선택 시 AskUserQuestion:
   - "Slack Bot Token (xoxb-...) — Slack 앱의 Bot Token"
   - "Slack Team ID (T로 시작하는 워크스페이스 ID — Slack 앱 > About 또는 URL에서 확인)"
4. `~/.claude.json`의 `mcpServers`에 추가:
   ```json
   "slack": {
     "command": "npx",
     "args": ["-y", "@modelcontextprotocol/server-slack"],
     "env": {
       "SLACK_BOT_TOKEN": "{bot_token}",
       "SLACK_TEAM_ID": "{team_id}"
     }
   }
   ```
5. 완료 후 안내:
   ```
   ✅ Jira/Confluence 워크플로우 설정 완료
   Claude Code를 재시작해야 MCP가 적용됩니다: claude --resume
   ```

---

### Slack 워크플로우 봇

**목표:** `bot/.env` 파일을 생성하고 의존성을 설치한다.

**선행 조건 확인:**
- `.claude.local.md`가 존재하고 Atlassian 사이트 정보가 있는지 확인
- 없으면 "Jira/Confluence 워크플로우를 먼저 설정하세요." 출력 후 건너뜀

1. `bot/.env` 파일이 이미 존재하면:
   - AskUserQuestion: "bot/.env가 이미 있습니다. 어떻게 할까요?"
     - `기존 파일 유지` — 건너뜀
     - `덮어써서 새로 설정`
2. AskUserQuestion으로 Slack 정보 수집:
   - "Slack Bot Token (xoxb-...)"
   - "Slack App-Level Token (xapp-..., Socket Mode용)"
   - "감시할 Slack 채널 ID (채널명 우클릭 > 링크 복사 하단에 표시)"
3. `.claude.local.md`에서 Atlassian 사이트와 Jira 프로젝트 키 읽어서 자동 채움
4. `bot/.env` 생성 (프로젝트 절대 경로 포함):
   ```
   SLACK_BOT_TOKEN={bot_token}
   SLACK_APP_TOKEN={app_token}
   SLACK_CHANNEL_ID={channel_id}
   TRIGGER_EMOJI=robot_face
   ATLASSIAN_SITE={사이트}
   JIRA_PROJECT_KEY={jira_key}
   CLAUDE_WORK_DIR={프로젝트_절대경로}
   CLAUDE_MAX_TURNS_TICKET=25
   CLAUDE_MAX_TURNS_ANALYSIS=25
   ```
5. `cd bot && npm install` 실행
6. AskUserQuestion: "SwiftBar 메뉴바 플러그인도 설치할까요? (봇 시작/중지/상태 확인)"
   - 설치: `ln -s "{경로}/swiftbar/workflow-bot.5s.sh" ~/SwiftBar/workflow-bot.5s.sh`
   - 건너뜀
7. AskUserQuestion: "지금 바로 봇을 시작할까요?"
   - 시작: `bash bot/scripts/start-bot.sh`
   - 나중에: 시작 명령어 안내 출력

---

### AWS 인프라 모니터

**목표:** AWS CLI 확인 후 SwiftBar 플러그인을 설치한다.

1. `aws --version` 실행하여 AWS CLI 설치 확인
2. 없으면 안내:
   ```
   AWS CLI가 설치되지 않았습니다.
   brew install awscli
   설치 후 aws configure 로 인증 설정 필요
   ```
3. `~/SwiftBar` 폴더 존재 확인
4. 없으면 SwiftBar 설치 안내 (Mac 답변 알림과 동일한 안내)
5. `~/SwiftBar/infra-snapshot.5s.sh` 이미 존재하면 건너뜀
6. 심볼릭 링크 생성:
   ```bash
   ln -s "{프로젝트_절대경로}/swiftbar/infra-snapshot.5s.sh" ~/SwiftBar/infra-snapshot.5s.sh
   ```
7. AskUserQuestion: "지금 바로 최초 스냅샷을 수집할까요? (약 1-2분 소요)"
   - 수집: `bash infra-snapshot/snapshot.sh`
   - 건너뜀

---

## 3단계: 완료 요약

모든 기능 설정이 끝나면 아래 형식으로 요약을 출력한다:

```
## kit-setup 완료

| 기능 | 상태 |
|------|------|
| Mac 답변 알림 | ✅ 설정 완료 / ⬜ 건너뜀 |
| Claude 사용량 모니터 | ... |
| Jira/Confluence 워크플로우 | ... (재시작 필요) |
| Slack 워크플로우 봇 | ... |
| AWS 인프라 모니터 | ... |
```

재시작이 필요한 기능이 있으면 마지막에 강조:
```
⚠️ Claude Code를 재시작해야 MCP 설정이 적용됩니다:
  claude --resume
```
