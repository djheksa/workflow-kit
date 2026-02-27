/**
 * 파서 + claude -p 로컬 테스트
 * 실제 Slack에서 수신된 메시지 형식 기반
 */
const { isFormMessage, parseFormMessage, buildTicketPrompt } = require('./src/services/parser');

// 실제 Slack Workflow Form이 보내는 텍스트 (Slack 변환 후 형식)
const SAMPLE_SLACK_TEXT = `:clipboard: *요청사항*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• *유형* *:*  기능 추가
• *제목* *:* 계약 일괄 수정이 오류 발생
• *우선순위* *:* :large_yellow_circle: 보통
• *관련* *화면* *:* 수납관리
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
*상세 설명*

[이슈 내용 / 요청 내용]
테스트 요청건입니다. 문서 작성시 분석 결과는 더미 데이터로 채우세요

[발생 현황 / 요청 배경]
테스트 요청건입니다. 문서 작성시 분석 결과는 더미 데이터로 채우세요

[AS-IS]
테스트 요청건입니다. 문서 작성시 분석 결과는 더미 데이터로 채우세요

[TO-BE]
테스트 요청건입니다. 문서 작성시 분석 결과는 더미 데이터로 채우세요

[기대 효과]
테스트 요청건입니다. 문서 작성시 분석 결과는 더미 데이터로 채우세요
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
*요청자* : <@U_EXAMPLE_USER>
*담당자 :* <@U_EXAMPLE_USER>`;

console.log('=== 1. Form 메시지 감지 테스트 ===');
console.log('isFormMessage:', isFormMessage(SAMPLE_SLACK_TEXT));

console.log('\n=== 2. 파싱 결과 ===');
const parsed = parseFormMessage(SAMPLE_SLACK_TEXT);
console.log(JSON.stringify(parsed, null, 2));

console.log('\n=== 3. Claude 프롬프트 ===');
if (parsed) {
  const prompt = buildTicketPrompt(parsed);
  console.log(prompt);

  // --run 플래그로 실제 claude -p 실행
  if (process.argv.includes('--run')) {
    console.log('\n=== 4. claude -p 실행 ===');
    const { runTicketCreation } = require('./src/services/claude');
    runTicketCreation(prompt)
      .then((result) => {
        console.log('성공:', JSON.stringify(result, null, 2));
      })
      .catch((err) => {
        console.error('실패:', err.message);
      });
  }
}
