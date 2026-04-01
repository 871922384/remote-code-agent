const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { DatabaseSync } = require('node:sqlite');

function normalizeCwd(value) {
  if (!value) return '';
  return String(value)
    .replace(/^\\\\\?\\/, '')
    .replace(/[\\/]+$/, '');
}

function toProjectName(cwd) {
  const normalized = normalizeCwd(cwd);
  return path.basename(normalized) || normalized;
}

function toIsoFromUnixSeconds(value) {
  const numeric = Number(value || 0);
  return new Date(numeric * 1000).toISOString();
}

function createCodexSyncStore({ codexHomeDir } = {}) {
  const resolvedCodexHomeDir = codexHomeDir || process.env.CODEX_HOME || path.join(os.homedir(), '.codex');
  const globalStatePath = path.join(resolvedCodexHomeDir, '.codex-global-state.json');
  const stateDbPath = path.join(resolvedCodexHomeDir, 'state_5.sqlite');

  function safeReadJson(filePath) {
    try {
      return JSON.parse(fs.readFileSync(filePath, 'utf8'));
    } catch {
      return null;
    }
  }

  function safeOpenDb() {
    if (!fs.existsSync(stateDbPath)) {
      return null;
    }

    try {
      return new DatabaseSync(stateDbPath, { readonly: true });
    } catch {
      return null;
    }
  }

  function readGlobalState() {
    return safeReadJson(globalStatePath) || {};
  }

  function readThreadRows() {
    const db = safeOpenDb();
    if (!db) return [];

    try {
      return db.prepare(`
        SELECT id, rollout_path, cwd, title, updated_at, created_at, model, archived
        FROM threads
        WHERE archived = 0
        ORDER BY updated_at DESC
      `).all();
    } catch {
      return [];
    } finally {
      db.close();
    }
  }

  function findThreadRow(threadId) {
    const db = safeOpenDb();
    if (!db) return null;

    try {
      return db.prepare(`
        SELECT id, rollout_path, cwd, title, updated_at, created_at, model, archived
        FROM threads
        WHERE id = ?
      `).get(threadId) || null;
    } catch {
      return null;
    } finally {
      db.close();
    }
  }

  function countRolloutMessages(rolloutPath) {
    const messages = parseRolloutMessages(rolloutPath);
    return messages.length;
  }

  function parseRolloutMessages(rolloutPath) {
    if (!rolloutPath || !fs.existsSync(rolloutPath)) {
      return [];
    }

    const lines = fs.readFileSync(rolloutPath, 'utf8').split(/\r?\n/).filter(Boolean);
    const messages = [];

    for (const line of lines) {
      try {
        const record = JSON.parse(line);
        const payload = record.payload || {};

        if (record.type === 'event_msg' && payload.type === 'user_message' && payload.message) {
          messages.push({
            id: `${payload.turn_id || record.timestamp || messages.length}:user`,
            role: 'user',
            text: payload.message,
            engine: 'codex',
            createdAt: record.timestamp || new Date().toISOString(),
            source: 'codex',
          });
        }

        if (record.type === 'event_msg' && payload.type === 'agent_message' && payload.message) {
          messages.push({
            id: `${payload.turn_id || record.timestamp || messages.length}:assistant`,
            role: 'assistant',
            text: payload.message,
            engine: 'codex',
            createdAt: record.timestamp || new Date().toISOString(),
            source: 'codex',
          });
        }
      } catch {
        // Ignore malformed rollout lines and keep best-effort history.
      }
    }

    return messages;
  }

  function listProjects() {
    const globalState = readGlobalState();
    const orderedRoots = [
      ...(Array.isArray(globalState['project-order']) ? globalState['project-order'] : []),
      ...(Array.isArray(globalState['electron-saved-workspace-roots']) ? globalState['electron-saved-workspace-roots'] : []),
      ...readThreadRows().map((row) => row.cwd),
    ];

    const activeRoots = new Set(
      (Array.isArray(globalState['active-workspace-roots']) ? globalState['active-workspace-roots'] : [])
        .map(normalizeCwd)
    );

    const seen = new Set();
    const projects = [];

    for (const root of orderedRoots) {
      const cwd = normalizeCwd(root);
      if (!cwd || seen.has(cwd)) continue;
      seen.add(cwd);
      projects.push({
        id: cwd,
        name: toProjectName(cwd),
        cwd,
        source: 'codex',
        isActive: activeRoots.has(cwd),
      });
    }

    return projects;
  }

  function getProject(projectId) {
    const normalizedProjectId = normalizeCwd(projectId);
    return listProjects().find((project) => normalizeCwd(project.id) === normalizedProjectId) || null;
  }

  function listThreads({ projectId } = {}) {
    const normalizedProjectId = normalizeCwd(projectId);
    return readThreadRows()
      .filter((row) => !normalizedProjectId || normalizeCwd(row.cwd) === normalizedProjectId)
      .map((row) => ({
        id: row.id,
        projectId: normalizeCwd(row.cwd),
        title: row.title,
        engine: 'codex',
        status: 'idle',
        createdAt: toIsoFromUnixSeconds(row.created_at),
        updatedAt: toIsoFromUnixSeconds(row.updated_at),
        source: 'codex',
        readOnly: true,
        messageCount: countRolloutMessages(row.rollout_path),
      }));
  }

  function hasThread(threadId) {
    return Boolean(findThreadRow(threadId));
  }

  function listMessages(threadId) {
    const row = findThreadRow(threadId);
    if (!row) return [];
    return parseRolloutMessages(row.rollout_path);
  }

  function hasProjects() {
    return listProjects().length > 0;
  }

  return {
    codexHomeDir: resolvedCodexHomeDir,
    globalStatePath,
    stateDbPath,
    normalizeCwd,
    hasProjects,
    listProjects,
    getProject,
    listThreads,
    hasThread,
    listMessages,
  };
}

module.exports = {
  createCodexSyncStore,
  normalizeCwd,
};
