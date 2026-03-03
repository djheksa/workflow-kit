#!/bin/bash
# PreCompact 훅: 컨텍스트 압축 전 세션 요약 저장
# 저장 위치: /tmp/claude-session-{프로젝트명}.md (세션별 누적)

export CLAUDE_HOOK_INPUT
CLAUDE_HOOK_INPUT=$(cat)

python3 << 'PYEOF'
import json, os, sys
from datetime import datetime

raw = os.environ.get('CLAUDE_HOOK_INPUT', '{}')
try:
    d = json.loads(raw)
except Exception:
    sys.exit(0)

cwd             = d.get('cwd', '')
transcript_path = d.get('transcript_path', '')
proj            = os.path.basename(cwd) or 'claude'
ts              = datetime.now().strftime('%Y-%m-%d %H:%M')
output_file     = f'/tmp/claude-session-{proj}.md'

if not transcript_path or not os.path.exists(transcript_path):
    sys.exit(0)

edited_files = []
seen_files   = set()
last_texts   = []

try:
    with open(transcript_path, encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except Exception:
                continue

            if entry.get('type') != 'assistant':
                continue

            for block in entry.get('message', {}).get('content', []):
                if not isinstance(block, dict):
                    continue
                btype = block.get('type', '')

                if btype == 'text':
                    text = block.get('text', '').strip()
                    if text:
                        last_texts.append(text)

                if btype == 'tool_use' and block.get('name') in ('Edit', 'Write'):
                    path = block.get('input', {}).get('file_path', '')
                    if path and path not in seen_files:
                        seen_files.add(path)
                        edited_files.append(path)
except Exception:
    pass

recent = last_texts[-3:] if last_texts else []

lines = [f'# {proj} 세션 로그 — {ts}', '']

if edited_files:
    lines.append('## 수정된 파일')
    for p in edited_files:
        lines.append(f'- {p}')
    lines.append('')

if recent:
    lines.append('## 최근 응답 (압축 전 마지막 3개)')
    for i, msg in enumerate(recent, 1):
        short = msg[:300].replace('\n', ' ').strip()
        lines.append(f'{i}. {short}')
    lines.append('')

lines.append('---\n')

with open(output_file, 'a', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print(f'[precompact] 세션 요약 저장 완료: {output_file}', file=sys.stderr)
PYEOF

unset CLAUDE_HOOK_INPUT
