const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(
  path.join(__dirname, '..', 'public', 'index.html'),
  'utf8'
);

test('feed renderer exposes the mobile session state hooks', () => {
  assert.match(html, /let messages = \[\];/);
  assert.match(html, /function renderFeed\(\)/);
  assert.match(html, /function addUserMessage\(/);
  assert.match(html, /function startAgentRun\(/);
  assert.match(html, /function appendRunChunk\(/);
  assert.match(html, /function finishAgentRun\(/);
});
