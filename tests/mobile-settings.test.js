const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(
  path.join(__dirname, '..', 'public', 'index.html'),
  'utf8'
);

test('settings drawer contract is present', () => {
  assert.match(html, /let settingsDrawerOpen = false;/);
  assert.match(html, /function toggleSettings\(/);
  assert.match(html, /function syncSettingsDrawer\(/);
  assert.match(html, /id="clear-chat-btn"/);
  assert.match(html, /id="connection-pill"/);
});
