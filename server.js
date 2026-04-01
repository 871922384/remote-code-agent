/**
 * Remote Code Agent - Windows side
 * Wraps Claude Code CLI & OpenAI Codex CLI, exposes streaming HTTP API
 * Run: node server.js
 */

const express = require('express');
const { spawn } = require('child_process');
const fs = require('node:fs');
const path = require('path');
const crypto = require('crypto');
const { createCodexSyncStore, normalizeCwd } = require('./lib/codex-sync-store');
const { createStateStore } = require('./lib/state-store');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3333;
const HOST = '127.0.0.1';
const AUTH_TOKEN = process.env.AUTH_TOKEN;
const DEFAULT_CWD = process.env.DEFAULT_CWD || 'C:\\';
const AGENT_DATA_DIR = process.env.AGENT_DATA_DIR || path.join(__dirname, 'data');
const DIST_DIR = path.join(__dirname, 'dist');
const PUBLIC_DIR = path.join(__dirname, 'public');
const IS_WINDOWS = process.platform === 'win32';
const CODEX_BIN = process.env.CODEX_BIN || (IS_WINDOWS ? 'codex.cmd' : 'codex');
const CLAUDE_BIN = process.env.CLAUDE_BIN || 'claude';
const stateStore = createStateStore({ dataDir: AGENT_DATA_DIR });
const codexSyncStore = createCodexSyncStore();
const HAS_DIST = fs.existsSync(path.join(DIST_DIR, 'index.html'));

function listProjectsForResponse() {
  const codexProjects = codexSyncStore.listProjects();
  const localProjects = stateStore.listProjects();

  if (codexProjects.length === 0) {
    return localProjects;
  }

  const seen = new Set(codexProjects.map((project) => normalizeCwd(project.cwd || project.id)));
  const merged = codexProjects.slice();

  for (const project of localProjects) {
    const key = normalizeCwd(project.cwd || project.id);
    if (seen.has(key)) continue;
    seen.add(key);
    merged.push(project);
  }

  return merged;
}

function listThreadsForResponse({ projectId } = {}) {
  const codexThreads = codexSyncStore.listThreads({ projectId });
  const localThreads = stateStore.listThreads({ projectId });

  if (codexThreads.length === 0) {
    return localThreads;
  }

  const seen = new Set(codexThreads.map((thread) => thread.id));
  const merged = codexThreads.slice();

  for (const thread of localThreads) {
    if (seen.has(thread.id)) continue;
    seen.add(thread.id);
    merged.push(thread);
  }

  return merged.sort((left, right) => right.updatedAt.localeCompare(left.updatedAt));
}

function getSpawnCommand(bin, args) {
  if (IS_WINDOWS && /\.cmd$/i.test(bin)) {
    return {
      cmd: process.env.ComSpec || 'cmd.exe',
      args: ['/d', '/s', '/c', bin, ...args],
    };
  }

  if (IS_WINDOWS && /\.ps1$/i.test(bin)) {
    return {
      cmd: `${process.env.SystemRoot || 'C:\\Windows'}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe`,
      args: ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', bin, ...args],
    };
  }

  return { cmd: bin, args };
}

function buildClaudeLaunchEnv(baseEnv) {
  const env = { ...baseEnv };

  if (process.env.CLAUDE_ANTHROPIC_BASE_URL) {
    env.ANTHROPIC_BASE_URL = process.env.CLAUDE_ANTHROPIC_BASE_URL;
  }

  if (process.env.CLAUDE_ANTHROPIC_AUTH_TOKEN) {
    env.ANTHROPIC_AUTH_TOKEN = process.env.CLAUDE_ANTHROPIC_AUTH_TOKEN;
  }

  if (process.env.CLAUDE_ANTHROPIC_API_KEY) {
    env.ANTHROPIC_API_KEY = process.env.CLAUDE_ANTHROPIC_API_KEY;
  }

  return env;
}

if (!AUTH_TOKEN) {
  console.error('[ERROR] AUTH_TOKEN not set in .env — refusing to start.');
  process.exit(1);
}

app.use(express.json({ limit: '2mb' }));
app.get('/legacy', (req, res) => {
  res.sendFile(path.join(PUBLIC_DIR, 'index.html'));
});

app.use(express.static(HAS_DIST ? DIST_DIR : PUBLIC_DIR));

// ── Auth middleware ──────────────────────────────────────────────────────────
app.use('/api', (req, res, next) => {
  const token = req.headers['x-auth-token'];
  if (!token || token !== AUTH_TOKEN) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
});

