# Claude Anthropic-Compatible Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the web service keep launching `Claude Code CLI` while injecting Anthropic-compatible provider settings only into that Claude child process.

**Architecture:** Keep the existing Express-to-CLI bridge intact. Add a small Claude-only environment builder in `server.js`, feed it from `.env`, and verify through server-level process tests that Claude receives the provider config while Codex remains unchanged.

**Tech Stack:** Node.js, Express, dotenv, Node test runner, Windows `.cmd` launch wrappers

---

### Task 1: Add a failing regression test for Claude provider env injection

**Files:**
- Modify: `D:\remote-agent\tests\server-chat.test.js`
- Test: `D:\remote-agent\tests\server-chat.test.js`

- [ ] **Step 1: Write the failing test**

```js
test('server injects Anthropic-compatible env into Claude child process only', async () => {
  const tempDir = await fsp.mkdtemp(path.join(os.tmpdir(), 'remote-agent-claude-env-'));
  const envPath = path.join(tempDir, 'claude-env.txt');
  const cmdPath = path.join(tempDir, 'claude.cmd');
  await fsp.writeFile(cmdPath, [
    '@echo off',
    `echo ANTHROPIC_BASE_URL=%ANTHROPIC_BASE_URL%> "${envPath}"`,
    `echo ANTHROPIC_API_KEY=%ANTHROPIC_API_KEY%>> "${envPath}"`,
    'echo {"type":"assistant","message":{"content":[{"type":"text","text":"Claude env OK"}]}}',
  ].join('\r\n'));

  const port = await getFreePort();
  const token = 'test-token';
  const server = await startServer({
    AUTH_TOKEN: token,
    PORT: String(port),
    CLAUDE_BIN: cmdPath,
    CLAUDE_ANTHROPIC_BASE_URL: 'https://anthropic-compatible.example/v1',
    CLAUDE_ANTHROPIC_API_KEY: 'provider-key',
  });

  try {
    const response = await postJson(port, token, {
      engine: 'claude',
      prompt: 'say hello',
      cwd: projectRoot,
    });

    assert.equal(response.statusCode, 200);
    assert.match(response.body, /Claude env OK/);

    const envDump = await fsp.readFile(envPath, 'utf8');
    assert.match(envDump, /ANTHROPIC_BASE_URL=https:\/\/anthropic-compatible\.example\/v1/);
    assert.match(envDump, /ANTHROPIC_API_KEY=provider-key/);
  } finally {
    await stopChild(server.child);
    await fsp.rm(tempDir, { recursive: true, force: true });
  }
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `node --test tests/server-chat.test.js`
Expected: FAIL in the new Claude env test because the launched Claude child process does not yet receive `ANTHROPIC_BASE_URL` / `ANTHROPIC_API_KEY`.

- [ ] **Step 3: Confirm Codex remains isolated**

Run: `node --test tests/server-chat.test.js --test-name-pattern "server uses codex exec with supported arguments for /api/chat"`
Expected: PASS, showing the new Claude-focused test does not require any Codex-side behavior change.

### Task 2: Implement Claude-only provider env injection

**Files:**
- Modify: `D:\remote-agent\server.js`
- Test: `D:\remote-agent\tests\server-chat.test.js`

- [ ] **Step 1: Add a focused helper for Claude launch env**

```js
function buildClaudeEnv(baseEnv) {
  const env = { ...baseEnv };

  if (process.env.CLAUDE_ANTHROPIC_BASE_URL) {
    env.ANTHROPIC_BASE_URL = process.env.CLAUDE_ANTHROPIC_BASE_URL;
  }

  if (process.env.CLAUDE_ANTHROPIC_API_KEY) {
    env.ANTHROPIC_API_KEY = process.env.CLAUDE_ANTHROPIC_API_KEY;
  }

  return env;
}
```

- [ ] **Step 2: Use the helper only for Claude child process launch**

```js
const childEnv = engine === 'claude'
  ? buildClaudeEnv(process.env)
  : { ...process.env };

child = spawn(launcher.cmd, launcher.args, {
  cwd: workDir,
  shell: false,
  env: childEnv,
});
```

- [ ] **Step 3: Re-run server chat tests**

Run: `node --test tests/server-chat.test.js`
Expected: PASS with the new Claude env test green and the existing Claude/Codex spawn tests still green.

### Task 3: Document the new Claude provider configuration

**Files:**
- Modify: `D:\remote-agent\.env.example`
- Test: `D:\remote-agent\tests\server-chat.test.js`

- [ ] **Step 1: Add Claude Anthropic-compatible config comments**

```dotenv
# Optional: route Claude Code CLI through an Anthropic-compatible provider
# These are injected only into the Claude child process spawned by the web service
CLAUDE_ANTHROPIC_BASE_URL=
CLAUDE_ANTHROPIC_API_KEY=
```

- [ ] **Step 2: Run full verification**

Run: `npm test`
Expected: PASS with all server and UI tests green

Run: `npm run build`
Expected: PASS with Vite production bundle generated successfully
