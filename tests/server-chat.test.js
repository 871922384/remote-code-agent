const test = require('node:test');
const assert = require('node:assert/strict');
const fsp = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const http = require('node:http');
const net = require('node:net');
const { spawn } = require('node:child_process');

const projectRoot = path.join(__dirname, '..');
const serverPath = path.join(projectRoot, 'server.js');

function listenOnce(server, port) {
  return new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(port, '127.0.0.1', () => {
      server.removeListener('error', reject);
      resolve(server.address());
    });
  });
}

function closeOnce(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    });
  });
}

async function getFreePort() {
  const blocker = net.createServer();
  const address = await listenOnce(blocker, 0);
  await closeOnce(blocker);
  return address.port;
}

function startServer(envOverrides) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [serverPath], {
      cwd: projectRoot,
      env: { ...process.env, ...envOverrides },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';
    let settled = false;

    const timeout = setTimeout(() => {
      if (settled) return;
      settled = true;
      child.kill();
      reject(new Error(`server did not start\nstdout:\n${stdout}\nstderr:\n${stderr}`));
    }, 10000);

    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
      if (!settled && stdout.includes('[Agent] Listening on')) {
        settled = true;
        clearTimeout(timeout);
        resolve({ child, stdoutRef: () => stdout, stderrRef: () => stderr });
      }
    });

    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });

    child.once('error', (error) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      reject(error);
    });

    child.once('close', (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      reject(new Error(`server exited early with code ${code}\nstdout:\n${stdout}\nstderr:\n${stderr}`));
    });
  });
}

function postJson(port, token, body) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port,
      path: '/api/chat',
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-auth-token': token,
      },
    }, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, body: data });
      });
    });

    req.on('error', reject);
    req.write(JSON.stringify(body));
    req.end();
  });
}

async function stopChild(child) {
  if (!child || child.killed || child.exitCode !== null) {
    return;
  }

  child.kill();
  await new Promise((resolve) => child.once('close', resolve));
}

test('server uses codex exec with supported arguments for /api/chat', async () => {
  const tempDir = await fsp.mkdtemp(path.join(os.tmpdir(), 'remote-agent-codex-'));
  const argsPath = path.join(tempDir, 'codex-args.txt');
  const cmdPath = path.join(tempDir, 'codex.cmd');
  await fsp.writeFile(cmdPath, [
    '@echo off',
    `echo %* > "${argsPath}"`,
    'echo Fake Codex OK',
  ].join('\r\n'));

  const port = await getFreePort();
  const token = 'test-token';
  const server = await startServer({
    AUTH_TOKEN: token,
    PORT: String(port),
    CODEX_BIN: cmdPath,
  });

  try {
    const response = await postJson(port, token, {
      engine: 'codex',
      prompt: 'say hello',
      cwd: projectRoot,
    });

    assert.equal(response.statusCode, 200);
    assert.match(response.body, /Fake Codex OK/);

    const args = await fsp.readFile(argsPath, 'utf8');
    assert.match(args, /\bexec\b/);
    assert.match(args, /--skip-git-repo-check/);
    assert.doesNotMatch(args, /--approval-policy/);
  } finally {
    await stopChild(server.child);
    await fsp.rm(tempDir, { recursive: true, force: true });
  }
});

test('server adds --verbose for claude stream-json mode', async () => {
  const tempDir = await fsp.mkdtemp(path.join(os.tmpdir(), 'remote-agent-claude-'));
  const argsPath = path.join(tempDir, 'claude-args.txt');
  const cmdPath = path.join(tempDir, 'claude.cmd');
  await fsp.writeFile(cmdPath, [
    '@echo off',
    `echo %* > "${argsPath}"`,
    'echo {"type":"assistant","message":{"content":[{"type":"text","text":"Fake Claude OK"}]}}',
  ].join('\r\n'));

  const port = await getFreePort();
  const token = 'test-token';
  const server = await startServer({
    AUTH_TOKEN: token,
    PORT: String(port),
    CLAUDE_BIN: cmdPath,
  });

  try {
    const response = await postJson(port, token, {
      engine: 'claude',
      prompt: 'say hello',
      cwd: projectRoot,
    });

    assert.equal(response.statusCode, 200);
    assert.match(response.body, /Fake Claude OK/);

    const args = await fsp.readFile(argsPath, 'utf8');
    assert.match(args, /--output-format stream-json/);
    assert.match(args, /--verbose/);
  } finally {
    await stopChild(server.child);
    await fsp.rm(tempDir, { recursive: true, force: true });
  }
});

