const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

function emptyState() {
  return {
    projects: [],
    threads: [],
    messages: [],
  };
}

function normalizeState(parsed) {
  return {
    projects: Array.isArray(parsed?.projects) ? parsed.projects : [],
    threads: Array.isArray(parsed?.threads) ? parsed.threads : [],
    messages: Array.isArray(parsed?.messages) ? parsed.messages : [],
  };
}

function createStateStore({ dataDir, filename = 'agent-state.json' }) {
  const stateFile = path.join(dataDir, filename);

  function ensureStateFile() {
    fs.mkdirSync(dataDir, { recursive: true });
    if (!fs.existsSync(stateFile)) {
      fs.writeFileSync(stateFile, JSON.stringify(emptyState(), null, 2));
    }
  }

  function loadState() {
    ensureStateFile();
    return normalizeState(JSON.parse(fs.readFileSync(stateFile, 'utf8')));
  }

  function saveState(state) {
    ensureStateFile();
    fs.writeFileSync(stateFile, JSON.stringify(state, null, 2));
  }

  function withState(mutator) {
    const state = loadState();
    const result = mutator(state);
    saveState(state);
    return result;
  }

  function listProjects() {
    return loadState().projects
      .slice()
      .sort((left, right) => right.updatedAt.localeCompare(left.updatedAt));
  }

  function createProject({ name, cwd }) {
    return withState((state) => {
      const now = new Date().toISOString();
      const project = {
        id: crypto.randomUUID(),
        name,
        cwd,
        createdAt: now,
        updatedAt: now,
      };

      state.projects.push(project);
      return project;
    });
  }

  function upsertProject({ id, name, cwd, source = 'local' }) {
    return withState((state) => {
      const now = new Date().toISOString();
      const existing = state.projects.find((project) => project.id === id || project.cwd === cwd);
      if (existing) {
        existing.id = id || existing.id;
        existing.name = name || existing.name;
        existing.cwd = cwd || existing.cwd;
        existing.source = source;
        existing.updatedAt = now;
        return existing;
      }

      const project = {
        id: id || crypto.randomUUID(),
        name,
        cwd,
        source,
        createdAt: now,
        updatedAt: now,
      };
      state.projects.push(project);
      return project;
    });
  }

  function getProject(projectId) {
    return loadState().projects.find((project) => project.id === projectId) || null;
  }

  function listThreads({ projectId } = {}) {
    const state = loadState();
    const messagesByThreadId = new Map();

    for (const message of state.messages) {
      const bucket = messagesByThreadId.get(message.threadId) || [];
      bucket.push(message);
      messagesByThreadId.set(message.threadId, bucket);
    }

    return state.threads
      .filter((thread) => !projectId || thread.projectId === projectId)
      .map((thread) => {
        const threadMessages = messagesByThreadId.get(thread.id) || [];
        const lastMessage = threadMessages[threadMessages.length - 1];
        return {
          ...thread,
          messageCount: threadMessages.length,
          lastMessageAt: lastMessage?.createdAt || thread.updatedAt,
        };
      })
      .sort((left, right) => right.updatedAt.localeCompare(left.updatedAt));
  }

  function createThread({ projectId, title, engine }) {
    return withState((state) => {
      const project = state.projects.find((entry) => entry.id === projectId);
      if (!project) {
        const error = new Error('Project not found');
        error.code = 'PROJECT_NOT_FOUND';
        throw error;
      }

      const now = new Date().toISOString();
      const thread = {
        id: crypto.randomUUID(),
        projectId,
        title,
        engine,
        status: 'idle',
        createdAt: now,
        updatedAt: now,
      };

      state.threads.push(thread);
      project.updatedAt = now;
      return thread;
    });
  }

  function getThread(threadId) {
    return loadState().threads.find((thread) => thread.id === threadId) || null;
  }

  function updateThread(threadId, updates) {
    return withState((state) => {
      const thread = state.threads.find((entry) => entry.id === threadId);
      if (!thread) {
        const error = new Error('Thread not found');
        error.code = 'THREAD_NOT_FOUND';
        throw error;
      }

      Object.assign(thread, updates, { updatedAt: new Date().toISOString() });
      return thread;
    });
  }

  function appendMessage({ threadId, role, text, engine }) {
    return withState((state) => {
      const thread = state.threads.find((entry) => entry.id === threadId);
      if (!thread) {
        const error = new Error('Thread not found');
        error.code = 'THREAD_NOT_FOUND';
        throw error;
      }

      const project = state.projects.find((entry) => entry.id === thread.projectId);
      const now = new Date().toISOString();
      const message = {
        id: crypto.randomUUID(),
        threadId,
        role,
        text,
        engine,
        createdAt: now,
      };

      state.messages.push(message);
      thread.updatedAt = now;
      if (project) {
        project.updatedAt = now;
      }
      return message;
    });
  }

  function listMessages(threadId) {
    return loadState().messages
      .filter((message) => message.threadId === threadId)
      .sort((left, right) => left.createdAt.localeCompare(right.createdAt));
  }

  return {
    stateFile,
    listProjects,
    createProject,
    upsertProject,
    getProject,
    listThreads,
    createThread,
    getThread,
    updateThread,
    appendMessage,
    listMessages,
  };
}

module.exports = {
  createStateStore,
};
