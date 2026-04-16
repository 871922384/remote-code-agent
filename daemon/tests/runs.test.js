const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { openDatabase } = require('../src/db/open-db');
const { migrate } = require('../src/db/migrate');
const { createConversationService } = require('../src/conversations/conversation-service');
const { buildCodexCommand } = require('../src/runs/build-codex-command');
const { createRunService } = require('../src/runs/run-service');

test('buildCodexCommand requests JSON output from codex', () => {
  const command = buildCodexCommand({
    codexBin: 'codex',
    prompt: 'hello',
  });

  assert.deepEqual(command, {
    command: 'codex',
    args: ['exec', '--skip-git-repo-check', '--json', 'hello'],
  });
});

test('run service starts immediately and completes asynchronously', async () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'run-service-'));
  const fakeCodex = path.join(tempRoot, 'fake-codex.sh');
  fs.writeFileSync(fakeCodex, [
    '#!/usr/bin/env bash',
    'sleep 0.2',
    'printf \'{"type":"action","name":"reading files"}\\n\'',
    'printf \'{"type":"assistant","text":"已定位到问题文件。"}\\n\'',
    'printf \'{"type":"error","message":"API unavailable"}\\n\'',
  ].join('\n'));
  fs.chmodSync(fakeCodex, 0o755);

  const db = openDatabase({ daemonDataDir: path.join(tempRoot, 'data') });
  migrate(db);
  const publishedEvents = [];

  const conversationService = createConversationService({ db });
  const conversation = conversationService.createConversation({
    projectId: tempRoot,
    title: '排查接口失败',
    openingMessage: '看下为什么超时',
  });

  const runService = createRunService({
    db,
    codexBin: fakeCodex,
    eventBroker: {
      publish(event) {
        publishedEvents.push(event);
      },
    },
  });
  const run = await runService.startRun({
    conversationId: conversation.id,
    cwd: tempRoot,
    prompt: '看下为什么超时',
  });

  assert.equal(run.status, 'running');

  await waitFor(() => {
    const conversations = conversationService.listConversations(tempRoot);
    return conversations[0]?.status === 'completed';
  });

  const events = runService.listRunEvents(run.id);
  const conversationEvents = runService.listConversationEvents(conversation.id);
  const conversations = conversationService.listConversations(tempRoot);

  assert.equal(events[0].kind, 'run.action');
  assert.equal(events[1].kind, 'message.created');
  assert.equal(events[2].kind, 'run.error');
  assert.equal(conversationEvents[0].kind, 'run.action');
  assert.equal(conversationEvents[2].kind, 'run.error');
  assert.equal(conversations[0].status, 'completed');
  assert.equal(publishedEvents[0].kind, 'run.started');
  assert.equal(publishedEvents[0].conversationId, conversation.id);
  assert.equal(publishedEvents[1].conversationId, conversation.id);
});

test('run service marks the conversation failed when codex is unavailable', async () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'run-service-missing-codex-'));
  const db = openDatabase({ daemonDataDir: path.join(tempRoot, 'data') });
  migrate(db);

  const conversationService = createConversationService({ db });
  const conversation = conversationService.createConversation({
    projectId: tempRoot,
    title: 'codex missing',
    openingMessage: 'run',
  });

  const runService = createRunService({
    db,
    codexBin: '/tmp/definitely-missing-codex',
  });

  await assert.rejects(
    () => runService.startRun({
      conversationId: conversation.id,
      cwd: tempRoot,
      prompt: 'run',
    }),
    /codex/i,
  );

  const conversations = conversationService.listConversations(tempRoot);
  assert.equal(conversations[0].status, 'failed');
});

test('run service publishes a timestamped failure event when codex is unavailable', async () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'run-service-missing-codex-event-'));
  const db = openDatabase({ daemonDataDir: path.join(tempRoot, 'data') });
  migrate(db);
  const publishedEvents = [];

  const conversationService = createConversationService({ db });
  const conversation = conversationService.createConversation({
    projectId: tempRoot,
    title: 'codex missing event',
    openingMessage: 'run',
  });

  const runService = createRunService({
    db,
    codexBin: '/tmp/definitely-missing-codex',
    eventBroker: {
      publish(event) {
        publishedEvents.push(event);
      },
    },
  });

  await assert.rejects(
    () => runService.startRun({
      conversationId: conversation.id,
      cwd: tempRoot,
      prompt: 'run',
    }),
    /codex/i,
  );

  assert.equal(publishedEvents[0]?.kind, 'run.failed');
  assert.equal(publishedEvents[0]?.conversationId, conversation.id);
  assert.match(publishedEvents[0]?.createdAt ?? '', /\d{4}-\d{2}-\d{2}T/);
});

async function waitFor(predicate, { timeoutMs = 2000, intervalMs = 20 } = {}) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (predicate()) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  throw new Error('Timed out waiting for predicate to pass.');
}
