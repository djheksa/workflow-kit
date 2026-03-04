# hooks/

Claude Code 훅 스크립트 모음.

각 스크립트는 Claude Code의 이벤트(Stop, Notification, PreToolUse 등)에 연결하여 사용한다.
설치는 `~/.claude/settings.json` (전역) 또는 `.claude/settings.json` (프로젝트 한정)에 등록.

---

## 제공 훅

| 스크립트 | 이벤트 | 기능 | 기본 활성화 |
|---------|--------|------|------------|
| `notify-on-stop.sh` | Stop | Claude 답변 완료 시 Mac 데스크탑 알림 | 수동 설치 |
| `notify-on-permission.sh` | Notification, PreToolUse | 승인/권한 요청/질문 발생 시 Mac 알림 | 수동 설치 |
| `precompact-save-summary.sh` | PreCompact | 컨텍스트 압축 전 세션 요약 자동 저장 | `.claude/settings.json` 등록됨 |

---

## 설치 방법

### 1. `notify-on-stop.sh` — Mac 답변 알림

Claude가 답변을 마칠 때마다 macOS 알림 센터에 알림을 표시한다.

**전역 설치** (모든 프로젝트에서 동작):

`~/.claude/settings.json`에 아래 내용 추가:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash /절대경로/workflow-kit/hooks/notify-on-stop.sh"
          }
        ]
      }
    ]
  }
}
```

> 절대 경로 확인: `pwd` 명령으로 현재 workflow-kit 디렉토리 경로 확인 후 입력

**프로젝트 한정 설치** (이 프로젝트에서만 동작):

프로젝트 루트의 `.claude/settings.json`에 추가:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash hooks/notify-on-stop.sh"
          }
        ]
      }
    ]
  }
}
```

---

## 동작 원리

Claude Code는 훅 이벤트 발생 시 스크립트의 stdin으로 JSON을 전달한다.

```json
{
  "cwd": "/path/to/project",
  "last_assistant_message": "Claude의 마지막 응답 텍스트"
}
```

`notify-on-stop.sh`는 이 JSON에서 프로젝트명과 응답 요약(최대 80자)을 추출해 `osascript`로 알림을 발송한다.

---

---

## 2. `precompact-save-summary.sh` — 세션 요약 자동 저장

컨텍스트 압축이 발생하기 직전에 현재 세션의 수정 파일 목록과 최근 응답 요약을 파일로 저장한다.

**저장 위치:** `/tmp/claude-session-{프로젝트명}.md` (세션별 누적)

**이미 `.claude/settings.json`에 등록되어 있어 클론 후 바로 동작한다.**

저장 내용:
- 이 세션에서 수정된 파일 전체 목록
- 압축 직전 마지막 응답 3개 요약 (최대 300자)

**동작 확인:**
```bash
# 수동 테스트
TRANSCRIPT=$(ls -t ~/.claude/projects/$(basename $PWD | tr '/' '-')/*.jsonl 2>/dev/null | head -1)
echo "{\"cwd\":\"$PWD\",\"transcript_path\":\"$TRANSCRIPT\"}" \
  | bash hooks/precompact-save-summary.sh

# 저장 결과 확인
cat /tmp/claude-session-$(basename $PWD).md
```

---

## 주의사항

- `notify-on-stop.sh`: macOS 전용 (`osascript` 사용)
- 이미 `~/.claude/settings.json`에 Stop 훅이 있으면 **중복 알림**이 올 수 있음 → 기존 전역 훅 제거 권장
- macOS 알림 권한이 필요함 (시스템 설정 > 알림 > Terminal 허용)
