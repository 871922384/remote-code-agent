const { listWorkspaceProjects } = require('./workspace-scanner');

function createProjectService({ workspaceRoot, db }) {
  const selectMetadata = db.prepare(`
    SELECT project_id, pinned, last_opened_at, last_active_conversation_id
    FROM project_metadata
    WHERE project_id = ?
  `);

  function listProjects() {
    return listWorkspaceProjects(workspaceRoot)
      .map((project) => {
        const metadata = selectMetadata.get(project.id);
        return {
          ...project,
          pinned: Boolean(metadata?.pinned),
          lastOpenedAt: metadata?.last_opened_at || null,
          lastActiveConversationId: metadata?.last_active_conversation_id || null,
        };
      })
      .sort((left, right) => {
        if (left.pinned !== right.pinned) return left.pinned ? -1 : 1;
        return left.name.localeCompare(right.name);
      });
  }

  return {
    listProjects,
  };
}

module.exports = {
  createProjectService,
};
