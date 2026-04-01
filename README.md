# Remote Code Agent

Windows-first remote web UI for `Codex CLI` and `Claude Code CLI`.

This project is built for a simple situation: when you are away from your desk, or even on vacation, but still want to keep an existing project's vibe coding momentum moving.

It provides a browser-based control surface for local coding agents, keeps a lightweight project/thread model, and mirrors your existing Codex desktop workspace roots and thread history into a mobile-friendly interface.

## Features

- Web chat UI for both `Codex` and `Claude`
- Streaming responses over SSE
- Windows controller launcher for easier startup and log handling
- Codex workspace root and thread history mirroring from local desktop state
- Chinese-first UI copy for phone and desktop usage
- Claude override support, while still defaulting to the local CLI's own config
- Optional FRP-based remote exposure

## How It Works

- The browser talks to `server.js`
- `server.js` launches `codex` or `claude` as local child processes
- Codex keeps using its own local config, such as `~/.codex/config.toml`
- Claude also keeps using its own local config, such as `~/.claude/settings.json` and `settings.local.json`
- If you explicitly set Claude override env vars in this app, those values are injected only into the Claude child process launched by this web service

## Requirements

- Windows
- Node.js 20+
- `Codex CLI` installed and available on `PATH`
- `Claude Code CLI` installed and available on `PATH`
- Optional: `frpc` if you want remote access through FRP

## Quick Start

1. Install dependencies

```powershell
npm install
```

2. Copy the example env file

```powershell
Copy-Item .env.example .env
```

3. Edit `.env` and set at least:

```dotenv
AUTH_TOKEN=replace-with-a-random-secret
DEFAULT_CWD=C:\
PORT=3333
```

4. Start the app

```powershell
npm start
```

Or on Windows, use the controller launcher:

```powershell
.\start-agent.bat
```

5. Open the local UI

```text
http://127.0.0.1:3333
```

## Optional Claude Override

By default, Claude launched from this app keeps using whatever configuration your local `Claude Code CLI` is already using, including tools like `cc-switch`.

Only set these if you want the web service to override Claude for its own child process:

```dotenv
CLAUDE_ANTHROPIC_BASE_URL=
CLAUDE_ANTHROPIC_AUTH_TOKEN=
CLAUDE_ANTHROPIC_API_KEY=
```

## Optional FRP Exposure

This repo does not track a real FRP config or binary by default.

- Use `frpc.example.toml` as a template
- Keep your real `frpc.toml` local
- Keep your real `frpc.exe` local

## Development

Run tests:

```powershell
npm test
```

Build the frontend:

```powershell
npm run build
```

## Security Notes

- Do not commit `.env`
- Do not commit real FRP configs or binaries
- Do not commit local run logs or mirrored state data
- Treat this app as a powerful local agent bridge, because it can launch coding CLIs on your machine

## Roadmap

- Better public setup docs for Claude and Codex providers
- Cleaner first-run onboarding
- More portable remote exposure options beyond FRP
- Better conversation continuation for mirrored histories

## Acknowledgements

This project was shaped in part by ideas and implementation direction borrowed from existing open source work:

- [`friuns2/codexui`](https://github.com/friuns2/codexui): UI direction, project/thread layout ideas, and mobile-friendly Codex-style interaction patterns
- [`farion1231/cc-switch`](https://github.com/farion1231/cc-switch): practical inspiration for reusing the active Claude provider configuration instead of forcing a separate web-only provider setup

## License

MIT
