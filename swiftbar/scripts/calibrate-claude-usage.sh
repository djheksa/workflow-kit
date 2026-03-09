#!/bin/bash
# Claude Usage 캘리브레이션 (출력 토큰 기반)
# SwiftBar 메뉴에서 terminal=false로 실행

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PLUGIN_FILE="$PROJECT_DIR/swiftbar/claude-usage.config.sh"

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

# 2. 현재 출력 토큰 수 직접 계산 (플러그인과 동일한 로직)
# 주의: 플러그인 출력은 SwiftBar 형식(213k)이라 파싱 불가 → Python으로 직접 계산
WINDOW_HOURS=5
CURRENT_OUT_RAW=$(python3 << PYEOF
import json, os, glob, time
from datetime import datetime

claude_dir   = os.path.expanduser("~/.claude/projects")
window_hours = $WINDOW_HOURS
now    = time.time()
cutoff = now - (window_hours + 1) * 3600

all_msgs = []
for jsonl in glob.glob(f"{claude_dir}/**/*.jsonl", recursive=True):
    try:
        if os.path.getmtime(jsonl) < cutoff - 3600:
            continue
        with open(jsonl, encoding="utf-8", errors="ignore") as f:
            for line in f:
                try:
                    d = json.loads(line)
                    if d.get("type") != "assistant":
                        continue
                    ts_str = d.get("timestamp", "")
                    if not ts_str:
                        continue
                    if ts_str.endswith("Z"):
                        ts_str = ts_str[:-1] + "+00:00"
                    epoch = datetime.fromisoformat(ts_str).timestamp()
                    if epoch <= cutoff:
                        continue
                    u = d.get("message", {}).get("usage", {})
                    if u.get("output_tokens", 0) == 0:
                        continue
                    all_msgs.append((epoch, u))
                except Exception:
                    pass
    except Exception:
        pass

all_msgs.sort(key=lambda x: x[0])
if all_msgs and (now - all_msgs[-1][0]) >= 90 * 60:
    all_msgs = []

session_hour_start = (now // 3600) * 3600
for epoch, _ in all_msgs:
    candidate = (epoch // 3600) * 3600
    if candidate + window_hours * 3600 > now:
        session_hour_start = candidate
        break

total_out = sum(u.get("output_tokens", 0) for e, u in all_msgs if e >= session_hour_start)
print(total_out)
PYEOF)

if [ -z "$CURRENT_OUT_RAW" ] || [ "$CURRENT_OUT_RAW" = "0" ]; then
  osascript -e 'display alert "출력 토큰 읽기 실패. 잠시 후 다시 시도하세요." as warning'
  exit 1
fi

# 3. 새 한도 역산 + 이력 업데이트
RESULT=$(python3 << PYEOF
import re, statistics

actual_pct   = float("$ACTUAL_PCT")
current_out  = int("$CURRENT_OUT_RAW")

if actual_pct <= 0:
    print("ERROR:0으로 나눌 수 없습니다")
    exit(1)

new_limit = round(current_out / (actual_pct / 100))

with open("$PLUGIN_FILE") as f:
    content = f.read()

# 기존 이력에서 (차수, %, tok, 한도) 파싱
hist_raw = re.findall(r'#\s+(\d+)차:.*?/usage\s+(\d+)%\s+=\s+(\d+)tok\s+→\s+한도\s+(\d+)tok', content)
existing = [(int(n), int(p), int(m), int(l)) for n, p, m, l in hist_raw]
next_num = len(existing) + 1

# 새 포인트 포함한 전체 데이터
all_points = existing + [(next_num, int(actual_pct), current_out, new_limit)]

# 유효 포인트 필터: % >= 8, 한도 >= 500000 (너무 낮은 이상치 제거)
# 9~11차(세션 과대 집계로 부정확)는 IQR에서 자동 제외됨
valid = [(n, p, m, l) for n, p, m, l in all_points if p >= 8 and l >= 500000]

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

# 4. config 파일 업데이트 (없으면 새로 생성)
python3 << PYEOF
import re

try:
    with open("$PLUGIN_FILE") as f:
        content = f.read()
except FileNotFoundError:
    content = "# Claude Usage 개인 설정 파일 (git 미추적)\nLIMIT_OUTPUT_TOKENS=800000\n"

# 이력 마지막 줄 뒤에 새 항목 추가
all_hist = re.findall(r'#\s+\d+차:.*tok.*', content)
if all_hist:
    last = sorted(all_hist, key=lambda x: int(re.search(r'\d+', x).group()))[-1]
    new_line = "#   ${NEXT_NUM}차: /usage ${ACTUAL_PCT}% = ${CURRENT_OUT_RAW}tok → 한도 ${NEW_LIMIT}tok"
    content = content.replace(last, last + "\n" + new_line)

# LIMIT_OUTPUT_TOKENS 값 업데이트
content = re.sub(r'LIMIT_OUTPUT_TOKENS=\d+', f'LIMIT_OUTPUT_TOKENS=${AVG_LIMIT}', content)

with open("$PLUGIN_FILE", "w") as f:
    f.write(content)
PYEOF

# 5. 완료 알림
NEW_LIMIT_K=$(echo "$NEW_LIMIT / 1000" | bc)
AVG_LIMIT_K=$(echo "$AVG_LIMIT / 1000" | bc)
osascript << APPLESCRIPT
display notification "${NEXT_NUM}차 보정 완료
입력: ${ACTUAL_PCT}% / ${CURRENT_OUT_RAW}tok
역산 한도: ${NEW_LIMIT_K}k tok
가중 평균 (유효 ${VALID_COUNT}pt): ${AVG_LIMIT_K}k tok" \
  with title "Claude Usage 보정"
APPLESCRIPT