test('server injects Anthropic-compatible env into Claude child process only', async () => {
  const tempDir = await fsp.mkdtemp(path.join(os.tmpdir(), 'remote-agent-claude-env-'));
  const envPath = path.join(tempDir, 'claude-env.txt');
  const cmdPath = path.join(tempDir, 'claude.cmd');
  await fsp.writeFile(cmdPath, [
    '@echo off',
    `echo ANTHROPIC_BASE_URL=%ANTHROPIC_BASE_URL%> "${envPath}"`,
    `echo ANTHROPIC_API_KEY=%ANTHROPIC_API_KEY%>> "${envPath}"`,
    'echo {"type":"assistant","message":{"content":[{"type":"text","text":"Claude env OK"}]}}',
  ].join('\r\n'));

  const port = await getFreePort();
  const token = 'test-token';
  const server = await startServer({
    AUTH_TOKEN: token,
    PORT: String(port),
    CLAUDE_BIN: cmdPath,
    CLAUDE_ANTHROPIC_BASE_URL: 'https://anthropic-compatible.example/v1',
    CLAUDE_ANTHROPIC_API_KEY: 'provider-key',
  });

  try {
    const response = await postJson(port, token, {
      engine: 'claude',
      prompt: 'say hello',
      cwd: projectRoot,
    });

    assert.equal(response.statusCode, 200);
    assert.match(response.body, /Claude env OK/);

    const envDump = await fsp.readFile(envPath, 'utf8');
    assert.match(envDump, /ANTHROPIC_BASE_URL=https:\/\/anthropic-compatible\.example\/v1/);
    assert.match(envDump, /ANTHROPIC_API_KEY=provider-key/);
  } finally {
    await stopChild(server.child);
    await fsp.rm(tempDir, { recursive: true, force: true });
  }
});

test('server supports Claude AUTH_TOKEN-style overrides used by config switchers', async () => {
  const tempDir = await fsp.mkdtemp(path.join(os.tmpdir(), 'remote-agent-claude-auth-token-'));
  const envPath = path.join(tempDir, 'claude-env.txt');
  const cmdPath = path.join(tempDir, 'claude.cmd');
  await fsp.writeFile(cmdPath, [
    '@echo off',
    `echo ANTHROPIC_BASE_URL=%ANTHROPIC_BASE_URL%> "${envPath}"`,
    `echo ANTHROPIC_AUTH_TOKEN=%ANTHROPIC_AUTH_TOKEN%>> "${envPath}"`,
    `echo ANTHROPIC_API_KEY=%ANTHROPIC_API_KEY%>> "${envPath}"`,
    'echo {"type":"assistant","message":{"content":[{"type":"text","text":"Claude auth token OK"}]}}',
  ].join('\r\n'));

  const port = await getFreePort();
  const token = 'test-token';
  const server = await startServer({
    AUTH_TOKEN: token,
    PORT: String(port),
    CLAUDE_BIN: cmdPath,
    CLAUDE_ANTHROPIC_BASE_URL: 'https://anthropic-compatible.example/v1',
    CLAUDE_ANTHROPIC_AUTH_TOKEN: 'provider-auth-token',
  });

  try {
    const response = await postJson(port, token, {
      engine: 'claude',
      prompt: 'say hello',
      cwd: projectRoot,
    });

    assert.equal(response.statusCode, 200);
    assert.match(response.body, /Claude auth token OK/);

    const envDump = await fsp.readFile(envPath, 'utf8');
    assert.match(envDump, /ANTHROPIC_BASE_URL=https:\/\/anthropic-compatible\.example\/v1/);
    assert.match(envDump, /ANTHROPIC_AUTH_TOKEN=provider-auth-token/);
  } finally {
    await stopChild(server.child);
    await fsp.rm(tempDir, { recursive: true, force: true });
  }
});
