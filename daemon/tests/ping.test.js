const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const path = require('node:path');
const http = require('node:http');

const daemonRoot = path.join(__dirname, '..');
const entryPath = path.join(daemonRoot, 'src', 'index.js');

function getJson(port, pathname) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port,
      path: pathname,
      method: 'GET',
    }, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve({ statusCode: res.statusCode, body: JSON.parse(data) });
      });
    });
    req.on('error', reject);
    req.end();
  });
}

test('daemon exposes a health endpoint', async () => {
  const child = spawn(process.execPath, [entryPath], {
    cwd: daemonRoot,
    env: {
      ...process.env,
      PORT: '4311',
      WORKSPACE_ROOT: '/tmp/code',
      DAEMON_DATA_DIR: '/tmp/agent-workbench',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let stderr = '';

  child.stderr.on('data', (chunk) => {
    stderr += chunk.toString();
  });

  await new Promise((resolve, reject) => {
    child.stdout.on('data', (chunk) => {
      if (chunk.toString().includes('[daemon] listening')) resolve();
    });
    child.once('error', reject);
    child.once('close', (code) => reject(new Error(`daemon exited with ${code}\n${stderr}`)));
  });

  const response = await getJson(4311, '/health');
  assert.equal(response.statusCode, 200);
  assert.equal(response.body.ok, true);
  assert.equal(response.body.product, 'android-agent-workbench-daemon');

  child.kill('SIGTERM');
});
