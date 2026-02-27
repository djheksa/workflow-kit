#!/bin/bash
# <bitbar.title>Infra Snapshot Service</bitbar.title>
# <bitbar.version>1.0</bitbar.version>
# <bitbar.author></bitbar.author>
# <bitbar.desc>AWS 인프라 스냅샷 서비스 상태 관리</bitbar.desc>

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

PID_FILE="/tmp/infra-snapshot.pid"
LOG_FILE="/tmp/infra-snapshot.log"
STATUS_FILE="/tmp/infra-snapshot-status.json"
SNAPSHOT_FILE="/tmp/infra-snapshot.md"
# 스크립트 위치 기반 경로 계산 (심볼릭 링크 resolve)
REAL_SCRIPT="$(readlink -f "$0" 2>/dev/null || readlink "$0" 2>/dev/null || echo "$0")"
SWIFTBAR_DIR="$(cd "$(dirname "$REAL_SCRIPT")" && pwd)"
PROJECT_DIR="$(cd "$SWIFTBAR_DIR/.." && pwd)"
SCRIPTS_DIR="$PROJECT_DIR/infra-snapshot/scripts"

# --- 상태 판별 ---

is_running() {
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    kill -0 "$PID" 2>/dev/null && return 0
    rm -f "$PID_FILE"
  fi
  return 1
}

is_collecting() {
  if [ -f "$STATUS_FILE" ]; then
    grep -q '"state":"running"' "$STATUS_FILE" 2>/dev/null && return 0
  fi
  return 1
}

get_phase() {
  if [ -f "$STATUS_FILE" ]; then
    python3 -c "import json; print(json.load(open('$STATUS_FILE')).get('phase',''))" 2>/dev/null
  fi
}

get_uptime() {
  if [ -f "$PID_FILE" ]; then
    local pid_created
    pid_created=$(stat -f %m "$PID_FILE" 2>/dev/null)
    if [ -n "$pid_created" ]; then
      local now diff hours mins
      now=$(date +%s)
      diff=$((now - pid_created))
      hours=$((diff / 3600))
      mins=$(((diff % 3600) / 60))
      if [ $hours -gt 0 ]; then
        echo "${hours}h ${mins}m"
      else
        echo "${mins}m"
      fi
    fi
  fi
}

get_snapshot_age() {
  if [ -f "$SNAPSHOT_FILE" ]; then
    local file_time now diff mins
    file_time=$(stat -f %m "$SNAPSHOT_FILE" 2>/dev/null)
    now=$(date +%s)
    diff=$((now - file_time))
    mins=$((diff / 60))
    if [ $mins -lt 60 ]; then
      echo "${mins}분 전"
    else
      echo "$((mins / 60))시간 전"
    fi
  else
    echo "없음"
  fi
}

# --- 메뉴바 아이콘 ---

if ! is_running; then
  echo "🔌"
else
  if is_collecting; then
    phase=$(get_phase)
    case "$phase" in
      ecs) echo "📡 ecs" ;;
      route53) echo "📡 dns" ;;
      alb) echo "📡 alb" ;;
      cloudfront) echo "📡 cdn" ;;
      nginx) echo "📡 ngx" ;;
      codebuild) echo "📡 cb" ;;
      rds) echo "📡 rds" ;;
      elasticache) echo "📡 redis" ;;
      s3) echo "📡 s3" ;;
      ecr) echo "📡 ecr" ;;
      ses) echo "📡 ses" ;;
      params) echo "📡 param" ;;
      *) echo "📡" ;;
    esac
  else
    echo "📊"
  fi
fi

echo "---"

# --- 드롭다운 메뉴 ---

echo "AWS Infra Snapshot | size=14"
echo "---"

if is_running; then
  PID=$(cat "$PID_FILE")
  UPTIME=$(get_uptime)
  SNAPSHOT_AGE=$(get_snapshot_age)
  echo "상태: 실행 중 | color=green"
  echo "PID: $PID"
  [ -n "$UPTIME" ] && echo "가동 시간: $UPTIME"
  echo "스냅샷: $SNAPSHOT_AGE"
  echo "---"
  echo "지금 수집 | bash=$SCRIPTS_DIR/../snapshot.sh terminal=false refresh=true"
  echo "서비스 중지 | bash=$SCRIPTS_DIR/stop.sh terminal=false refresh=true"
  echo "서비스 재시작 | bash=$SCRIPTS_DIR/restart.sh terminal=false refresh=true"
else
  SNAPSHOT_AGE=$(get_snapshot_age)
  echo "상태: 중지됨 | color=red"
  echo "마지막 스냅샷: $SNAPSHOT_AGE"
  echo "---"
  echo "서비스 시작 | bash=$SCRIPTS_DIR/start.sh terminal=false refresh=true"
  [ -f "$SNAPSHOT_FILE" ] && echo "지금 수집 (1회) | bash=$SCRIPTS_DIR/../snapshot.sh terminal=false refresh=true"
fi

echo "---"

# 스냅샷 파일 열기
if [ -f "$SNAPSHOT_FILE" ]; then
  echo "스냅샷 파일 보기 | bash=/usr/bin/open param1=$SNAPSHOT_FILE terminal=false"
fi

echo "로그 보기 | bash=/usr/bin/open param1=-a param2=Console param3=$LOG_FILE terminal=false"
echo "---"
echo "새로고침 | refresh=true"
