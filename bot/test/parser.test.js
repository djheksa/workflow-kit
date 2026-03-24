/**
 * parser.js 단위 테스트
 * Node.js 내장 assert 사용 (외부 의존 없음)
 */
const assert = require('assert');
const { isFormMessage, parseFormMessage, buildTicketPrompt } = require('../src/services/parser');

// ─── 테스트 데이터 ─────────────────────────────────────────────

const FORM_MESSAGE_FULL = `:clipboard: *요청사항*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• *유형* *:*  기능 추가
• *제목* *:* 멀티 수납취소 기능 개발 요청
• *우선순위* *:* :large_yellow_circle: 보통
• *관련* *화면* *:* 수납관리
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
*상세 설명*
[이슈 내용 / 요청 내용]
시스템 개선건 입니다

[AS-IS]
현재는 한달 한건 씩만 취소가능

[TO-BE]
체크박스가 생성되어 멀티 수납취소 기능 개발

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
*요청자* : <@U0A1BCDEF>
*담당자 :* <@U0A9XYZAB>`;

const FORM_MESSAGE_NO_ASSIGNEE = `:clipboard: *요청사항*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• *유형* *:*  버그
• *제목* *:* 계약 상태 변경 시 오류 발생
• *우선순위* *:* :red_circle: 긴급
• *관련* *화면* *:* 계약관리
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
*상세 설명*
[이슈 내용 / 요청 내용]
계약 목록에서 일괄 변경 시 오류 발생

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
*요청자* : <@U0A1BCDEF>`;

const NOT_FORM_MESSAGE = '일반 메시지입니다. 안녕하세요!';
const PARTIAL_MESSAGE = ':clipboard: *요청사항* 이지만 구분선이 없음';

// ─── 테스트 헬퍼 ─────────────────────────────────────────────

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ✓ ${name}`);
    passed++;
  } catch (err) {
    console.error(`  ✗ ${name}`);
    console.error(`    ${err.message}`);
    failed++;
  }
}

// ─── isFormMessage 테스트 ────────────────────────────────────

console.log('\n[isFormMessage]');

test('Form 메시지 감지', () => {
  assert.strictEqual(isFormMessage(FORM_MESSAGE_FULL), true);
});

test('담당자 없는 Form 메시지 감지', () => {
  assert.strictEqual(isFormMessage(FORM_MESSAGE_NO_ASSIGNEE), true);
});

test('일반 메시지는 false', () => {
  assert.strictEqual(isFormMessage(NOT_FORM_MESSAGE), false);
});

test('구분선 없으면 false', () => {
  assert.strictEqual(isFormMessage(PARTIAL_MESSAGE), false);
});

test('null/undefined 처리', () => {
  assert.strictEqual(isFormMessage(null), false);
  assert.strictEqual(isFormMessage(undefined), false);
  assert.strictEqual(isFormMessage(''), false);
});

// ─── parseFormMessage 테스트 ─────────────────────────────────

console.log('\n[parseFormMessage]');

test('기본 필드 파싱', () => {
  const parsed = parseFormMessage(FORM_MESSAGE_FULL);
  assert.ok(parsed, 'parsed가 null이 아니어야 함');
  assert.strictEqual(parsed.type, '기능 추가');
  assert.strictEqual(parsed.title, '멀티 수납취소 기능 개발 요청');
  assert.strictEqual(parsed.priority, '보통');
  assert.strictEqual(parsed.screen, '수납관리');
});

test('요청자/담당자 Slack ID 파싱', () => {
  const parsed = parseFormMessage(FORM_MESSAGE_FULL);
  assert.strictEqual(parsed.requester?.slackId, 'U0A1BCDEF');
  assert.strictEqual(parsed.assignee?.slackId, 'U0A9XYZAB');
});

test('담당자 없는 경우 undefined', () => {
  const parsed = parseFormMessage(FORM_MESSAGE_NO_ASSIGNEE);
  assert.ok(parsed.requester?.slackId);
  assert.strictEqual(parsed.assignee, undefined);
});

test('상세 설명 파싱', () => {
  const parsed = parseFormMessage(FORM_MESSAGE_FULL);
  assert.ok(parsed.description['이슈 내용 / 요청 내용']);
  assert.ok(parsed.description['AS-IS']);
  assert.ok(parsed.description['TO-BE']);
});

test('긴급 우선순위 파싱', () => {
  const parsed = parseFormMessage(FORM_MESSAGE_NO_ASSIGNEE);
  assert.strictEqual(parsed.priority, '긴급');
  assert.strictEqual(parsed.type, '버그');
});

test('구분선 부족 시 null 반환', () => {
  const result = parseFormMessage(PARTIAL_MESSAGE);
  assert.strictEqual(result, null);
});

// ─── buildTicketPrompt 테스트 ────────────────────────────────

console.log('\n[buildTicketPrompt]');

test('프롬프트 기본 구조 포함', () => {
  const parsed = parseFormMessage(FORM_MESSAGE_FULL);
  const prompt = buildTicketPrompt(parsed, {
    jiraProjectKey: 'TEST',
    atlassianSite: 'test.atlassian.net',
    slackChannel: 'C0TEST',
    slackTs: '1234567890.123456',
  });
  assert.ok(prompt.includes('[headless 모드'));
  assert.ok(prompt.includes('티켓 생성해줘'));
  assert.ok(prompt.includes('멀티 수납취소'));
  assert.ok(prompt.includes('보통'));
  assert.ok(prompt.includes('C0TEST'));
  assert.ok(prompt.includes('1234567890.123456'));
});

test('요청자=담당자일 때 담당자 DM 생략 지시 포함', () => {
  // 같은 slackId로 강제 설정
  const parsed = parseFormMessage(FORM_MESSAGE_FULL);
  parsed.requester = { slackId: 'USAME' };
  parsed.assignee = { slackId: 'USAME' };

  const prompt = buildTicketPrompt(parsed, { jiraProjectKey: 'TEST', atlassianSite: 'test.atlassian.net' });
  assert.ok(prompt.includes('담당자 DM 생략'));
});

test('담당자 없을 때 담당자 DM 단계 없음', () => {
  const parsed = parseFormMessage(FORM_MESSAGE_NO_ASSIGNEE);
  const prompt = buildTicketPrompt(parsed, { jiraProjectKey: 'TEST', atlassianSite: 'test.atlassian.net' });
  assert.ok(!prompt.includes('담당자 DM'));
});

// ─── 결과 출력 ───────────────────────────────────────────────

console.log(`\n총 ${passed + failed}개 | 통과 ${passed}개 | 실패 ${failed}개\n`);
if (failed > 0) process.exit(1);
