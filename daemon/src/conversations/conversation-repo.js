const { randomUUID } = require('node:crypto');

function createConversationRepo(db) {
  const insertConversation = db.prepare(`
    INSERT INTO conversations (id, project_id, title, status, archived, created_at, updated_at)
    VALUES (?, ?, ?, ?, 0, ?, ?)
  `);
  const listByProject = db.prepare(`
    SELECT id, project_id, title, status, created_at, updated_at
    FROM conversations
    WHERE project_id = ? AND archived = 0
    ORDER BY updated_at DESC
  `);

  return {
    create({ projectId, title, now }) {
      const id = randomUUID();
      insertConversation.run(id, projectId, title, 'idle', now, now);
      return {
        id,
        projectId,
        title,
        status: 'idle',
        createdAt: now,
        updatedAt: now,
      };
    },
    list(projectId) {
      return listByProject.all(projectId).map((row) => ({
        id: row.id,
        projectId: row.project_id,
        title: row.title,
        status: row.status,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
      }));
    },
  };
}

module.exports = {
  createConversationRepo,
};
