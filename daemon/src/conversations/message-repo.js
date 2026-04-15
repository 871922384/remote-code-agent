const { randomUUID } = require('node:crypto');

function createMessageRepo(db) {
  const insertMessage = db.prepare(`
    INSERT INTO messages (id, conversation_id, role, text, created_at)
    VALUES (?, ?, ?, ?, ?)
  `);
  const listByConversation = db.prepare(`
    SELECT id, conversation_id, role, text, created_at
    FROM messages
    WHERE conversation_id = ?
    ORDER BY created_at ASC
  `);

  return {
    create({ conversationId, role, text, now }) {
      const id = randomUUID();
      insertMessage.run(id, conversationId, role, text, now);
      return { id, conversationId, role, text, createdAt: now };
    },
    list(conversationId) {
      return listByConversation.all(conversationId).map((row) => ({
        id: row.id,
        conversationId: row.conversation_id,
        role: row.role,
        text: row.text,
        createdAt: row.created_at,
      }));
    },
  };
}

module.exports = {
  createMessageRepo,
};
