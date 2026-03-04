const { spawn, exec } = require('child_process');
const fs = require('fs');
const { notify } = require('./notify');
const config = require('../config');

const STATUS_FILE = '/tmp/workflow-bot-status.json';

function refreshSwiftBar() {
  exec('open -g "swiftbar://refreshplugin?name=workflow-bot"', () => {});
}

function writeStatus(state, task = null) {
  const data = { state, task, updatedAt: new Date().toISOString() };
  try { fs.writeFileSync(STATUS_FILE, JSON.stringify(data)); } catch (_) {}
  refreshSwiftBar();
}

function clearStatus() {
  try { fs.unlinkSync(STATUS_FILE); } catch (_) {}
  refreshSwiftBar();
}

/**
 * 순차 처리 큐
 * MAX 플랜 rate limit 방지를 위해 claude -p 요청을 순차적으로 처리
 */
class ClaudeQueue {
  constructor() {
    this.queue = [];
    this.processing = false;
  }

  enqueue(task) {
    return new Promise((resolve, reject) => {
      this.queue.push({ task, resolve, reject });
      this._processNext();
    });
  }

  async _processNext() {
    if (this.processing || this.queue.length === 0) return;

    this.processing = true;
    const { task, resolve, reject } = this.queue.shift();

    try {
      const result = await task();
      resolve(result);
    } catch (err) {
      reject(err);
    } finally {
      this.processing = false;
      this._processNext();
    }
  }
}

const queue = new ClaudeQueue();

/**
 * claude -p 실행
 *
 * @param {string} prompt - 프롬프트
 * @param {object} options
 * @param {string} options.allowedTools - 허용할 도구 목록
 * @param {number} options.maxTurns - 최대 턴 수
 * @param {number} options.timeoutMs - 타임아웃 (기본 5분)
 * @returns {Promise<{result: string, sessionId: string, usage: object}>}
 */
function runClaude(prompt, options = {}) {
  return queue.enqueue(() => _execute(prompt, options));
}

function _execute(prompt, options) {
  const {
    allowedTools = 'mcp__atlassian__*,mcp__slack__*',
    maxTurns = 15,
    timeoutMs = 5 * 60 * 1000,
  } = options;

  const workDir = config.claude.workDir;

  const args = [
    '-p', prompt,
    '--output-format', 'json',
    '--max-turns', String(maxTurns),
    '--allowedTools', allowedTools,
    '--permission-mode', 'acceptEdits',
  ];

  return new Promise((resolve, reject) => {
    // Claude Code 관련 환경변수 제거 (중첩 세션 차단 방지)
    const env = { ...process.env };
    delete env.CLAUDECODE;
    delete env.CLAUDE_CODE_ENTRYPOINT;

    const proc = spawn('claude', args, {
      cwd: workDir,
      env,
      stdio: ['ignore', 'pipe', 'pipe'], // stdin 닫기 (열려있으면 hang)
    });

    let stdout = '';
    let stderr = '';
    let resolved = false;

    const GRACE_PERIOD = 2 * 1000; // JSON 수신 후 프로세스 종료 대기 2초

    function tryResolveFromStdout() {
      if (resolved) return;
      try {
        const parsed = JSON.parse(stdout);
        // JSON 파싱 성공 = claude -p 작업 완료
        resolved = true;
        clearTimeout(timeout);
        resolve({
          result: parsed.result,
          sessionId: parsed.session_id,
          usage: parsed.usage,
          cost: parsed.cost_usd,
        });
        // 프로세스가 아직 살아있으면 grace period 후 강제 종료
        setTimeout(() => {
          if (!proc.killed) proc.kill('SIGTERM');
        }, GRACE_PERIOD);
      } catch (_) {
        // 아직 JSON이 완성되지 않음, 계속 대기
      }
    }

    proc.stdout.on('data', (data) => {
      stdout += data.toString();
      tryResolveFromStdout();
    });

    proc.stderr.on('data', (data) => {
      const chunk = data.toString();
      stderr += chunk;
      process.stderr.write(`[claude] ${chunk}`);
    });

    const timeout = setTimeout(() => {
      if (!resolved) {
        proc.kill('SIGTERM');
        reject(new Error(`claude -p timed out after ${timeoutMs}ms`));
      }
    }, timeoutMs);

    proc.on('close', (code) => {
      clearTimeout(timeout);

      if (resolved) return; // 이미 stdout JSON으로 resolve됨

      if (code === 0) {
        tryResolveFromStdout();
        if (!resolved) {
          resolved = true;
          resolve({ result: stdout, sessionId: null, usage: null, cost: null });
        }
      } else {
        resolved = true;
        reject(new Error(`claude -p exited with code ${code}: ${stderr}`));
      }
    });

    proc.on('error', (err) => {
      clearTimeout(timeout);
      if (!resolved) {
        resolved = true;
        reject(new Error(`Failed to spawn claude: ${err.message}`));
      }
    });
  });
}

/**
 * 티켓 생성 워크플로우 실행
 */
function runTicketCreation(prompt) {
  writeStatus('processing', 'ticket');
  notify('Workflow Bot', '티켓 생성 처리 중...');
  return runClaude(prompt, {
    allowedTools: 'Read,Glob,Grep,mcp__atlassian__*,mcp__slack__*,mcp__claude_ai_Atlassian__*',
    maxTurns: config.claude.maxTurnsTicket,
  }).finally(() => clearStatus());
}

/**
 * 분석 워크플로우 실행
 */
function runAnalysis(prompt) {
  writeStatus('processing', 'analysis');
  notify('Workflow Bot', '분석 처리 중...');
  return runClaude(prompt, {
    allowedTools: 'Read,Glob,Grep,Bash,mcp__atlassian__*,mcp__slack__*,mcp__claude_ai_Atlassian__*',
    maxTurns: config.claude.maxTurnsAnalysis,
    timeoutMs: 10 * 60 * 1000, // 분석은 10분
  }).finally(() => clearStatus());
}

module.exports = {
  runClaude,
  runTicketCreation,
  runAnalysis,
};
