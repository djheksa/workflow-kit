#!/bin/bash
# Claude Usage 캘리브레이션 (메시지 수 기반)
# SwiftBar 메뉴에서 terminal=false로 실행

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLUGIN_FILE="$PROJECT_DIR/swiftbar/claude-usage.30s.sh"

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

# 1. 실제 % 입력받기
ACTUAL_PCT=$(osascript <<'APPLESCRIPT'
set result to display dialog "/usage 에서 확인한 현재 세션 사용률을 입력하세요 (%)" \
  default answer "" \
  with title "Claude Usage 보정" \
  buttons {"취소", "보정"} \
  default button "보정"
return text returned of result
APPLESCRIPT
)

[ -z "$ACTUAL_PCT" ] && exit 0

if ! echo "$ACTUAL_PCT" | grep -qE '^[0-9]+$'; then
  osascript -e 'display alert "숫자만 입력하세요 (예: 74)" as warning'
  exit 1
fi

# 2. 현재 메시지 수 가져오기
CURRENT_MSG=$(bash "$PLUGIN_FILE" | grep "^메시지:" | grep -oE '[0-9]+' | head -1)

if [ -z "$CURRENT_MSG" ]; then
  osascript -e 'display alert "메시지 수 읽기 실패. 잠시 후 다시 시도하세요." as warning'
  exit 1
fi

# 3. 새 한도 역산 + 이력 업데이트
RESULT=$(python3 << PYEOF
actual_pct  = float("$ACTUAL_PCT")
current_msg = int("$CURRENT_MSG")

if actual_pct <= 0:
    print("ERROR:0으로 나눌 수 없습니다")
    exit(1)

new_limit = round(current_msg / (actual_pct / 100))

import re
with open("$PLUGIN_FILE") as f:
    content = f.read()

# 기존 이력 줄 수
history_lines = re.findall(r'#\s+\d+차:.*', content)
next_num = len(history_lines) + 1

# 기존 한도 평균 계산
existing_limits = [int(x) for x in re.findall(r'한도\s+(\d+)msg', content)]
all_limits = existing_limits + [new_limit]
avg_limit = round(sum(all_limits) / len(all_limits))

print(f"NEW_LIMIT={new_limit}")
print(f"AVG_LIMIT={avg_limit}")
print(f"NEXT_NUM={next_num}")
PYEOF
)

if echo "$RESULT" | grep -q "^ERROR:"; then
  osascript -e "display alert \"$(echo "$RESULT" | cut -d: -f2-)\" as warning"
  exit 1
fi

get_r() { echo "$RESULT" | grep "^$1=" | cut -d= -f2-; }
NEW_LIMIT=$(get_r NEW_LIMIT)
AVG_LIMIT=$(get_r AVG_LIMIT)
NEXT_NUM=$(get_r NEXT_NUM)

# 4. 플러그인 파일 업데이트
python3 << PYEOF
import re

with open("$PLUGIN_FILE") as f:
    content = f.read()

# 이력 마지막 줄 뒤에 새 항목 추가
all_hist = re.findall(r'#\s+\d+차:.*', content)
if all_hist:
    last = sorted(all_hist, key=lambda x: int(re.search(r'\d+', x).group()))[-1]
    new_line = "#   ${NEXT_NUM}차: /usage ${ACTUAL_PCT}% = ${CURRENT_MSG}msg → 한도 ${NEW_LIMIT}msg"
    content = content.replace(last, last + "\n" + new_line)

# 한도: N msg (Npt 캘리브레이션) 줄 업데이트
content = re.sub(r'한도: \d+msg \(\d+pt 캘리브레이션\)', f'한도: ${AVG_LIMIT}msg (${NEXT_NUM}pt 캘리브레이션)', content)

# LIMIT_MESSAGES 값 업데이트
content = re.sub(r'LIMIT_MESSAGES=\d+', f'LIMIT_MESSAGES=${AVG_LIMIT}', content)

with open("$PLUGIN_FILE", "w") as f:
    f.write(content)
PYEOF

# 5. 완료 알림
osascript << APPLESCRIPT
display notification "${NEXT_NUM}차 보정 완료
입력: ${ACTUAL_PCT}% / ${CURRENT_MSG}msg
새 한도: ${NEW_LIMIT}msg → 평균: ${AVG_LIMIT}msg" \
  with title "Claude Usage 보정"
APPLESCRIPT
