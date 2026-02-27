#!/bin/bash
# 인프라 스냅샷 서비스 시작 (30분 간격 반복 실행)

SNAPSHOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="/tmp/infra-snapshot.pid"
LOG_FILE="/tmp/infra-snapshot.log"
INTERVAL=1800  # 30분

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    echo "이미 실행 중 (PID: $PID)"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

# 백그라운드 루프 시작
(
  while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 스냅샷 수집 시작" >> "$LOG_FILE"
    bash "$SNAPSHOT_DIR/snapshot.sh" >> "$LOG_FILE" 2>&1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 스냅샷 수집 완료" >> "$LOG_FILE"
    sleep $INTERVAL
  done
) &

echo $! > "$PID_FILE"
echo "인프라 스냅샷 서비스 시작됨 (PID: $(cat "$PID_FILE"), 간격: ${INTERVAL}초)"
osascript -e 'display notification "인프라 스냅샷 서비스가 시작되었습니다" with title "Infra Snapshot"'
