const { createConversationRepo } = require('./conversation-repo');
const { createMessageRepo } = require('./message-repo');

function createConversationService({ db }) {
  const conversationRepo = createConversationRepo(db);
  const messageRepo = createMessageRepo(db);
  const selectLastMessage = db.prepare(`
    SELECT text
    FROM messages
    WHERE conversation_id = ?
    ORDER BY created_at DESC
    LIMIT 1
  `);
  const selectActiveRun = db.prepare(`
    SELECT id, requires_confirmation
    FROM runs
    WHERE conversation_id = ? AND ended_at IS NULL
    ORDER BY started_at DESC
    LIMIT 1
  `);

  return {
    createConversation({ projectId, title, openingMessage }) {
      const now = new Date().toISOString();
      const conversation = conversationRepo.create({ projectId, title, now });
      if (openingMessage && openingMessage.trim()) {
        messageRepo.create({
          conversationId: conversation.id,
          role: 'user',
          text: openingMessage.trim(),
          now,
        });
      }
      return conversation;
    },
    listConversations(projectId) {
      return conversationRepo.list(projectId).map((conversation) => {
        const lastMessage = selectLastMessage.get(conversation.id);
        const activeRun = selectActiveRun.get(conversation.id);
        return {
          ...conversation,
          lastMessagePreview: lastMessage?.text || 'No messages yet.',
          activeRunId: activeRun?.id || null,
          requiresConfirmation: Boolean(activeRun?.requires_confirmation),
        };
      });
    },
    appendUserMessage({ conversationId, text }) {
      const now = new Date().toISOString();
      const message = messageRepo.create({
        conversationId,
        role: 'user',
        text: text.trim(),
        now,
      });
      conversationRepo.touch({ conversationId, now });
      return message;
    },
    listMessages(conversationId) {
      return messageRepo.list(conversationId);
    },
  };
}

module.exports = {
  createConversationService,
};
