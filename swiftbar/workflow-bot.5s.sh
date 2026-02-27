#!/bin/bash
# <bitbar.title>Workflow Bot</bitbar.title>
# <bitbar.version>1.0</bitbar.version>
# <bitbar.desc>Workflow Bot 상태 관리</bitbar.desc>

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

PID_FILE="/tmp/workflow-bot.pid"
LOG_FILE="/tmp/workflow-bot.log"
STATUS_FILE="/tmp/workflow-bot-status.json"

# 스크립트 위치 기반 경로 계산 (심볼릭 링크 resolve)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || readlink "$0" 2>/dev/null || echo "$0")")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BOT_DIR="$PROJECT_DIR/bot"
SCRIPTS_DIR="$BOT_DIR/scripts"

# --- 상태 판별 ---

is_running() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    kill -0 "$PID" 2>/dev/null && return 0
    # PID 파일은 있지만 프로세스 없음 → 정리
    rm -f "$PID_FILE"
  fi
  return 1
}

is_processing() {
  # 상태 파일 기반 감지
  if [ -f "$STATUS_FILE" ]; then
    local status
    status=$(cat "$STATUS_FILE" 2>/dev/null)
    if echo "$status" | grep -q '"state":"processing"'; then
      return 0
    fi
  fi
  return 1
}

get_status_detail() {
  if [ -f "$STATUS_FILE" ]; then
    cat "$STATUS_FILE" 2>/dev/null
  fi
}

get_uptime() {
  if [ -f "$PID_FILE" ]; then
    local pid_created
    pid_created=$(stat -f %m "$PID_FILE" 2>/dev/null)
    if [ -n "$pid_created" ]; then
      local now
      now=$(date +%s)
      local diff=$((now - pid_created))
      local hours=$((diff / 3600))
      local mins=$(((diff % 3600) / 60))
      if [ $hours -gt 0 ]; then
        echo "${hours}h ${mins}m"
      else
        echo "${mins}m"
      fi
    fi
  fi
}

get_recent_logs() {
  if [ -f "$LOG_FILE" ]; then
    grep -E "(티켓 생성 완료|분석 완료|티켓 생성 실패|분석 실패)" "$LOG_FILE" | tail -5
  fi
}

# --- 메뉴바 아이콘 ---

if ! is_running; then
  echo "💤 Bot"
else
  if is_processing; then
    # 처리 중 세부 정보
    local_detail=$(get_status_detail)
    task_type=$(echo "$local_detail" | grep -o '"task":"[^"]*"' | head -1 | cut -d'"' -f4)
    case "$task_type" in
      ticket) echo "⚙️ Bot (티켓)" ;;
      analysis) echo "⚙️ Bot (분석)" ;;
      *) echo "⚙️ Bot" ;;
    esac
  else
    echo "🤖 Bot"
  fi
fi

echo "---"

# --- 드롭다운 메뉴 ---

if is_running; then
  PID=$(cat "$PID_FILE")
  UPTIME=$(get_uptime)
  echo "상태: 실행 중 | color=green"
  echo "PID: $PID"
  [ -n "$UPTIME" ] && echo "가동 시간: $UPTIME"
  echo "---"
  echo "봇 중지 | bash=$SCRIPTS_DIR/stop-bot.sh terminal=false refresh=true"
  echo "봇 재시작 | bash=$SCRIPTS_DIR/restart-bot.sh terminal=false refresh=true"
else
  echo "상태: 중지됨 | color=red"
  echo "---"
  echo "봇 시작 | bash=$SCRIPTS_DIR/start-bot.sh terminal=false refresh=true"
fi

echo "---"

# 최근 처리 내역
echo "최근 처리 내역"
RECENT=$(get_recent_logs)
if [ -n "$RECENT" ]; then
  echo "$RECENT" | while IFS= read -r line; do
    # 타임스탬프 제거하고 핵심만 표시
    clean=$(echo "$line" | sed 's/.*\(티켓 생성 완료\|분석 완료\|티켓 생성 실패\|분석 실패\)/\1/')
    echo "--$clean | size=12"
  done
else
  echo "--내역 없음 | color=gray size=12"
fi

echo "---"
echo "로그 보기 | bash=/usr/bin/open param1=-a param2=Terminal param3=/tmp/workflow-bot-tail.command terminal=false"
echo "새로고침 | refresh=true"
