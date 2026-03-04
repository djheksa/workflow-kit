/**
 * Slack Workflow Form 메시지 파서
 *
 * 실제 수신되는 형식 (Slack이 변환한 텍스트):
 *
 * :clipboard: *요청사항*
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * • *유형* *:*  기능 추가
 * • *제목* *:* 멀티 수납취소 기능 개발 요청
 * • *우선순위* *:* :large_yellow_circle: 보통
 * • *관련* *화면* *:* 수납관리
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * *상세 설명*
 * [이슈 내용 / 요청 내용]
 * {여러 줄 자유 입력}
 * [발생 현황 / 요청 배경]
 * {여러 줄 자유 입력}
 * [AS-IS]
 * {여러 줄 자유 입력}
 * [TO-BE]
 * {여러 줄 자유 입력}
 * [기대 효과]
 * {여러 줄 자유 입력}
 * ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 * *요청자* : <@U_EXAMPLE_USER>
 * *담당자 :* <@U_EXAMPLE_USER>
 */

const PRIORITY_EMOJI_MAP = {
  ':red_circle:': '긴급',
  ':large_orange_circle:': '높음',
  ':large_yellow_circle:': '보통',
  ':large_green_circle:': '낮음',
  '🔴': '긴급',
  '🟠': '높음',
  '🟡': '보통',
  '🟢': '낮음',
};

/**
 * Slack 볼드/포맷 마크업 제거
 * "*유형*" → "유형", "• " 제거
 */
function stripSlackFormatting(text) {
  return text
    .replace(/\*/g, '')  // 볼드 제거
    .replace(/^•\s*/, '') // 불릿 제거
    .trim();
}

/**
 * Slack Form 메시지인지 판별
 */
function isFormMessage(text) {
  return text && text.includes('요청사항') && text.includes('━━');
}

/**
 * 헤더 필드(유형, 제목, 우선순위, 관련 화면) 파싱
 * 실제 형식: "• *유형* *:*  기능 추가"
 */
function parseHeaderFields(section) {
  const fields = {};
  const lines = section.split('\n');

  for (const line of lines) {
    // 볼드/불릿 제거 후 파싱
    const cleaned = stripSlackFormatting(line);
    if (!cleaned) continue;

    // "키 : 값" 또는 "키 화면 : 값" 패턴 (콜론 앞뒤 공백 허용)
    const match = cleaned.match(/^(.+?)\s*[:：]\s*(.+)$/);
    if (!match) continue;

    const key = match[1].trim();
    const value = match[2].trim();

    if (key === '유형') {
      fields.type = value;
    } else if (key === '제목') {
      fields.title = value;
    } else if (key === '우선순위') {
      // Slack 이모지 코드 또는 유니코드 이모지에서 우선순위 추출
      const emojiKey = Object.keys(PRIORITY_EMOJI_MAP).find((e) => value.includes(e));
      if (emojiKey) {
        fields.priority = PRIORITY_EMOJI_MAP[emojiKey];
      } else {
        // 이모지 코드 패턴 제거 후 텍스트만
        fields.priority = value.replace(/:[a-z_]+:/g, '').trim() || value;
      }
    } else if ((key.includes('관련') && key.includes('화면')) || key === '관련 화면') {
      fields.screen = value;
    }
  }

  return fields;
}

/**
 * 상세 설명 섹션 파싱
 * [섹션명] 을 기준으로 분리하고, 사이의 모든 내용을 값으로 수집
 */
function parseDescription(section) {
  const parts = {};
  let currentKey = null;
  const lines = section.split('\n');

  for (const line of lines) {
    const trimmed = line.trim();

    // "*상세 설명*" 또는 "상세 설명" 헤더는 건너뜀
    if (stripSlackFormatting(trimmed) === '상세 설명') continue;

    // 섹션 헤더 감지: [이슈 내용 / 요청 내용], [AS-IS], [TO-BE] 등
    const sectionMatch = trimmed.match(/^\[(.+?)\]\s*$/);
    if (sectionMatch) {
      currentKey = sectionMatch[1];
      parts[currentKey] = '';
      continue;
    }

    // 현재 섹션에 내용 추가 (빈 줄도 포함하되 앞뒤 빈 줄은 나중에 trim)
    if (currentKey !== null) {
      if (parts[currentKey]) {
        parts[currentKey] += '\n' + trimmed;
      } else if (trimmed) {
        parts[currentKey] = trimmed;
      }
    }
  }

  // 각 섹션 값의 앞뒤 공백/빈줄 제거
  for (const key of Object.keys(parts)) {
    parts[key] = parts[key].trim();
  }

  return parts;
}

/**
 * 요청자/담당자 파싱
 * 실제 형식: "*요청자* : <@U_EXAMPLE_USER>" 또는 "*담당자 :* <@U_EXAMPLE_USER>"
 */
function parseFooterFields(section) {
  const fields = {};
  const lines = section.split('\n');

  for (const line of lines) {
    const cleaned = stripSlackFormatting(line);
    if (!cleaned) continue;

    // "요청자 : 값" 패턴
    if (cleaned.match(/요청자/)) {
      const match = cleaned.match(/요청자\s*[:：]\s*(.+)/);
      if (match) {
        fields.requester = parseUserMention(match[1].trim());
      }
    }

    // "담당자 : 값" 패턴
    if (cleaned.match(/담당자/)) {
      const match = cleaned.match(/담당자\s*[:：]\s*(.+)/);
      if (match) {
        const value = match[1].trim();
        if (value) {
          fields.assignee = parseUserMention(value);
        }
      }
    }
  }

  return fields;
}

