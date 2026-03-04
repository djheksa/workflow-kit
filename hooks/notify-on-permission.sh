#!/bin/bash
# Claude Code 승인/권한 요청 시 Mac 알림
# 용도:
#   - Notification 훅 (elicitation_dialog): "승인이 필요합니다" 알림
#   - Notification 훅 (permission_prompt): "[도구명] 실행 승인이 필요합니다" 알림
#   - PreToolUse 훅 (AskUserQuestion): 질문 알림
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

    # PreToolUse (tool_name 있는 경우)
    tool = d.get('tool_name', '')
    if tool:
        print(f'[{tool}] 확인이 필요합니다.')
        sys.exit(0)

    # Notification permission_prompt (message 있는 경우)
    raw_msg = d.get('message', '')
    if raw_msg:
        tool = raw_msg.split()[-1] if raw_msg.split() else '명령'
        print(f'[{tool}] 실행 승인이 필요합니다.')
        sys.exit(0)

    # Notification elicitation_dialog 또는 기타
    print('승인이 필요합니다. 확인해주세요.')
except Exception:
    print('확인이 필요합니다.')
" 2>/dev/null || echo "확인이 필요합니다.")

proj_safe="${proj//\'/\'}"
msg_safe="${msg//\'/\'}"

osascript -e "display notification \"${msg_safe}\" with title \"${proj_safe}\" sound name \"default\"" 2>/dev/null || true
