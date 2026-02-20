# Confluence 문서 작업 규칙

## 문서 작성
- Confluence PE 스페이스의 "신규 개발자 공통 가이드" 문서를 템플릿으로 참고하여 문서 작성
- 체계화된 문서 구축 지향 (제목, 폴더 구조, 일관된 형식)
- 앵커 링크, 텍스트 링크 설정 시 반드시 실제로 연결되는지 확인할 것

## 문서 수정 원칙
- 문서 업데이트 시 기존 스타일/디자인을 절대 건드리지 말 것
- 반드시 원본 storage format(HTML)을 보존하면서 필요한 부분만 삽입/수정할 것
- 수정 절차:
  1. 현재 페이지 storage format을 `convert_to_markdown=false`로 가져오기
  2. Python으로 삽입 위치(마커)를 찾아 정확한 지점에만 새 content 삽입
  3. `content_format="storage"`로 업데이트 (markdown 포맷 사용 금지)
- MCP 도구로 대용량 content 전달이 어려울 경우 Confluence REST API 직접 호출 (curl + API 토큰)
- 전체 내용을 markdown으로 교체하는 방식은 절대 사용 금지 (기존 스타일 손실)

## 문서 삭제
- 문서 삭제는 사용자가 직접 수행함
- 삭제 대상 문서는 제목에 `[Deprecated]` 표시만 추가할 것
