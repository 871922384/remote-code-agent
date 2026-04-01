const test = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const { spawn } = require('node:child_process');
const path = require('node:path');

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

function spawnServer(envOverrides) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [serverPath], {
      cwd: projectRoot,
      env: { ...process.env, ...envOverrides },
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });

    child.once('error', reject);
    child.once('close', (code, signal) => {
      resolve({ code, signal, stdout, stderr });
    });
  });
}

test('server exits cleanly with a readable message when the port is already in use', async () => {
  const blocker = net.createServer();
  const address = await listenOnce(blocker, 0);

  try {
    const result = await spawnServer({
      AUTH_TOKEN: 'test-token',
      PORT: String(address.port),
    });

    assert.notEqual(result.code, 0);
    assert.match(
      `${result.stdout}\n${result.stderr}`,
      /port \d+ is already in use/i
    );
  } finally {
    await closeOnce(blocker);
  }
});
