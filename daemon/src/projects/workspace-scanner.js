const fs = require('node:fs');
const path = require('node:path');

function listWorkspaceProjects(workspaceRoot) {
  return fs.readdirSync(workspaceRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => ({
      id: path.join(workspaceRoot, entry.name),
      name: entry.name,
      path: path.join(workspaceRoot, entry.name),
    }))
    .sort((left, right) => left.name.localeCompare(right.name));
}

module.exports = {
  listWorkspaceProjects,
};
