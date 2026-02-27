#!/bin/bash
# 인프라 스냅샷 서비스 재시작

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPTS_DIR/stop.sh"
sleep 1
"$SCRIPTS_DIR/start.sh"
