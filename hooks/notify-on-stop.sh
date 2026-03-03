#!/bin/bash
# Claude Code 답변 완료 시 Mac 알림
# 용도: Claude Code Stop 이벤트 훅으로 등록하면 답변이 끝날 때 데스크탑 알림 발송
# 설치: hooks/README.md 참조

input=$(cat)

proj=$(echo "$input" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    cwd = d.get('cwd', '')
    print(cwd.split('/')[-1] or 'Claude Code')
except Exception:
    print('Claude Code')
" 2>/dev/null || echo "Claude Code")

msg=$(echo "$input" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    m = d.get('last_assistant_message', '') or ''
    short = m.replace(chr(10), ' ').strip()[:80]
    print(short if short else '답변이 완료되었습니다.')
except Exception:
    print('답변이 완료되었습니다.')
" 2>/dev/null || echo "답변이 완료되었습니다.")

# 작은따옴표 이스케이프 (osascript 안전)
msg_safe="${msg//\'/\'}"
proj_safe="${proj//\'/\'}"

osascript -e "display notification \"${msg_safe}\" with title \"${proj_safe}\" sound name \"default\"" 2>/dev/null || true
