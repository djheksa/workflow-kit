#!/bin/bash
# <bitbar.title>Claude Code Usage</bitbar.title>
# <bitbar.version>2.0</bitbar.version>
# <bitbar.desc>Claude Code 사용량 (Anthropic API ratelimit 헤더 기반, 실시간 정확)</bitbar.desc>

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

CACHE_FILE="/tmp/claude-usage-api-cache.txt"
CACHE_TTL=300  # 5분 캐시 (API 호출 최소화)

# ── 캐시 유효 시 → 캐시 데이터 사용 ───────────────────────
if [ -f "$CACHE_FILE" ]; then
  CACHE_AGE=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [ "$CACHE_AGE" -lt "$CACHE_TTL" ]; then
    RESULT=$(cat "$CACHE_FILE")
  fi
fi

# ── 캐시 미스 → API 호출 ────────────────────────────────
if [ -z "$RESULT" ]; then
  RESULT=$(python3 << 'PYEOF'
import json, subprocess, urllib.request, time
from datetime import datetime

# 1. Keychain에서 OAuth 토큰 읽기
try:
    raw = subprocess.check_output(
        ["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
        stderr=subprocess.DEVNULL
    ).decode().strip()
    d = json.loads(raw)
    token = d["claudeAiOauth"]["accessToken"]
except Exception as e:
    print(f"ERROR=토큰 읽기 실패: {e}")
    exit(0)

# 2. v1/messages 호출 (max_tokens=1, ratelimit 헤더 목적)
try:
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps({
            "max_tokens": 1,
            "messages": [{"content": "hi", "role": "user"}],
            "model": "claude-haiku-4-5-20251001"
        }).encode(),
        headers={
            "Authorization": f"Bearer {token}",
            "anthropic-version": "2023-06-01",
            "anthropic-beta": "oauth-2025-04-20",
            "Content-Type": "application/json",
            "User-Agent": "claude-code/2.1.5",
        },
        method="POST"
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        headers = dict(resp.headers)
except urllib.error.HTTPError as e:
    body = e.read().decode()
    print(f"ERROR=HTTP {e.code}: {body[:80]}")
    exit(0)
except Exception as e:
    print(f"ERROR=API 호출 실패: {e}")
    exit(0)

now = time.time()

# 3. ratelimit 헤더 추출
util_5h = float(headers.get("anthropic-ratelimit-unified-5h-utilization", 0))
util_7d = float(headers.get("anthropic-ratelimit-unified-7d-utilization", 0))
reset_5h = int(headers.get("anthropic-ratelimit-unified-5h-reset", 0))

pct_float = util_5h * 100
pct_int = int(pct_float)
pct_disp = f"{pct_float:.1f}" if (pct_float > 0 and pct_int == 0) else str(pct_int)
pct_7d_disp = f"{util_7d * 100:.0f}"

# 4. 세션 시간 계산 (5h-reset 기반)
if reset_5h > 0:
    remaining_sec = max(0, int(reset_5h - now))
    remain_h = remaining_sec // 3600
    remain_m = (remaining_sec % 3600) // 60
    reset_local = datetime.fromtimestamp(reset_5h).strftime("%H:%M")
    win_start_local = datetime.fromtimestamp(reset_5h - 5 * 3600).strftime("%H:%M")
else:
    remain_h, remain_m = 5, 0
    reset_local = win_start_local = "N/A"

# 5. 게이지 바
filled = min(10, pct_int // 10)
bar = "█" * filled + "░" * (10 - filled)

print(f"PCT={pct_disp}")
print(f"PCT_INT={pct_int}")
print(f"PCT_7D={pct_7d_disp}")
print(f"BAR={bar}")
print(f"REMAIN={remain_h}h {remain_m}m")
print(f"RESET={reset_local}")
print(f"WIN_START={win_start_local}")
PYEOF
  )

  # 캐시 저장 (오류 없을 때만)
  if ! echo "$RESULT" | grep -q "^ERROR="; then
    echo "$RESULT" > "$CACHE_FILE"
  fi
fi

# ── 값 파싱 ────────────────────────────────────────────
get_val() { echo "$RESULT" | grep "^$1=" | cut -d= -f2-; }

ERROR=$(get_val ERROR)
PCT=$(get_val PCT)
PCT_INT=$(get_val PCT_INT)
PCT_7D=$(get_val PCT_7D)
BAR=$(get_val BAR)
REMAIN=$(get_val REMAIN)
RESET=$(get_val RESET)
WIN_START=$(get_val WIN_START)

# ── 메뉴바 출력 ────────────────────────────────────────
if [ -n "$ERROR" ]; then
  echo "⚠ Claude | color=#FF3B30"
elif [ -z "$PCT" ] || [ "$PCT_INT" = "0" ]; then
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

if [ -n "$ERROR" ]; then
  echo "오류: $ERROR | color=red"
  echo "새로고침 | refresh=true"
elif [ -n "$PCT" ]; then
  echo "[${BAR}] ${PCT}% | font=Menlo"
  echo "주간 사용량: ${PCT_7D}% | color=gray size=12"
  echo "---"
  echo "세션: ${WIN_START} → ${RESET} | color=gray"
  echo "리셋까지: ${REMAIN} | color=orange"
else
  echo "[░░░░░░░░░░] 0% | font=Menlo"
  echo "---"
  echo "데이터 없음 | color=gray"
fi

echo "---"
echo "새로고침 | refresh=true bash=rm param1=-f param2=$CACHE_FILE terminal=false refresh=true"
