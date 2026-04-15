const test = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { openDatabase } = require('../src/db/open-db');
const { migrate } = require('../src/db/migrate');
const { createConversationService } = require('../src/conversations/conversation-service');

test('conversation service creates a conversation and appends a user message', () => {
  const db = openDatabase({ daemonDataDir: `/tmp/${randomUUID()}` });
  migrate(db);

  const service = createConversationService({ db });
  const conversation = service.createConversation({
    projectId: '/Users/rex/code/alpha-api',
    title: '修复支付回调',
    openingMessage: '先看为什么重复入库',
  });

  const conversations = service.listConversations('/Users/rex/code/alpha-api');
  const messages = service.listMessages(conversation.id);

  assert.equal(conversations.length, 1);
  assert.equal(conversations[0].status, 'idle');
  assert.equal(messages.length, 1);
  assert.equal(messages[0].role, 'user');
  assert.equal(messages[0].text, '先看为什么重复入库');
});
