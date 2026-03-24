/**
 * retry.js + startup.js 로직 단위 테스트
 * Slack client를 목(mock)으로 대체하여 실제 API 호출 없이 검증
 */
const assert = require('assert');
const { isFormMessage } = require('../src/services/parser');
const { scanUnprocessed } = require('../src/services/startup');

// ─── 테스트 데이터 ─────────────────────────────────────────────

const FORM_MSG_TEXT = `:clipboard: *요청사항*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• *유형* *:*  기능 추가
• *제목* *:* 테스트 재처리 기능
• *우선순위* *:* :large_yellow_circle: 보통
• *관련* *화면* *:* 테스트화면
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
*상세 설명*
[이슈 내용 / 요청 내용]
테스트용 요청입니다

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
*요청자* : <@U0ATEST01>`;

const PROCESSED_FORM_MSG = {
  ts: '1000000000.000001',
  text: FORM_MSG_TEXT,
  reactions: [{ name: 'ticket', count: 1 }], // 이미 처리됨
};

const UNPROCESSED_FORM_MSG = {
  ts: '1000000000.000002',
  text: FORM_MSG_TEXT,
  reactions: [{ name: 'x', count: 1 }], // 실패 상태
};

const UNPROCESSED_NO_REACTION = {
  ts: '1000000000.000003',
  text: FORM_MSG_TEXT,
  reactions: [], // 아무 처리 안 됨
};

const NORMAL_MSG = {
  ts: '1000000000.000004',
  text: '그냥 일반 메시지',
  reactions: [],
};

const THREAD_REPLY = {
  ts: '1000000000.000005',
  thread_ts: '999999999.000000', // 스레드 답글 (ts !== thread_ts)
  text: FORM_MSG_TEXT,
  reactions: [],
};

// ─── Mock Slack Client ────────────────────────────────────────

function createMockClient(messages, threadRepliesMap = {}, runTicketFn = async () => {}) {
  const calls = {
    history: [],
    replies: [],
    reactionsAdd: [],
    reactionsRemove: [],
    postMessage: [],
  };

  const client = {
    _calls: calls,
    conversations: {
      history: async ({ channel, oldest, limit }) => {
        calls.history.push({ channel, oldest, limit });
        return { messages };
      },
      replies: async ({ channel, ts }) => {
        calls.replies.push({ channel, ts });
        return { messages: threadRepliesMap[ts] || [{ ts, text: FORM_MSG_TEXT }] };
      },
    },
    reactions: {
      add: async ({ channel, timestamp, name }) => {
        calls.reactionsAdd.push({ channel, timestamp, name });
      },
      remove: async ({ channel, timestamp, name }) => {
        calls.reactionsRemove.push({ channel, timestamp, name });
      },
    },
    chat: {
      postMessage: async (args) => {
        calls.postMessage.push(args);
      },
    },
  };

  return client;
}

const TEST_CONFIG = {
  slack: { channelId: 'C0TEST' },
  jira: { projectKey: 'TEST' },
  atlassian: { site: 'test.atlassian.net' },
};

// ─── 테스트 헬퍼 ─────────────────────────────────────────────

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    const result = fn();
    if (result && typeof result.then === 'function') {
      return result
        .then(() => { console.log(`  ✓ ${name}`); passed++; })
        .catch((err) => { console.error(`  ✗ ${name}\n    ${err.message}`); failed++; });
    }
    console.log(`  ✓ ${name}`);
    passed++;
  } catch (err) {
    console.error(`  ✗ ${name}\n    ${err.message}`);
    failed++;
  }
  return Promise.resolve();
}

// ─── isFormMessage 빠른 검증 ─────────────────────────────────

console.log('\n[재시도 판단: isFormMessage]');

test('Form 메시지 정상 감지', () => {
  assert.strictEqual(isFormMessage(FORM_MSG_TEXT), true);
});

test('일반 메시지는 재시도 대상 아님', () => {
  assert.strictEqual(isFormMessage('안녕하세요'), false);
});

// ─── scanUnprocessed 로직 테스트 ─────────────────────────────

console.log('\n[startup.scanUnprocessed]');

