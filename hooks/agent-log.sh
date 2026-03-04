#!/bin/bash
# Claude Code 에이전트(Task) 실행 결과 로깅
# 용도: PostToolUse Task 훅으로 등록 → 에이전트 완료 시 결과를 로그 파일에 기록
# 로그 위치: /tmp/claude-agent-log.jsonl
# 설치: hooks/README.md 참조

input=$(cat)

python3 -c "
import sys, json, os, tempfile, datetime

d = sys.stdin.read()
status = 'error' if any(k in d.lower() for k in ['failed', 'error', 'exception']) else 'ok'

log_path = os.path.join(tempfile.gettempdir(), 'claude-agent-log.jsonl')
entry = json.dumps({
    'ts': datetime.datetime.now().strftime('%H:%M:%S'),
    'status': status
})
with open(log_path, 'a') as f:
    f.write(entry + '\n')
" <<< "$input" 2>/dev/null || true
