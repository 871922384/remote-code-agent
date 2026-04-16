const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');

function loadConfig() {
  return {
    port: Number(process.env.PORT || 3333),
    host: process.env.HOST || '127.0.0.1',
    authToken: process.env.DAEMON_AUTH_TOKEN?.trim() || null,
    workspaceRoot: process.env.WORKSPACE_ROOT || path.join(os.homedir(), 'code'),
    daemonDataDir: process.env.DAEMON_DATA_DIR || path.join(os.homedir(), '.remote-code-agent'),
    codexBin: resolveCodexBin(),
  };
}

function resolveCodexBin({
  preferredExecutable = process.env.CODEX_BIN || 'codex',
  environment = process.env,
  executablePath = process.execPath,
  isMacOS = process.platform === 'darwin',
  fileExists = (filePath) => fs.existsSync(filePath),
  shellLookup = lookupCodexWithInteractiveZsh,
} = {}) {
  if (preferredExecutable !== 'codex') {
    return preferredExecutable;
  }

  const siblingCandidate = path.join(path.dirname(executablePath), 'codex');
  if (fileExists(siblingCandidate)) {
    return siblingCandidate;
  }

  const override = environment.REMOTE_CODE_AGENT_CODEX_BIN?.trim();
  if (override) {
    return override;
  }

  const pathCandidate = shellLookup({ environment, interactive: false })?.trim();
  if (pathCandidate) {
    return pathCandidate;
  }

  if (isMacOS) {
    const interactiveCandidate = shellLookup({ environment, interactive: true })?.trim();
    if (interactiveCandidate) {
      return interactiveCandidate;
    }
  }

  return preferredExecutable;
}

function lookupCodexWithInteractiveZsh({
  environment = process.env,
  interactive = true,
} = {}) {
  const result = spawnSync(
    '/bin/zsh',
    [interactive ? '-lic' : '-lc', 'command -v codex'],
    {
      env: environment,
      encoding: 'utf8',
    }
  );
  if (result.status !== 0) {
    return null;
  }

  const resolved = result.stdout?.trim();
  return resolved ? resolved : null;
}

module.exports = {
  loadConfig,
  resolveCodexBin,
};
