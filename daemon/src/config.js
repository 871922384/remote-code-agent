const os = require('node:os');
const path = require('node:path');

function loadConfig() {
  return {
    port: Number(process.env.PORT || 3333),
    host: process.env.HOST || '127.0.0.1',
    workspaceRoot: process.env.WORKSPACE_ROOT || path.join(os.homedir(), 'code'),
    daemonDataDir: process.env.DAEMON_DATA_DIR || path.join(os.homedir(), '.remote-code-agent'),
    codexBin: process.env.CODEX_BIN || 'codex',
  };
}

module.exports = {
  loadConfig,
};
