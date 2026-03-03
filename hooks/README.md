# hooks/

Claude Code 훅 스크립트 모음.

각 스크립트는 Claude Code의 이벤트(Stop, Notification, PreToolUse 등)에 연결하여 사용한다.
설치는 `~/.claude/settings.json` (전역) 또는 `.claude/settings.json` (프로젝트 한정)에 등록.

---

## 제공 훅

| 스크립트 | 이벤트 | 기능 |
|---------|--------|------|
| `notify-on-stop.sh` | Stop | Claude 답변 완료 시 Mac 데스크탑 알림 |

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

## 주의사항

- macOS 전용 (`osascript` 사용)
- 이미 `~/.claude/settings.json`에 Stop 훅이 있으면 **중복 알림**이 올 수 있음 → 기존 전역 훅 제거 권장
- macOS 알림 권한이 필요함 (시스템 설정 > 알림 > Terminal 허용)
