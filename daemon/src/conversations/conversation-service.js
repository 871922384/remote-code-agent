const { createConversationRepo } = require('./conversation-repo');
const { createMessageRepo } = require('./message-repo');

function createConversationService({ db }) {
  const conversationRepo = createConversationRepo(db);
  const messageRepo = createMessageRepo(db);

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
      return conversationRepo.list(projectId);
    },
    appendUserMessage({ conversationId, text }) {
      return messageRepo.create({
        conversationId,
        role: 'user',
        text: text.trim(),
        now: new Date().toISOString(),
      });
    },
    listMessages(conversationId) {
      return messageRepo.list(conversationId);
    },
  };
}

module.exports = {
  createConversationService,
};
