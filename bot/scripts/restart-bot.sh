#!/bin/bash
# Workflow Bot 재시작 스크립트

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPTS_DIR/stop-bot.sh"
sleep 1
"$SCRIPTS_DIR/start-bot.sh"
