# PMS Workflow Tool

Claude Code에서 사용하는 워크플로우 도구. 이 프로젝트를 클론하고 해당 경로에서 Claude Code를 실행하면 정의된 워크플로우를 사용할 수 있음.

## 작업 원칙

- 모르거나 불확실한 사항은 AskUserQuestion을 적극 활용하여 사용자에게 선택지를 제공할 것 (토큰 절약 및 올바른 플로우 실행 목적)
- 추측하지 말고, 확인이 필요한 사항은 반드시 질문할 것

## 세션 시작 시 환경 체크리스트

세션의 첫 메시지에서 `.claude.local.md` 파일을 읽어 사용자 환경 정보를 확인하고, 아래 체크리스트를 표시할 것:

**출력 형식:**
```
워크플로우 사용을 위한 환경 체크리스트:
[ ] .claude.local.md 설정 완료
[ ] Atlassian MCP 연결 (Jira/Confluence)
[ ] Slack MCP 연결
[ ] 백엔드 프로젝트 경로 (.claude.local.md 참조)
[ ] 프론트엔드 프로젝트 경로 (.claude.local.md 참조)

위 항목들은 워크플로우 사용을 위한 사전 준비사항입니다.
환경 검증 과정에 도움이 필요하다면 "도움" 이라고 작성해주세요.
```

**초기 설정 안내:**
세션 시작 시 `.claude.local.md` 파일이 존재하지 않으면:
1. `.claude.local.md.example`을 `.claude.local.md`로 복사하라고 안내
2. 자신의 환경에 맞게 값 수정 안내 (프로젝트 경로, 이메일 등)
3. 초기 설정이 완료될 때까지 워크플로우 실행을 차단

**환경 검증 절차:**
사용자가 "도움"을 입력하면:
1. `.claude.local.md` 존재 여부 확인
2. `.claude.local.md`에서 백엔드/프론트엔드 경로를 읽어 해당 디렉토리 존재 여부 검증
3. Atlassian MCP 도구 사용 가능 여부 확인
4. Slack MCP 도구 사용 가능 여부 확인
5. 실패 항목에 대해 해결 방법 안내

## 사전 요구사항

### 1. Claude Code 설치
- https://claude.ai/code 에서 설치

### 2. Atlassian MCP 설정

Claude Code 설정 파일에 Atlassian MCP를 추가해야 합니다.

**설정 파일 위치:**
- macOS: `~/.claude/mcp_settings.json`
- Windows: `%APPDATA%\claude\mcp_settings.json`

**설정 내용:**
```json
{
  "mcpServers": {
    "atlassian": {
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-atlassian"],
      "env": {
        "ATLASSIAN_SITE": "dnklabs.atlassian.net",
        "ATLASSIAN_USER_EMAIL": "your-email@dnklabs.co",
        "ATLASSIAN_API_TOKEN": "your-api-token"
      }
    }
  }
}
```

**API 토큰 발급 방법:**
1. https://id.atlassian.com/manage-profile/security/api-tokens 접속
2. "Create API token" 클릭
3. 라벨 입력 (예: "Claude Code MCP")
4. 생성된 토큰 복사하여 설정 파일에 입력

### 3. Claude Code 재시작
설정 후 Claude Code를 재시작해야 MCP가 적용됩니다.

---

## 사용 가능한 워크플로우

### 워크플로우 1: 요청 분석 → 티켓/문서 생성

사용자의 요청을 분석하여 Jira 티켓과 Confluence 분석 문서를 자동 생성합니다.

**사용 방법:**
```
요청 분석해줘

요청 유형: 버그 (또는: 기능 추가 / 개선 사항 / 기타)
제목: 계약 상태 변경 시 오류 발생
설명: 계약 목록에서 일괄 변경 시 "변경하지 않음" 선택해도 값이 변경됨
우선순위: 높음 (또는: 긴급 / 보통 / 낮음)
관련 화면: 계약관리
요청자: 홍길동
```

**출력:**
1. Jira 티켓 (PDPMS 프로젝트)
2. Confluence 분석 문서 (PE > 05.AI Analysis)
3. Jira 티켓에 Confluence 분석 문서 링크 연결
4. Jira 티켓 상태 전환: `Backlog` → `AI 분석 시작` → `분석 완료` (AI Reviewed)
5. Slack DM 알림 발송:
   - 요청자: 분석 완료 알림 (티켓 링크 + 분석 문서 링크 + 담당자 + 상태)
   - 담당자 (있는 경우): 배정 알림 (티켓 링크 + 분석 문서 링크 + 요청자 + 우선순위 + 상태)

