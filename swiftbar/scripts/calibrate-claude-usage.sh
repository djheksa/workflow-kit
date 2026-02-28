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
import re, statistics

actual_pct  = float("$ACTUAL_PCT")
current_msg = int("$CURRENT_MSG")

if actual_pct <= 0:
    print("ERROR:0으로 나눌 수 없습니다")
    exit(1)

new_limit = round(current_msg / (actual_pct / 100))

with open("$PLUGIN_FILE") as f:
    content = f.read()

# 기존 이력에서 (차수, %, msg, 한도) 파싱
hist_raw = re.findall(r'#\s+(\d+)차:.*?/usage\s+(\d+)%\s+=\s+(\d+)msg\s+→\s+한도\s+(\d+)msg', content)
existing = [(int(n), int(p), int(m), int(l)) for n, p, m, l in hist_raw]
next_num = len(existing) + 1

# 새 포인트 포함한 전체 데이터
all_points = existing + [(next_num, int(actual_pct), current_msg, new_limit)]

# 유효 포인트 필터: % >= 8, 한도 >= 1500 (구버전 카운팅 방식 데이터 제외)
valid = [(n, p, m, l) for n, p, m, l in all_points if p >= 8 and l >= 1500]

# IQR 기반 이상치 제거 (데이터 4개 이상일 때만)
if len(valid) >= 4:
    limits_only = sorted([l for _, _, _, l in valid])
    q1 = statistics.quantiles(limits_only, n=4)[0]
    q3 = statistics.quantiles(limits_only, n=4)[2]
    iqr = q3 - q1
    lo, hi = q1 - 1.5 * iqr, q3 + 1.5 * iqr
    valid = [(n, p, m, l) for n, p, m, l in valid if lo <= l <= hi]

# 가중 평균 (% 값이 높을수록 신뢰도 높으므로 가중치로 사용)
if valid:
    w_sum = sum(p * l for _, p, _, l in valid)
    w_cnt = sum(p for _, p, _, _ in valid)
    avg_limit = round(w_sum / w_cnt)
else:
    avg_limit = new_limit

print(f"NEW_LIMIT={new_limit}")
print(f"AVG_LIMIT={avg_limit}")
print(f"NEXT_NUM={next_num}")
print(f"VALID_COUNT={len(valid)}")
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
VALID_COUNT=$(get_r VALID_COUNT)

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
역산 한도: ${NEW_LIMIT}msg
가중 평균 (유효 ${VALID_COUNT}pt): ${AVG_LIMIT}msg" \
  with title "Claude Usage 보정"
APPLESCRIPT
