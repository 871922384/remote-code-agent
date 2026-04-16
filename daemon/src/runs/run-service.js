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

    const launchedProcess = launchCodexProcess({
      command: codexBin,
      prompt,
      cwd,
    });
    const { child, spawnPromise } = launchedProcess;
    try {
      await spawnPromise;
    } catch (error) {
      await launchedProcess.closePromise.catch(() => {});
      const endedAt = new Date().toISOString();
      if (eventBroker) {
        eventBroker.publish({
          kind: 'run.failed',
          runId,
          conversationId,
          createdAt: endedAt,
          payload: { message: error.message },
        });
      }
      updateRun.run('failed', endedAt, runId);
      updateConversationStatus.run('failed', endedAt, conversationId);
      throw error;
    }

    activeRuns.set(runId, child);
    if (eventBroker) {
      eventBroker.publish({
        kind: 'run.started',
        runId,
        conversationId,
        createdAt: startedAt,
      });
    }

    void processRun({
      child,
      stdout: launchedProcess.stdout,
      stderr: launchedProcess.stderr,
      closePromise: launchedProcess.closePromise,
      conversationId,
      runId,
    });
    return { id: runId, conversationId, status: 'running', startedAt, endedAt: null };
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

  async function processRun({ child, stdout, stderr, closePromise, conversationId, runId }) {
    try {
      const stderrTask = (async () => {
        for await (const line of stderr) {
          const createdAt = new Date().toISOString();
          insertEvent.run(
            randomUUID(),
            runId,
            'run.error',
            JSON.stringify({ message: line }),
            createdAt,
          );
          if (eventBroker) {
            eventBroker.publish({
              kind: 'run.error',
              runId,
              conversationId,
              createdAt,
              payload: { message: line },
            });
          }
        }
      })();

      for await (const line of stdout) {
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

      await stderrTask;
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
    } catch (error) {
      if (!child.killed) {
        child.kill('SIGTERM');
      }
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
    } finally {
      activeRuns.delete(runId);
    }
  }
}

function launchCodexProcess({ command, prompt, cwd }) {
  const { args } = buildCodexCommand({ codexBin: command, prompt });
  const child = spawn(command, args, { cwd, stdio: ['pipe', 'pipe', 'pipe'] });
  const spawnPromise = waitForSpawn(child, command);
  const stdout = readline.createInterface({ input: child.stdout });
  const stderr = readline.createInterface({ input: child.stderr });
  const closePromise = waitForExit(child);
  child.stdin.end();
  return { child, spawnPromise, stdout, stderr, closePromise };
}

function waitForSpawn(child, command) {
  return new Promise((resolve, reject) => {
    child.once('spawn', resolve);
    child.once('error', (error) => {
      if (error?.code === 'ENOENT') {
        reject(
          new Error(
            `Codex executable was not found: ${command}. Set CODEX_BIN to an absolute codex path.`
          )
        );
        return;
      }
      reject(error);
    });
  });
}

function waitForExit(child) {
  return new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('close', (code) => {
      if (code === 0 || code === null) {
        resolve();
        return;
      }
      reject(new Error(`Codex exited with code ${code}`));
    });
  });
}

module.exports = {
  createRunService,
};
