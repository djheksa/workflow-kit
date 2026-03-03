# Claude 사용량 모니터

macOS 메뉴바(SwiftBar)에서 Claude Code 5시간 세션 사용률을 실시간으로 확인한다.

## 동작

- 30초마다 `~/.claude/projects/` 디렉토리의 JSONL 파일을 읽어 출력 토큰 집계
- 사용률에 따라 색상 변경: 초록(0~30%) → 주황(30~60%) → 빨강(60~+%)
- 드롭다운: 세션 시작/종료 시간, 남은 시간, 토큰 breakdown
- `/usage` 결과로 한도 보정(캘리브레이션) 기능 내장

## 요구사항

- macOS
- [SwiftBar](https://github.com/swiftbar/SwiftBar) 설치: `brew install --cask swiftbar`
- Python 3

## 파일

- `swiftbar/claude-usage.30s.sh` — 메뉴바 플러그인
- `swiftbar/scripts/calibrate-claude-usage.sh` — 한도 보정 스크립트

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

## 캘리브레이션

실제 `/usage` 값과 표시값이 다를 경우 메뉴에서 "보정" 클릭:
1. `/usage` 명령으로 현재 세션 사용률 확인
2. SwiftBar 메뉴 > "📐 /usage % 입력해서 보정" 클릭
3. 퍼센트 숫자 입력 → 자동으로 한도 역산 및 가중 평균 적용

## 지표 설명

- **출력 토큰 기반**: 컨텍스트 압축(context compression)을 반영하여 `/usage`와 가장 일치
- **세션 경계**: 정각(hour) 기준으로 감지. 90분 이상 비활성 시 세션 없음으로 표시
