const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const html = fs.readFileSync(
  path.join(__dirname, '..', 'public', 'index.html'),
  'utf8'
);

test('mobile style contract is present', () => {
  assert.match(html, /\.app-shell\s*\{/);
  assert.match(html, /\.top-bar\s*\{/);
  assert.match(html, /\.engine-chip\s*\{/);
  assert.match(html, /\.run-card\s*\{/);
  assert.match(html, /\.settings-sheet\s*\{/);
  assert.match(html, /@media\s*\(min-width:\s*768px\)/);
});
