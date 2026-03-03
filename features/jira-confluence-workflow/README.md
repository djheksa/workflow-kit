# Jira/Confluence 워크플로우

Claude Code로 Jira 티켓 생성 및 Confluence 분석 문서 생성을 자동화한다.

## 제공 워크플로우

### 워크플로우 1: 티켓 생성

요청 내용을 입력하면 Jira 티켓을 생성하고 요청자/담당자에게 Slack DM을 발송한다.

```
티켓 생성해줘

유형: 버그
제목: 계약 상태 변경 시 오류 발생
우선순위: 높음
관련 화면: 계약관리
상세 설명: 일괄 변경 시 값이 변경됨
요청자: 홍길동
```

### 워크플로우 2: AI 분석 + Confluence 문서

Jira 티켓을 기반으로 코드베이스를 분석하고 Confluence에 분석 문서를 생성한다.

```
분석해줘

티켓: PMS-123
분석 범위: 백엔드
```

### 워크플로우 3: 코드베이스 분석 (단독)

티켓 없이 특정 기능/버그를 코드 분석한다.

```
코드 분석해줘

분석 대상: 계약 상태 일괄 변경 기능
분석 범위: 전체
```

## 요구사항

- Atlassian MCP 설정 (`~/.claude.json` > `mcpServers`)
- `.claude.local.md` 설정 (프로젝트 경로, Atlassian 계정)
- Slack MCP 설정 (DM 발송 시)

## 설치

### 1. Atlassian API 토큰 발급

1. https://id.atlassian.com/manage-profile/security/api-tokens 접속
2. "Create API token" 클릭
3. 생성된 토큰 복사

### 2. Atlassian MCP 설정

`~/.claude.json`의 `mcpServers`에 추가:

```json
{
  "mcpServers": {
    "atlassian": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-atlassian"],
      "env": {
        "ATLASSIAN_SITE": "your-company.atlassian.net",
        "ATLASSIAN_USER_EMAIL": "your-email@company.com",
        "ATLASSIAN_API_TOKEN": "your-api-token"
      }
    }
  }
}
```

### 3. `.claude.local.md` 설정

```bash
cp .claude.local.md.example .claude.local.md
```

파일을 열어 아래 항목 입력:
- 백엔드/프론트엔드 프로젝트 경로
- Atlassian 계정 이메일
- Jira 프로젝트 키, Confluence 스페이스 키

### 4. Claude Code 재시작

```bash
claude --resume  # 또는 새 세션으로 시작
```

## 주요 규칙

- Confluence 문서 수정 시 기존 HTML 스타일 보존 (`.claude/rules/confluence.md` 참조)
- 코드 분석은 `collector` → `draft-writer` 에이전트 파이프라인 사용
