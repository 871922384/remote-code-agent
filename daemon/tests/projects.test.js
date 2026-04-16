const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { openDatabase } = require('../src/db/open-db');
const { migrate } = require('../src/db/migrate');
const { createProjectService } = require('../src/projects/project-service');

test('project service lists first-level folders from the workspace root and merges metadata', () => {
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-workspace-'));
  const workspaceRoot = path.join(tempRoot, 'code');
  const dataDir = path.join(tempRoot, 'data');
  fs.mkdirSync(workspaceRoot, { recursive: true });
  fs.mkdirSync(path.join(workspaceRoot, 'alpha-api'));
  fs.mkdirSync(path.join(workspaceRoot, 'beta-admin'));

  const db = openDatabase({ daemonDataDir: dataDir });
  migrate(db);
  const betaProjectId = path.join(workspaceRoot, 'beta-admin');
  db.prepare(`
    INSERT INTO project_metadata (project_id, pinned, last_opened_at, last_active_conversation_id)
    VALUES (?, 1, '2026-04-15T10:00:00.000Z', 'conv-9')
  `).run(betaProjectId);
  db.prepare(`
    INSERT INTO conversations (id, project_id, title, status, archived, created_at, updated_at)
    VALUES ('conv-9', ?, 'Fix billing callback', 'running', 0, '2026-04-15T10:00:00.000Z', '2026-04-15T10:05:00.000Z')
  `).run(betaProjectId);
  db.prepare(`
    INSERT INTO messages (id, conversation_id, role, text, created_at)
    VALUES ('msg-9', 'conv-9', 'assistant', 'Reading billing_controller.dart', '2026-04-15T10:05:00.000Z')
  `).run();

  const service = createProjectService({ workspaceRoot, db });
  const projects = service.listProjects();

  assert.deepEqual(
    projects.map((project) => ({
      name: project.name,
      path: project.path,
      pinned: project.pinned,
      lastActiveConversationId: project.lastActiveConversationId,
      runningConversationCount: project.runningConversationCount,
      lastSummary: project.lastSummary,
    })),
    [
      {
        name: 'beta-admin',
        path: path.join(workspaceRoot, 'beta-admin'),
        pinned: true,
        lastActiveConversationId: 'conv-9',
        runningConversationCount: 1,
        lastSummary: 'Reading billing_controller.dart',
      },
      {
        name: 'alpha-api',
        path: path.join(workspaceRoot, 'alpha-api'),
        pinned: false,
        lastActiveConversationId: null,
        runningConversationCount: 0,
        lastSummary: 'No active conversations right now.',
      },
    ],
  );
});
