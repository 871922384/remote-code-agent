const fs = require('node:fs');
const path = require('node:path');

function migrate(db) {
  const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  db.exec(schema);
}

module.exports = {
  migrate,
};