### 워크플로우 2: 코드베이스 분석

특정 기능이나 버그에 대해 관련 코드를 분석합니다.

**사용 방법:**
```
코드 분석해줘

분석 대상: 계약 상태 일괄 변경 기능
분석 범위: 백엔드 (또는: 프론트엔드 / 전체)
```

---

## 연동 대상

| 항목 | 값 |
|------|-----|
| Jira 프로젝트 | PDPMS |
| Confluence 스페이스 | PE |
| 분석 문서 위치 | PE > 🤖 05.AI Analysis |

---

## 관련 프로젝트 경로

분석 시 참조하는 코드베이스 경로는 `.claude.local.md`에 정의됩니다.
워크플로우 실행 시 `.claude.local.md`의 "프로젝트 경로" 테이블에서 백엔드/프론트엔드 경로를 읽어 사용할 것.

`.claude.local.md`가 없거나 경로가 정의되지 않은 경우, AskUserQuestion으로 사용자에게 경로를 질문할 것.

---

## 템플릿

### Jira 티켓 템플릿

**제목 형식:**
- 버그: `[긴급] {제목}` 또는 `{제목}`
- 기능: `[기능] {제목}`
- 개선: `[개선] {제목}`

**설명 형식 (원본 요청 Form 유지 + AI 분석 요약만 추가, 상세 내용은 Confluence 분석 문서에 위임):**
```
## 요청사항

| 항목 | 내용 |
|------|------|
| 유형 | {유형} |
| 제목 | {제목} |
| 우선순위 | {우선순위} |
| 관련 화면 | {화면} |
| 요청자 | @{요청자} |
| 담당자 | @{담당자} |

## 상세 설명

{원본 요청의 상세 설명을 그대로 유지}

## AI 분석 요약

{1-2문장 핵심 요약}

분석 문서: {Confluence 링크}
```

### Confluence 분석 문서 템플릿

**제목:** `🤖 {요청 제목} 분석`
**위치:** PE > 🤖 05.AI Analysis

**내용 구조:**
```
🤖 AI 생성 문서 | 분석일: {날짜}

## 요청 정보
| 항목 | 내용 |
|------|------|
| 요청 유형 | {유형} |
| 요청자 | {이름} |
| 우선순위 | {우선순위} |
| 관련 화면 | {화면} |
| Jira 티켓 | PDPMS-{번호} |

## 요청 내용
> {원본 요청}

## 분석 결과

### 요약
{1-2문장 요약}

### 관련 파일
| 파일 경로 | 관련도 | 설명 |
|----------|--------|------|
| {경로} | 높음/중간/낮음 | {설명} |

### 영향 범위
| 항목 | 내용 |
|------|------|
| 예상 수정 파일 수 | {N}개 |
| 복잡도 | 단순/보통/복잡 |
| API 변경 | 있음/없음 |
| DB 마이그레이션 | 필요/불필요 |

## 제안 구현 방안

### 접근 방식
{설명}

### 단계별 작업
1. {단계 1}
2. {단계 2}

## 리스크 및 고려사항
- ⚠️ {리스크}

## 미해결 질문
- ❓ {질문}

---
🤖 이 문서는 Claude Code를 사용하여 생성되었습니다.
```

---

## 워크플로우 실행 규칙

아래 규칙 파일들은 워크플로우 실행 시 반드시 참조해야 합니다:

### Confluence 문서 작업 규칙
- 워크플로우 1에서 Confluence 분석 문서 생성/수정 시 적용
- 규칙 파일: `.claude/rules/confluence.md` 를 읽을 것

### 에이전트 모델 전략
- 워크플로우 2에서 코드베이스 분석 시 서브 에이전트를 활용할 때 적용
- 규칙 파일: `.claude/rules/agent-strategy.md` 를 읽을 것

---

## 관련 문서

- [워크플로우 아키텍처 설계](https://dnklabs.atlassian.net/wiki/spaces/PE/pages/8192022)
- [📋 분석 결과 템플릿](https://dnklabs.atlassian.net/wiki/spaces/PE/pages/9273345)