const runTests = async () => {
  await test('SLACK_CHANNEL_ID 없으면 스캔 건너뜀', async () => {
    const client = createMockClient([]);
    const config = { ...TEST_CONFIG, slack: { channelId: null } };
    await scanUnprocessed(client, config);
    assert.strictEqual(client._calls.history.length, 0);
  });

  await test('ticket 이모지 있는 메시지는 재처리 안 함', async () => {
    const client = createMockClient([PROCESSED_FORM_MSG]);
    await scanUnprocessed(client, TEST_CONFIG);
    // history는 호출되지만 ticket 생성(reactionsAdd hourglass)은 없어야 함
    const hourglassAdded = client._calls.reactionsAdd.some((r) => r.name === 'hourglass_flowing_sand');
    assert.strictEqual(hourglassAdded, false);
  });

  await test('일반 메시지는 재처리 안 함', async () => {
    const client = createMockClient([NORMAL_MSG]);
    await scanUnprocessed(client, TEST_CONFIG);
    const hourglassAdded = client._calls.reactionsAdd.some((r) => r.name === 'hourglass_flowing_sand');
    assert.strictEqual(hourglassAdded, false);
  });

  await test('스레드 답글(thread_ts != ts)은 재처리 안 함', async () => {
    const client = createMockClient([THREAD_REPLY]);
    await scanUnprocessed(client, TEST_CONFIG);
    const hourglassAdded = client._calls.reactionsAdd.some((r) => r.name === 'hourglass_flowing_sand');
    assert.strictEqual(hourglassAdded, false);
  });

  await test('미처리 메시지에서 x 이모지 제거 후 hourglass 추가', async () => {
    // runTicketCreation을 목으로 대체 (모듈 캐시 우회)
    const startup = require('../src/services/startup');
    const originalModule = require('../src/services/claude');
    const originalFn = originalModule.runTicketCreation;
    originalModule.runTicketCreation = async () => {}; // no-op

    const client = createMockClient([UNPROCESSED_FORM_MSG], {
      '1000000000.000002': [{ ts: '1000000000.000002', text: FORM_MSG_TEXT }], // 스레드에 티켓 없음
    });

    await startup.scanUnprocessed(client, TEST_CONFIG);

    const xRemoved = client._calls.reactionsRemove.some((r) => r.name === 'x');
    const hourglassAdded = client._calls.reactionsAdd.some((r) => r.name === 'hourglass_flowing_sand');
    assert.strictEqual(xRemoved, true, 'x 이모지가 제거되어야 함');
    assert.strictEqual(hourglassAdded, true, 'hourglass 이모지가 추가되어야 함');

    originalModule.runTicketCreation = originalFn; // 복원
  });

  await test('스레드에 티켓 번호 있으면 재처리 안 함', async () => {
    const client = createMockClient([UNPROCESSED_NO_REACTION], {
      '1000000000.000003': [
        { ts: '1000000000.000003', text: FORM_MSG_TEXT },
        { ts: '1000000000.000003-reply', text: '티켓 생성 완료: TEST-999' }, // 티켓 번호 있음
      ],
    });

    await scanUnprocessed(client, TEST_CONFIG);

    const hourglassAdded = client._calls.reactionsAdd.some((r) => r.name === 'hourglass_flowing_sand');
    assert.strictEqual(hourglassAdded, false, '스레드에 티켓 있으면 재처리하면 안 됨');
  });

  await test('성공 시 ticket 이모지 추가', async () => {
    const originalModule = require('../src/services/claude');
    const originalFn = originalModule.runTicketCreation;
    originalModule.runTicketCreation = async () => {};

    const client = createMockClient([UNPROCESSED_NO_REACTION], {
      '1000000000.000003': [{ ts: '1000000000.000003', text: FORM_MSG_TEXT }],
    });

    const startup = require('../src/services/startup');
    await startup.scanUnprocessed(client, TEST_CONFIG);

    const ticketAdded = client._calls.reactionsAdd.some((r) => r.name === 'ticket');
    assert.strictEqual(ticketAdded, true, '성공 시 ticket 이모지가 추가되어야 함');

    originalModule.runTicketCreation = originalFn;
  });

  await test('Claude 실패 시 x 이모지 추가', async () => {
    const originalModule = require('../src/services/claude');
    const originalFn = originalModule.runTicketCreation;
    originalModule.runTicketCreation = async () => { throw new Error('claude 실패'); };

    const client = createMockClient([UNPROCESSED_NO_REACTION], {
      '1000000000.000003': [{ ts: '1000000000.000003', text: FORM_MSG_TEXT }],
    });

    const startup = require('../src/services/startup');
    await startup.scanUnprocessed(client, TEST_CONFIG);

    const xAdded = client._calls.reactionsAdd.some((r) => r.name === 'x');
    assert.strictEqual(xAdded, true, '실패 시 x 이모지가 추가되어야 함');

    originalModule.runTicketCreation = originalFn;
  });

  // 결과 출력
  console.log(`\n총 ${passed + failed}개 | 통과 ${passed}개 | 실패 ${failed}개\n`);
  if (failed > 0) process.exit(1);
};

runTests().catch((err) => {
  console.error('테스트 실행 중 예외:', err);
  process.exit(1);
});
