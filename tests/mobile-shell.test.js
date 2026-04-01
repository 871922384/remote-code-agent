const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(
  path.join(__dirname, '..', 'public', 'index.html'),
  'utf8'
);

test('mobile shell exposes the core Codex-style regions', () => {
  assert.match(html, /id="top-bar"/);
  assert.match(html, /id="engine-switch"/);
  assert.match(html, /id="session-feed"/);
  assert.match(html, /id="composer"/);
  assert.match(html, /id="settings-drawer"/);
});
