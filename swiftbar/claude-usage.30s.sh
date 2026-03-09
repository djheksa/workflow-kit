#!/bin/bash
# <bitbar.title>Claude Code Usage</bitbar.title>
# <bitbar.version>1.4</bitbar.version>
# <bitbar.desc>Claude Code 5시간 세션 usage 모니터링 (출력 토큰 기반)</bitbar.desc>

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

WINDOW_HOURS=5

# ────────────────────────────────────────────
# 개인 설정 로드 (캘리브레이션 값, 이력)
# config 파일 없으면 기본값 사용 (처음 clone 시)
REAL_SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || readlink "$0" 2>/dev/null || echo "$0")")" && pwd)"
CONFIG_FILE="$REAL_SCRIPT_DIR/claude-usage.config.sh"
LIMIT_OUTPUT_TOKENS=800000  # 기본값 (캘리브레이션 전)
LIMIT_COST_USD=44.6         # 참고용
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"
# ────────────────────────────────────────────

USAGE=$(python3 << PYEOF
import json, os, glob, time
from datetime import datetime

claude_dir          = os.path.expanduser("~/.claude/projects")
window_hours        = $WINDOW_HOURS
limit_output_tokens = $LIMIT_OUTPUT_TOKENS
limit_cost          = $LIMIT_COST_USD
now    = time.time()
cutoff = now - (window_hours + 1) * 3600  # +1h 버퍼 (세션 시작 정각 감지용)

# 1단계: 6시간 내 모든 메시지 수집
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

# 2단계: 세션 시작 감지 (gap-based — 실제 첫 메시지 timestamp 사용)
# 역방향으로 탐색하여 90분 이상 gap 직후 메시지 = 현재 세션 시작
# → 정각 반올림 없이 Anthropic 리셋 시간과 정확히 일치
SESSION_GAP = 90 * 60
all_msgs.sort(key=lambda x: x[0])

session_start = None
if all_msgs:
    # 90분 이상 비활성이면 현재 세션 없음
    if now - all_msgs[-1][0] >= SESSION_GAP:
        all_msgs = []
    else:
        # 역방향으로 현재 연속 세션의 첫 번째 메시지 탐색
        session_start = all_msgs[0][0]
        for i in range(len(all_msgs) - 1, 0, -1):
            if all_msgs[i][0] - all_msgs[i - 1][0] > SESSION_GAP:
                session_start = all_msgs[i][0]
                break
        # Anthropic은 정각 기준 5시간 rolling — 정각으로 내림
        session_hour = (session_start // 3600) * 3600
        # 세션이 이미 5시간 초과 만료된 경우
        if session_hour + window_hours * 3600 <= now:
            session_start = None
            all_msgs = []

current_msgs = [(e, u) for e, u in all_msgs if session_start and e >= session_hour]

# 3단계: 집계
total_in = total_out = total_cache_c = total_cache_r = 0
msg_count = 0

for epoch, u in current_msgs:
    total_in      += u.get("input_tokens", 0)
    total_out     += u.get("output_tokens", 0)
    total_cache_c += u.get("cache_creation_input_tokens", 0)
    total_cache_r += u.get("cache_read_input_tokens", 0)
    msg_count     += 1

# --- 사용률 % (출력 토큰 기반, 기본 지표) ---
pct_float = min(999.0, total_out * 100 / limit_output_tokens) if limit_output_tokens > 0 else 0.0
pct_int   = int(pct_float)                          # 게이지·색상 계산용 정수
# 소수점 표시: 1% 미만이고 사용량이 있으면 소수점 1자리
if pct_float > 0 and pct_int == 0:
    pct_disp = f"{pct_float:.1f}"
else:
    pct_disp = str(pct_int)

# --- 비용 (참고용) ---
cost_out     = total_out     * 15.00 / 1_000_000
cost_in      = total_in      *  3.00 / 1_000_000
cost_cache_c = total_cache_c *  3.75 / 1_000_000
cost_cache_r = total_cache_r *  0.30 / 1_000_000
total_cost   = cost_out + cost_in + cost_cache_c + cost_cache_r
pct_cost     = min(999, int(total_cost * 100 / limit_cost)) if limit_cost > 0 else 0

# --- 세션 윈도우 ---
if msg_count > 0:
    # Anthropic은 정각 기준 5시간 → window_end는 session_hour 기반
    window_end    = session_hour + window_hours * 3600
    remaining_sec = max(0, int(window_end - now))
    remain_h = remaining_sec // 3600
    remain_m = (remaining_sec % 3600) // 60
    reset_local     = datetime.fromtimestamp(window_end).strftime("%H:%M")
    win_start_local = datetime.fromtimestamp(session_hour).strftime("%H:%M")
else:
    remain_h, remain_m = window_hours, 0
    reset_local = win_start_local = "N/A"

def fmt(n):
    if n >= 1_000_000: return f"{n/1_000_000:.1f}M"
    if n >= 1_000:     return f"{n/1_000:.0f}k"
    return str(n)

filled = min(10, pct_int // 10)
bar    = "█" * filled + "░" * (10 - filled)

print(f"PCT={pct_disp}")
print(f"PCT_INT={pct_int}")
print(f"BAR={bar}")
print(f"MSG={msg_count}")
print(f"OUT_RAW={total_out}")
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
PCT_INT=$(get_val PCT_INT)
BAR=$(get_val BAR)
MSG=$(get_val MSG)
OUT_RAW=$(get_val OUT_RAW)
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
  if   [ "$PCT_INT" -le 20 ]; then GAUGE="▁"
  elif [ "$PCT_INT" -le 40 ]; then GAUGE="▃"
  elif [ "$PCT_INT" -le 60 ]; then GAUGE="▅"
  elif [ "$PCT_INT" -le 80 ]; then GAUGE="▇"
  else                              GAUGE="█"
  fi

  if   [ "$PCT_INT" -le 30 ]; then COLOR="#34C759"
  elif [ "$PCT_INT" -le 60 ]; then COLOR="#FF9F0A"
  elif [ "$PCT_INT" -le 85 ]; then COLOR="#FF6B35"
  else                              COLOR="#FF3B30"
  fi

  echo "Claude ${GAUGE} ${PCT}% | color=${COLOR}"
fi

echo "---"
echo "Claude Code Session Usage | size=14"
echo "---"

if [ -n "$PCT" ] && [ "$MSG" != "0" ]; then
  echo "[${BAR}] ${PCT}% | font=Menlo"
  echo "출력 토큰: ${OUT} / $(echo "$LIMIT_OUTPUT_TOKENS / 1000" | bc)k | color=gray size=12"
  echo "메시지: ${MSG}개 | 비용 참고: \$${COST} (${PCT_COST}%) | color=gray size=11"
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
echo "한도: $(echo "$LIMIT_OUTPUT_TOKENS / 1000" | bc)k tok (1pt 캘리브레이션) | color=gray size=11"
echo "새로고침 | refresh=true"
