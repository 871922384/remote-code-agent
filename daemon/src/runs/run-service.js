const { spawn } = require('node:child_process');
const { randomUUID } = require('node:crypto');
const readline = require('node:readline');
const { buildCodexCommand } = require('./build-codex-command');
const { parseCodexLine } = require('./codex-line-parser');

function createRunService({ db, codexBin, eventBroker = null }) {
  const activeRuns = new Map();
  const insertRun = db.prepare(`
    INSERT INTO runs (id, conversation_id, status, requires_confirmation, started_at, ended_at)
    VALUES (?, ?, ?, 0, ?, NULL)
  `);
  const updateRun = db.prepare(`UPDATE runs SET status = ?, ended_at = ? WHERE id = ?`);
  const updateConversationStatus = db.prepare(`
    UPDATE conversations
    SET status = ?, updated_at = ?
    WHERE id = ?
  `);
  const insertMessage = db.prepare(`
    INSERT INTO messages (id, conversation_id, role, text, created_at)
    VALUES (?, ?, ?, ?, ?)
  `);
  const insertEvent = db.prepare(`
    INSERT INTO run_events (id, run_id, kind, payload_json, created_at)
    VALUES (?, ?, ?, ?, ?)
  `);
  const selectEvents = db.prepare(`
    SELECT kind, payload_json, created_at
    FROM run_events
    WHERE run_id = ?
    ORDER BY created_at ASC
  `);
  const selectConversationEvents = db.prepare(`
    SELECT run_events.kind, run_events.payload_json, run_events.created_at
    FROM run_events
    JOIN runs ON runs.id = run_events.run_id
    WHERE runs.conversation_id = ?
    ORDER BY run_events.created_at ASC
  `);

  async function startRun({ conversationId, cwd, prompt }) {
    const runId = randomUUID();
    const startedAt = new Date().toISOString();
    insertRun.run(runId, conversationId, 'running', startedAt);
    updateConversationStatus.run('running', startedAt, conversationId);

    const { command, args } = buildCodexCommand({ codexBin, prompt });
    const child = spawn(command, args, { cwd, stdio: ['pipe', 'pipe', 'pipe'] });
    activeRuns.set(runId, child);
    const stream = readline.createInterface({ input: child.stdout });

    if (eventBroker) {
      eventBroker.publish({
        kind: 'run.started',
        runId,
        conversationId,
        createdAt: startedAt,
      });
    }

    const closePromise = new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('close', (code) => {
        if (code === 0) {
          resolve();
          return;
        }
        reject(new Error(`Codex exited with code ${code}`));
      });
    });

    try {
      for await (const line of stream) {
        const event = parseCodexLine(line);
        const createdAt = new Date().toISOString();
        insertEvent.run(randomUUID(), runId, event.kind, JSON.stringify(event.payload), createdAt);
        if (event.kind === 'message.created') {
          insertMessage.run(randomUUID(), conversationId, event.payload.role, event.payload.text, createdAt);
        }
        if (eventBroker) {
          eventBroker.publish({ runId, conversationId, ...event, createdAt });
        }
      }

      await closePromise;
      const endedAt = new Date().toISOString();
      updateRun.run('completed', endedAt, runId);
      updateConversationStatus.run('completed', endedAt, conversationId);
      if (eventBroker) {
        eventBroker.publish({
          kind: 'run.completed',
          runId,
          conversationId,
          createdAt: endedAt,
        });
      }
      return { id: runId, conversationId, status: 'completed', startedAt, endedAt };
    } catch (error) {
      const endedAt = new Date().toISOString();
      updateRun.run('failed', endedAt, runId);
      updateConversationStatus.run('failed', endedAt, conversationId);
      if (eventBroker) {
        eventBroker.publish({
          kind: 'run.failed',
          runId,
          conversationId,
          createdAt: endedAt,
          payload: { message: error.message },
        });
      }
      throw error;
    } finally {
      activeRuns.delete(runId);
    }
  }

  function listRunEvents(runId) {
    return selectEvents.all(runId).map((row) => ({
      kind: row.kind,
      payload: JSON.parse(row.payload_json),
      createdAt: row.created_at,
    }));
  }

  function listConversationEvents(conversationId) {
    return selectConversationEvents.all(conversationId).map((row) => ({
      kind: row.kind,
      payload: JSON.parse(row.payload_json),
      createdAt: row.created_at,
    }));
  }

  function interruptRun(runId) {
    const child = activeRuns.get(runId);
    if (!child) return false;
    child.kill('SIGINT');
    activeRuns.delete(runId);
    const conversationRow = db
      .prepare(`SELECT conversation_id FROM runs WHERE id = ?`)
      .get(runId);
    const endedAt = new Date().toISOString();
    updateRun.run('interrupted', endedAt, runId);
    if (conversationRow?.conversation_id) {
      updateConversationStatus.run(
        'interrupted',
        endedAt,
        conversationRow.conversation_id,
      );
    }
    if (eventBroker) {
      eventBroker.publish({
        kind: 'run.interrupted',
        runId,
        conversationId: conversationRow?.conversation_id || null,
        createdAt: endedAt,
      });
    }
    return true;
  }

  async function confirmRun(runId) {
    const child = activeRuns.get(runId);
    if (!child) return { ok: false };
    child.stdin.write('y\n');
    if (eventBroker) {
      const conversationRow = db
        .prepare(`SELECT conversation_id FROM runs WHERE id = ?`)
        .get(runId);
      eventBroker.publish({
        kind: 'run.waiting_confirmation',
        runId,
        conversationId: conversationRow?.conversation_id || null,
        createdAt: new Date().toISOString(),
      });
    }
    return { ok: true };
  }

  return {
    startRun,
    listRunEvents,
    listConversationEvents,
    interruptRun,
    confirmRun,
  };
}

module.exports = {
  createRunService,
};
