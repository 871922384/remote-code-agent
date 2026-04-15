const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { openDatabase } = require('../src/db/open-db');
const { migrate } = require('../src/db/migrate');
const { createConversationService } = require('../src/conversations/conversation-service');
const { createRunService } = require('../src/runs/run-service');

test('run service persists action events, assistant output, and completion state', async () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'run-service-'));
  const fakeCodex = path.join(tempRoot, 'fake-codex.sh');
  fs.writeFileSync(fakeCodex, [
    '#!/usr/bin/env bash',
    'printf \'{"type":"action","name":"reading files"}\\n\'',
    'printf \'{"type":"assistant","text":"已定位到问题文件。"}\\n\'',
    'printf \'{"type":"error","message":"API unavailable"}\\n\'',
  ].join('\n'));
  fs.chmodSync(fakeCodex, 0o755);

  const db = openDatabase({ daemonDataDir: path.join(tempRoot, 'data') });
  migrate(db);

  const conversationService = createConversationService({ db });
  const conversation = conversationService.createConversation({
    projectId: tempRoot,
    title: '排查接口失败',
    openingMessage: '看下为什么超时',
  });

  const runService = createRunService({ db, codexBin: fakeCodex });
  const run = await runService.startRun({
    conversationId: conversation.id,
    cwd: tempRoot,
    prompt: '看下为什么超时',
  });

  assert.equal(run.status, 'completed');
  const events = runService.listRunEvents(run.id);
  assert.equal(events[0].kind, 'run.action');
  assert.equal(events[1].kind, 'message.created');
  assert.equal(events[2].kind, 'run.error');
});
