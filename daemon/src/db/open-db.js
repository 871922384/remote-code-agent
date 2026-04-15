const fs = require('node:fs');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');

function openDatabase({ daemonDataDir }) {
  fs.mkdirSync(daemonDataDir, { recursive: true });
  return new DatabaseSync(path.join(daemonDataDir, 'agent-workbench.sqlite'));
}

module.exports = {
  openDatabase,
};
