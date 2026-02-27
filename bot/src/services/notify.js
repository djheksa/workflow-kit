const { exec } = require('child_process');

/**
 * macOS 알림 발송
 * @param {string} title - 알림 제목
 * @param {string} message - 알림 본문
 */
function notify(title, message) {
  const t = title.replace(/"/g, '\\"');
  const m = message.replace(/"/g, '\\"');
  exec(`osascript -e 'display notification "${m}" with title "${t}"'`, (err, stdout, stderr) => {
    if (err) console.error(`[notify] 알림 실패: ${err.message}`);
    if (stderr) console.error(`[notify] stderr: ${stderr}`);
  });
}

module.exports = { notify };
