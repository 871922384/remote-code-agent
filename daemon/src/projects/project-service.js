const { listWorkspaceProjects } = require('./workspace-scanner');

function createProjectService({ workspaceRoot, db }) {
  const selectMetadata = db.prepare(`
    SELECT project_id, pinned, last_opened_at, last_active_conversation_id
    FROM project_metadata
    WHERE project_id = ?
  `);
  const countRunningConversations = db.prepare(`
    SELECT COUNT(*) AS count
    FROM conversations
    WHERE project_id = ? AND archived = 0 AND status = 'running'
  `);
  const selectLastSummary = db.prepare(`
    SELECT messages.text
    FROM conversations
    JOIN messages ON messages.id = (
      SELECT id
      FROM messages
      WHERE conversation_id = conversations.id
      ORDER BY created_at DESC
      LIMIT 1
    )
    WHERE conversations.project_id = ? AND conversations.archived = 0
    ORDER BY conversations.updated_at DESC
    LIMIT 1
  `);

  function listProjects() {
    return listWorkspaceProjects(workspaceRoot)
      .map((project) => {
        const metadata = selectMetadata.get(project.id);
        const runningConversationCount =
          countRunningConversations.get(project.id)?.count || 0;
        const lastSummary =
          selectLastSummary.get(project.id)?.text ||
          'No active conversations right now.';
        return {
          ...project,
          pinned: Boolean(metadata?.pinned),
          lastOpenedAt: metadata?.last_opened_at || null,
          lastActiveConversationId: metadata?.last_active_conversation_id || null,
          runningConversationCount,
          lastSummary,
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
