# Mac 답변 알림

Claude Code가 답변을 마칠 때마다 macOS 알림 센터에 알림을 표시한다.
다른 앱을 사용하는 중에도 Claude 응답 완료를 즉시 확인할 수 있다.

## 요구사항

- macOS
- Python 3 (`python3` 명령어 사용 가능)
- macOS 알림 권한: 시스템 설정 > 알림 > Terminal (또는 iTerm2) 허용

## 파일

- `hooks/notify-on-stop.sh` — 알림 스크립트

## 설치

### 방법 1: 전역 설치 (모든 프로젝트)

`~/.claude/settings.json`을 열어 `hooks.Stop` 배열에 추가:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash /Users/your-name/workflow-kit/hooks/notify-on-stop.sh"
          }
        ]
      }
    ]
  }
}
```

> `/Users/your-name/workflow-kit` 부분을 실제 경로로 변경

### 방법 2: 이 프로젝트 한정

프로젝트 루트에 `.claude/settings.json` 생성:

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

## 동작 확인

```bash
echo '{"cwd":"/test","last_assistant_message":"테스트 완료"}' \
  | bash hooks/notify-on-stop.sh
```

알림이 표시되면 정상.

## 주의사항

- 이미 `~/.claude/settings.json`에 Stop 훅이 있으면 알림이 2번 올 수 있음
- 그 경우 기존 전역 Stop 훅을 제거하거나 이 스크립트로 교체
