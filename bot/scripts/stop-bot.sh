#!/bin/bash
# Workflow Bot 중지 스크립트

PID_FILE="/tmp/workflow-bot.pid"
STATUS_FILE="/tmp/workflow-bot-status.json"

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    echo "봇 중지됨 (PID: $PID)"
  else
    echo "프로세스가 이미 종료됨"
  fi
  rm -f "$PID_FILE"
else
  # PID 파일 없으면 pkill fallback
  if pkill -f "node src/index.js" 2>/dev/null; then
    echo "봇 중지됨 (pkill)"
  else
    echo "실행 중인 봇 없음"
  fi
fi

# 상태 파일 정리
rm -f "$STATUS_FILE"
osascript -e 'display notification "봇이 중지되었습니다" with title "Workflow Bot"'
