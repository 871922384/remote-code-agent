const test = require('node:test');
const assert = require('node:assert/strict');

const { resolveCodexBin } = require('../src/config');

test('resolveCodexBin prefers a sibling codex next to the current node executable', () => {
  const codexBin = resolveCodexBin({
    preferredExecutable: 'codex',
    environment: {},
    executablePath: '/Users/rex/.nvm/versions/node/v24.14.1/bin/node',
    fileExists: (path) => path === '/Users/rex/.nvm/versions/node/v24.14.1/bin/codex',
    shellLookup: () => null,
  });

  assert.equal(codexBin, '/Users/rex/.nvm/versions/node/v24.14.1/bin/codex');
});

test('resolveCodexBin falls back to an interactive shell lookup on macOS', () => {
  const codexBin = resolveCodexBin({
    preferredExecutable: 'codex',
    environment: {},
    executablePath: '/Applications/Agent Workbench.app/Contents/Resources/bin/node',
    isMacOS: true,
    fileExists: () => false,
    shellLookup: () => '/Users/rex/.nvm/versions/node/v24.14.1/bin/codex\n',
  });

  assert.equal(codexBin, '/Users/rex/.nvm/versions/node/v24.14.1/bin/codex');
});