// ── Health check ─────────────────────────────────────────────────────────────
app.get('/api/ping', (req, res) => {
  res.json({ ok: true, time: new Date().toISOString() });
});

app.get('/api/projects', (req, res) => {
  res.json({ projects: listProjectsForResponse() });
});

app.post('/api/projects', (req, res) => {
  const { name, cwd } = req.body;

  if (!name || !name.trim()) {
    return res.status(400).json({ error: 'name is required' });
  }

  const project = stateStore.createProject({
    name: name.trim(),
    cwd: cwd && cwd.trim() ? cwd.trim() : DEFAULT_CWD,
  });

  res.status(201).json({ project });
});

app.get('/api/threads', (req, res) => {
  const projectId = typeof req.query.projectId === 'string' ? req.query.projectId : undefined;
  res.json({ threads: listThreadsForResponse({ projectId }) });
});

app.post('/api/threads', (req, res) => {
  const { projectId, title, engine = 'codex' } = req.body;

  if (!projectId || !projectId.trim()) {
    return res.status(400).json({ error: 'projectId is required' });
  }

  if (!title || !title.trim()) {
    return res.status(400).json({ error: 'title is required' });
  }

  try {
    if (!stateStore.getProject(projectId.trim())) {
      const mirroredProject = codexSyncStore.getProject(projectId.trim());
      if (mirroredProject) {
        stateStore.upsertProject({
          id: mirroredProject.id,
          name: mirroredProject.name,
          cwd: mirroredProject.cwd,
          source: 'shadow',
        });
      }
    }

    const thread = stateStore.createThread({
      projectId: projectId.trim(),
      title: title.trim(),
      engine,
    });
    res.status(201).json({ thread });
  } catch (error) {
    if (error.code === 'PROJECT_NOT_FOUND') {
      return res.status(404).json({ error: error.message });
    }
    throw error;
  }
});

app.get('/api/threads/:id/messages', (req, res) => {
  if (codexSyncStore.hasThread(req.params.id)) {
    return res.json({ messages: codexSyncStore.listMessages(req.params.id) });
  }

  const thread = stateStore.getThread(req.params.id);
  if (!thread) {
    return res.status(404).json({ error: 'Thread not found' });
  }

  res.json({ messages: stateStore.listMessages(req.params.id) });
});

// ── Active sessions (for kill support) ───────────────────────────────────────
const sessions = new Map();

