# Claude 사용량 모니터

macOS 메뉴바(SwiftBar)에서 Claude Code 5시간 세션 사용률을 실시간으로 확인한다.

## 동작

- Anthropic API(`POST /v1/messages`)를 호출하여 `anthropic-ratelimit-unified-5h-utilization` 헤더로 사용률 조회
- 사용률에 따라 색상 변경: 초록(0~30%) → 주황(30~60%) → 빨강(85~+%)
- 드롭다운: 세션 시작/종료 시간, 남은 시간, 주간 사용률
- 5분 캐시 (`/tmp/claude-usage-api-cache.txt`), 메뉴 > 새로고침으로 강제 갱신

## 요구사항

- macOS
- [SwiftBar](https://github.com/swiftbar/SwiftBar) 설치: `brew install --cask swiftbar`
- Claude Code 설치 (OAuth 토큰 자동 관리)
- Python 3

## 파일

- `swiftbar/claude-usage.30s.sh` — 메뉴바 플러그인

## 설치

```bash
# 1. SwiftBar 설치
brew install --cask swiftbar

# 2. SwiftBar 실행 후 플러그인 폴더로 ~/SwiftBar 선택
open -a SwiftBar

# 3. 심볼릭 링크 생성
ln -s "$(pwd)/swiftbar/claude-usage.30s.sh" ~/SwiftBar/claude-usage.30s.sh

# 4. SwiftBar에서 플러그인 새로고침
```

캘리브레이션 불필요. Claude Code OAuth 토큰을 자동으로 읽어 Anthropic 서버에서 직접 사용률을 조회하므로 항상 정확하다.

## 지표 설명

- **5h-utilization**: 현재 5시간 세션 사용률 (Anthropic 서버 기준)
- **7d-utilization**: 주간 사용률
- **세션 시간**: `5h-reset` 헤더 기준으로 세션 시작/종료 시간 계산
