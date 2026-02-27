#!/bin/bash
# <bitbar.title>Claude Code Usage</bitbar.title>
# <bitbar.version>1.3</bitbar.version>
# <bitbar.desc>Claude Code 5시간 세션 usage 모니터링 (메시지 수 기반)</bitbar.desc>

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

WINDOW_HOURS=5

# ────────────────────────────────────────────
# 기본 지표: 메시지 수 (cache_r 오차 제거)
# 캘리브레이션 이력 (2포인트 평균):
#   1차: /usage 74% = 603msg → 한도 815msg
#   2차: /usage 79% = 703msg → 한도 890msg
#   3차: /usage 81% = 750msg → 한도 926msg  ← 최신 (현재 적용)
#   4차: /usage 5% = 170msg → 한도 3400msg
#   5차: /usage 6% = 182msg → 한도 3033msg
# ※ 최신 포인트 사용 (평균 대신): 한도가 세션 진행에 따라 수렴하는 경향
# 보조 지표: 비용 (참고용)
LIMIT_MESSAGES=1813
LIMIT_COST_USD=44.6   # 참고용
# ────────────────────────────────────────────

USAGE=$(python3 << PYEOF
import json, os, glob, time
from datetime import datetime

claude_dir   = os.path.expanduser("~/.claude/projects")
window_hours = $WINDOW_HOURS
limit_msg    = $LIMIT_MESSAGES
limit_cost   = $LIMIT_COST_USD
now    = time.time()
cutoff = now - window_hours * 3600

# 1단계: 5시간 내 모든 메시지 수집 (timestamp 순 정렬용)
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
                    u   = d.get("message", {}).get("usage", {})
                    out = u.get("output_tokens", 0)
                    if out == 0:
                        continue
                    all_msgs.append((epoch, u))
                except Exception:
                    pass
    except Exception:
        pass

# 2단계: 세션 경계 감지 (90분 이상 gap = 세션 리셋)
SESSION_GAP = 90 * 60  # 90분
all_msgs.sort(key=lambda x: x[0])

session_start_idx = 0
for i in range(len(all_msgs) - 1, 0, -1):
    gap = all_msgs[i][0] - all_msgs[i-1][0]
    if gap >= SESSION_GAP:
        session_start_idx = i
        break

# 마지막 메시지로부터 지금까지 90분 이상 공백이면 현재 세션 메시지 없음
if all_msgs and (now - all_msgs[-1][0]) >= SESSION_GAP:
    all_msgs = []

current_msgs = all_msgs[session_start_idx:]

# 3단계: 집계
total_in = total_out = total_cache_c = total_cache_r = 0
msg_count   = 0
earliest_ts = None

for epoch, u in current_msgs:
    total_in      += u.get("input_tokens", 0)
    total_out     += u.get("output_tokens", 0)
    total_cache_c += u.get("cache_creation_input_tokens", 0)
    total_cache_r += u.get("cache_read_input_tokens", 0)
    msg_count     += 1
    if earliest_ts is None or epoch < earliest_ts:
        earliest_ts = epoch

# --- 사용률 % (메시지 수 기반, 기본 지표) ---
pct_msg  = min(999, int(msg_count * 100 / limit_msg)) if limit_msg > 0 else 0

# --- 비용 (참고용) ---
cost_out     = total_out     * 15.00 / 1_000_000
cost_in      = total_in      *  3.00 / 1_000_000
cost_cache_c = total_cache_c *  3.75 / 1_000_000
cost_cache_r = total_cache_r *  0.30 / 1_000_000
total_cost   = cost_out + cost_in + cost_cache_c + cost_cache_r
pct_cost     = min(999, int(total_cost * 100 / limit_cost)) if limit_cost > 0 else 0

# --- 세션 윈도우 ---
if earliest_ts:
    window_end    = earliest_ts + window_hours * 3600
    remaining_sec = max(0, int(window_end - now))
    remain_h = remaining_sec // 3600
    remain_m = (remaining_sec % 3600) // 60
    reset_local     = datetime.fromtimestamp(window_end).strftime("%H:%M")
    win_start_local = datetime.fromtimestamp(earliest_ts).strftime("%H:%M")
else:
    remain_h, remain_m = window_hours, 0
    reset_local = win_start_local = "N/A"

def fmt(n):
    if n >= 1_000_000: return f"{n/1_000_000:.1f}M"
    if n >= 1_000:     return f"{n/1_000:.0f}k"
    return str(n)

pct    = pct_msg
filled = min(10, pct // 10)
bar    = "█" * filled + "░" * (10 - filled)

print(f"PCT={pct}")
print(f"BAR={bar}")
print(f"MSG={msg_count}")
print(f"COST={total_cost:.2f}")
print(f"PCT_COST={pct_cost}")
print(f"OUT={fmt(total_out)}")
print(f"IN={fmt(total_in)}")
print(f"CACHE_C={fmt(total_cache_c)}")
print(f"CACHE_R={fmt(total_cache_r)}")
print(f"REMAIN={remain_h}h {remain_m}m")
print(f"RESET={reset_local}")
print(f"WIN_START={win_start_local}")
PYEOF
)

get_val() { echo "$USAGE" | grep "^$1=" | cut -d= -f2-; }

PCT=$(get_val PCT)
BAR=$(get_val BAR)
MSG=$(get_val MSG)
COST=$(get_val COST)
PCT_COST=$(get_val PCT_COST)
OUT=$(get_val OUT)
IN=$(get_val IN)
CACHE_C=$(get_val CACHE_C)
CACHE_R=$(get_val CACHE_R)
REMAIN=$(get_val REMAIN)
RESET=$(get_val RESET)
WIN_START=$(get_val WIN_START)

# --- 메뉴바 ---

if [ -z "$PCT" ] || [ "$MSG" = "0" ]; then
  echo "◯ Claude"
else
  if   [ "$PCT" -le 20 ]; then GAUGE="▁"
  elif [ "$PCT" -le 40 ]; then GAUGE="▃"
  elif [ "$PCT" -le 60 ]; then GAUGE="▅"
  elif [ "$PCT" -le 80 ]; then GAUGE="▇"
  else                         GAUGE="█"
  fi

  if   [ "$PCT" -le 30 ]; then COLOR="#34C759"
  elif [ "$PCT" -le 60 ]; then COLOR="#FF9F0A"
  elif [ "$PCT" -le 85 ]; then COLOR="#FF6B35"
  else                         COLOR="#FF3B30"
  fi

  echo "Claude ${GAUGE} ${PCT}% | color=${COLOR}"
fi

echo "---"
echo "Claude Code Session Usage | size=14"
echo "---"

if [ -n "$PCT" ] && [ "$MSG" != "0" ]; then
  echo "[${BAR}] ${PCT}% | font=Menlo"
  echo "메시지: ${MSG} / ${LIMIT_MESSAGES}개 | color=gray size=12"
  echo "비용 참고: \$${COST} (${PCT_COST}%) | color=gray size=11"
  echo "---"
  echo "세션: ${WIN_START} → ${RESET} | color=gray"
  echo "리셋까지: ${REMAIN} | color=orange"
  echo "---"
  echo "출력 토큰:  ${OUT} | color=green"
  echo "입력 토큰:  ${IN} | color=gray"
  echo "캐시 생성:  ${CACHE_C} | color=gray"
  echo "캐시 읽기:  ${CACHE_R} | color=gray"
else
  echo "[░░░░░░░░░░] 0% | font=Menlo"
  echo "---"
  echo "5시간 내 사용 내역 없음 | color=gray"
fi

echo "---"
REAL_SCRIPT="$(readlink -f "$0" 2>/dev/null || readlink "$0" 2>/dev/null || echo "$0")"
SWIFTBAR_DIR="$(cd "$(dirname "$REAL_SCRIPT")" && pwd)"
CALIBRATE_SCRIPT="$SWIFTBAR_DIR/scripts/calibrate-claude-usage.sh"
echo "📐 /usage % 입력해서 보정 | bash=$CALIBRATE_SCRIPT terminal=false refresh=true"
echo "한도: ${LIMIT_MESSAGES}msg (1pt 캘리브레이션) | color=gray size=11"
echo "새로고침 | refresh=true"
