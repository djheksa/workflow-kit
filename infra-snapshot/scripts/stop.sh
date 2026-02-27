#!/bin/bash
# 인프라 스냅샷 서비스 중지

PID_FILE="/tmp/infra-snapshot.pid"
STATUS_FILE="/tmp/infra-snapshot-status.json"

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    echo "서비스 중지됨 (PID: $PID)"
  else
    echo "프로세스가 이미 종료됨"
  fi
  rm -f "$PID_FILE"
else
  echo "실행 중인 서비스 없음"
fi

rm -f "$STATUS_FILE"
osascript -e 'display notification "인프라 스냅샷 서비스가 중지되었습니다" with title "Infra Snapshot"'