// ── Main streaming chat endpoint ─────────────────────────────────────────────
// Client sends: { engine: "claude"|"codex", prompt: "...", cwd: "..." }
// Server responds: SSE stream of { type, text } objects
app.post('/api/chat', (req, res) => {
  const { engine = 'claude', prompt, cwd, threadId } = req.body;

  if (!prompt || !prompt.trim()) {
    return res.status(400).json({ error: 'prompt is required' });
  }

  if (threadId && codexSyncStore.hasThread(threadId) && !stateStore.getThread(threadId)) {
    return res.status(409).json({ error: 'Mirrored Codex threads are read-only. Create a new thread to continue chatting.' });
  }

  if (threadId && !stateStore.getThread(threadId)) {
    return res.status(404).json({ error: 'Thread not found' });
  }

  // Set up SSE
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no'); // Disable Nginx buffering
  res.flushHeaders();

  const workDir = cwd && cwd.trim() ? cwd.trim() : DEFAULT_CWD;
  const sessionId = crypto.randomUUID();
  const assistantChunks = [];
  let assistantSaved = false;

  if (threadId) {
    stateStore.appendMessage({
      threadId,
      role: 'user',
      text: prompt.trim(),
      engine,
    });
    stateStore.updateThread(threadId, { status: 'running', engine });
  }

  const persistableTypes = new Set([
    'text',
    'raw',
    'tool',
    'tool_result',
    'result',
    'system',
    'stderr',
    'error',
  ]);

  const send = (type, text) => {
    if (threadId && persistableTypes.has(type) && text) {
      assistantChunks.push(text);
    }
    res.write(`data: ${JSON.stringify({ type, text, sessionId })}\n\n`);
  };

  const persistAssistantMessage = (fallbackText, status) => {
    if (!threadId || assistantSaved) {
      return;
    }

    assistantSaved = true;
    const finalText = assistantChunks.join('').trim() || fallbackText || '';
    if (finalText) {
      stateStore.appendMessage({
        threadId,
        role: 'assistant',
        text: finalText,
        engine,
      });
    }
    stateStore.updateThread(threadId, { status });
  };

  send('meta', `engine=${engine}  cwd=${workDir}`);

  // ── Spawn the correct CLI ─────────────────────────────────────────────────
  let cmd, args;

  if (engine === 'claude') {
    // Claude Code non-interactive mode with streaming JSON output
    cmd = CLAUDE_BIN;
    args = [
      '-p', prompt,
      '--output-format', 'stream-json',
      '--verbose',
      '--dangerously-skip-permissions',
    ];
  } else {
    // OpenAI Codex CLI — full-auto non-interactive mode
    cmd = CODEX_BIN;
    args = [
      '-a', 'never',
      '-s', 'danger-full-access',
      'exec',
      '--skip-git-repo-check',
      prompt,
    ];
  }

  let child;
  try {
    const launcher = getSpawnCommand(cmd, args);
    const childEnv = engine === 'claude'
      ? buildClaudeLaunchEnv(process.env)
      : { ...process.env };
    child = spawn(launcher.cmd, launcher.args, {
      cwd: workDir,
      shell: false,
      env: childEnv,
    });
  } catch (err) {
    send('error', `Failed to spawn ${cmd}: ${err.message}`);
    persistAssistantMessage(`Failed to spawn ${cmd}: ${err.message}`, 'error');
    res.end();
    return;
  }

  sessions.set(sessionId, child);
  send('start', `[${engine}] Session ${sessionId} started`);

  // ── Handle stdout ─────────────────────────────────────────────────────────
  if (engine === 'claude') {
    // Claude outputs newline-delimited JSON; parse and extract text
    let buffer = '';
    child.stdout.on('data', (chunk) => {
      buffer += chunk.toString();
      const lines = buffer.split('\n');
      buffer = lines.pop(); // keep incomplete last line

      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const obj = JSON.parse(line);
          // Extract assistant text content
          if (obj.type === 'assistant' && obj.message?.content) {
            for (const block of obj.message.content) {
              if (block.type === 'text') {
                send('text', block.text);
              } else if (block.type === 'tool_use') {
                send('tool', `[tool: ${block.name}]\n${JSON.stringify(block.input, null, 2)}`);
              }
            }
          } else if (obj.type === 'tool_result') {
            const content = Array.isArray(obj.content)
              ? obj.content.map(c => c.text || '').join('')
              : String(obj.content || '');
            if (content) send('tool_result', content);
          } else if (obj.type === 'result') {
            send('result', obj.result || '');
          } else if (obj.type === 'system') {
            send('system', JSON.stringify(obj));
          }
        } catch {
          // Non-JSON line — pass through raw
          send('raw', line);
        }
      }
    });
  } else {
    // Codex: plain stdout passthrough
    child.stdout.on('data', (chunk) => {
      send('text', chunk.toString());
    });
  }

  child.stderr.on('data', (chunk) => {
    send('stderr', chunk.toString());
  });

  child.on('error', (err) => {
    send('error', err.message);
    if (threadId) {
      stateStore.updateThread(threadId, { status: 'error' });
    }
  });

  child.on('close', (code) => {
    sessions.delete(sessionId);
    persistAssistantMessage(`exit code ${code}`, code === 0 ? 'idle' : 'error');
    send('done', `exit code ${code}`);
    res.end();
  });

  // Kill child if client disconnects
  req.on('aborted', () => {
    if (child && !child.killed) {
      child.kill('SIGTERM');
      sessions.delete(sessionId);
      persistAssistantMessage('', 'stopped');
    }
  });
});

// ── Kill a session ────────────────────────────────────────────────────────────
app.post('/api/kill/:id', (req, res) => {
  const child = sessions.get(req.params.id);
  if (child) {
    child.kill('SIGTERM');
    sessions.delete(req.params.id);
    res.json({ ok: true });
  } else {
    res.status(404).json({ error: 'Session not found' });
  }
});

if (HAS_DIST) {
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api/')) {
      next();
      return;
    }

    res.sendFile(path.join(DIST_DIR, 'index.html'));
  });
}

// ── Start ─────────────────────────────────────────────────────────────────────
const server = app.listen(PORT, HOST, () => {
  console.log(`[Agent] Listening on http://${HOST}:${PORT}`);
  console.log(`[Agent] Default CWD: ${DEFAULT_CWD}`);
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`[ERROR] Startup failed: port ${PORT} is already in use on ${HOST}.`);
  } else {
    console.error(`[ERROR] Startup failed: ${err.message}`);
  }
  process.exit(1);
});
