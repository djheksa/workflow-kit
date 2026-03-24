#!/bin/bash
# Workflow Bot 시작 스크립트

# SwiftBar 등 GUI 환경에서 nvm PATH 누락 보완
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh" --no-use
export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$NVM_DIR/versions/node/$(ls "$NVM_DIR/versions/node" 2>/dev/null | sort -V | tail -1)/bin:$PATH"

BOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="/tmp/workflow-bot.pid"
LOG_FILE="/tmp/workflow-bot.log"

# 이미 실행 중인지 확인
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    echo "이미 실행 중 (PID: $PID)"
    exit 0
  fi
  # PID 파일은 있지만 프로세스가 없음 → 정리
  rm -f "$PID_FILE"
fi

# 봇 시작
cd "$BOT_DIR"
nohup node src/index.js >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

echo "봇 시작됨 (PID: $(cat "$PID_FILE"))"
osascript -e 'display notification "봇이 시작되었습니다" with title "Workflow Bot"'
