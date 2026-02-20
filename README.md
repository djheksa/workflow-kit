# PMS Workflow Tool

Claude Code를 사용한 PMS 요청 분석 및 티켓 생성 워크플로우 도구입니다.

## 빠른 시작

1. 이 저장소를 클론합니다
   ```bash
   git clone <repo-url>
   cd pms-workflow-tool
   ```
2. 로컬 설정 파일을 생성합니다
   ```bash
   cp .claude.local.md.example .claude.local.md
   ```
3. `.claude.local.md`를 열어 자신의 환경에 맞게 수정합니다
   - 백엔드/프론트엔드 프로젝트 경로
   - Atlassian 이메일
4. Atlassian MCP를 설정합니다 (아래 참조)
5. 해당 디렉토리에서 Claude Code를 실행합니다
   ```bash
   claude
   ```

## 사전 요구사항

- Claude Code 설치
- Atlassian MCP 설정 (Jira/Confluence 연동)
- Slack MCP 설정 (알림 발송)

자세한 설정 방법은 [CLAUDE.md](./CLAUDE.md)를 참조하세요.

## 파일 구조

| 파일 | 용도 | Git 추적 |
|------|------|---------|
| `CLAUDE.md` | 워크플로우 정의, 템플릿, 조직 상수 | O |
| `.claude.local.md.example` | 로컬 설정 템플릿 | O |
| `.claude.local.md` | 사용자별 로컬 설정 (경로, 계정) | X |
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

| 항목 | 값 |
|------|-----|
| Jira 프로젝트 | PDPMS |
| Confluence 스페이스 | PE |