/**
 * Slack 사용자 멘션에서 사용자 ID와 표시 이름 추출
 * "<@U12345>" 형태 또는 "@이름 (English Name)" 형태
 */
function parseUserMention(value) {
  // Slack 멘션 형태: <@U12345>
  const slackMention = value.match(/<@(\w+)>/);
  if (slackMention) {
    return { slackId: slackMention[1], raw: value };
  }

  // 텍스트 형태: @오정현 (Jeonghyun Oh)
  const textMention = value.match(/@?(.+?)(?:\s*\((.+?)\))?$/);
  if (textMention) {
    return { name: textMention[1].trim(), englishName: textMention[2]?.trim(), raw: value };
  }

  return { raw: value };
}

/**
 * Slack Form 메시지를 구조화된 데이터로 파싱
 */
function parseFormMessage(text) {
  // ━━━ 구분선으로 섹션 분리
  const sections = text.split(/━{3,}/);

  if (sections.length < 3) {
    return null;
  }

  // 섹션 0: 📋 요청사항 (헤더)
  // 섹션 1: 유형, 제목, 우선순위, 관련 화면
  // 섹션 2: 상세 설명
  // 섹션 3: 요청자, 담당자
  const headerFields = parseHeaderFields(sections[1]);
  const description = parseDescription(sections[2]);
  const footerFields = parseFooterFields(sections[sections.length - 1]);

  return {
    ...headerFields,
    description,
    ...footerFields,
  };
}

/**
 * 파싱된 데이터를 Claude 프롬프트 문자열로 변환
 */
function buildTicketPrompt(parsed, config = {}) {
  let prompt = `[headless 모드 - 봇 자동 실행]\n세션 초기화, 기능 소개, 환경 체크 없이 바로 워크플로우를 실행할 것.\n`;
  if (config.jiraProjectKey) {
    prompt += `\n## 설정 정보 (파일 읽기 불필요, 이 값을 그대로 사용)\nJira 프로젝트 키: ${config.jiraProjectKey}\nAtlassian 사이트: ${config.atlassianSite || ''}\n`;
  }
  prompt += `\n티켓 생성해줘\n\n`;
  prompt += `유형: ${parsed.type || '기타'}\n`;
  prompt += `제목: ${parsed.title}\n`;
  prompt += `우선순위: ${parsed.priority || '보통'}\n`;
  prompt += `관련 화면: ${parsed.screen || '미지정'}\n`;

  prompt += `\n상세 설명:\n`;
  for (const [key, value] of Object.entries(parsed.description)) {
    if (value) {
      prompt += `[${key}]\n${value}\n\n`;
    }
  }

  const requesterSlackId = parsed.requester?.slackId;
  const assigneeSlackId = parsed.assignee?.slackId;

  if (parsed.requester) {
    const requesterInfo = requesterSlackId
      ? `<@${requesterSlackId}>`
      : (parsed.requester.name || parsed.requester.raw || '미지정');
    prompt += `요청자: ${requesterInfo}\n`;
  }

  if (parsed.assignee) {
    const assigneeInfo = assigneeSlackId
      ? `<@${assigneeSlackId}>`
      : (parsed.assignee.name || parsed.assignee.raw);
    prompt += `담당자: ${assigneeInfo}\n`;
  }

  prompt += `\n## 완료 후 처리 (순서대로 실행)\n`;
  if (config.slackChannel && config.slackTs) {
    prompt += `1. Slack 스레드 댓글 달기: 채널 ${config.slackChannel}, ts ${config.slackTs} 에 스레드 댓글로 "티켓 생성 완료: {티켓번호}\\n{티켓URL}" 형식으로 달 것\n`;
    prompt += `2. 요청자에게 DM: 티켓 번호, 제목, 우선순위, 담당자(없으면 미지정), 링크 포함\n`;
    if (requesterSlackId && assigneeSlackId && requesterSlackId !== assigneeSlackId) {
      prompt += `3. 담당자에게 DM: 티켓 번호, 제목, 요청자, 우선순위, 링크 포함\n`;
    } else if (requesterSlackId === assigneeSlackId) {
      prompt += `3. 요청자와 담당자가 동일하므로 담당자 DM 생략\n`;
    }
  } else {
    prompt += `1. 요청자에게 DM: 티켓 번호, 제목, 우선순위, 담당자(없으면 미지정), 링크 포함\n`;
    if (requesterSlackId && assigneeSlackId && requesterSlackId !== assigneeSlackId) {
      prompt += `2. 담당자에게 DM: 티켓 번호, 제목, 요청자, 우선순위, 링크 포함\n`;
    } else if (requesterSlackId === assigneeSlackId) {
      prompt += `2. 요청자와 담당자가 동일하므로 담당자 DM 생략\n`;
    }
  }

  return prompt;
}

/**
 * 분석 워크플로우 프롬프트 생성
 */
function buildAnalysisPrompt(ticketKey, triggeredBy) {
  return `[headless 모드 - 봇 자동 실행]\n세션 초기화, 기능 소개, 환경 체크 없이 바로 워크플로우를 실행할 것.\n\n분석해줘\n\n티켓: ${ticketKey}\n분석 범위: 전체\n트리거한 사람: ${triggeredBy}\n`;
}

module.exports = {
  isFormMessage,
  parseFormMessage,
  buildTicketPrompt,
  buildAnalysisPrompt,
};
