# Android Agent Workbench Design

**Problem**

The current project is a Windows-first remote web wrapper for Codex CLI and Claude Code CLI. That shape no longer matches the intended working environment or the actual user workflow.

The new target workflow is:

1. The developer works primarily on a Mac.
2. The developer uses Codex CLI as the primary agent tool.
3. When away from the desk, the developer uses an Android phone to continue real agent work remotely.
4. The mobile experience should feel closer to "managing several ongoing Codex conversations" than to "operating a raw shell in a browser."

The current system has four mismatches with that workflow:

1. It is built around Windows launchers and Windows-first assumptions.
2. It still carries Claude-specific flows that are no longer required.
3. It mirrors `~/.codex` state instead of treating this product as the source of truth for its own sessions.
4. Its main interaction model is a web chat surface, while the desired phone workflow is a multi-conversation workbench with rapid switching, visible agent actions, visible failures, and minimal typing overhead.

**Goals**

- Reposition the product as a Mac-only backend service plus an Android app.
- Support Codex CLI only.
- Let the user work from a phone by managing multiple ongoing conversations across projects.
- Keep project selection extremely fast by treating `~/code` as the fixed workspace root and each first-level folder as a project.
- Make conversation switching fast enough to preserve the feeling of several side-by-side Codex sessions.
- Show three kinds of output in each conversation:
  - normal conversation messages
  - Codex work/action states
  - failures and error causes
- Support the core mobile actions:
  - new conversation
  - continue conversation
  - confirm continue
  - interrupt conversation
- Keep conversations durable across app backgrounding, network drops, and reconnects.
- Allow multiple conversations to run in parallel, including multiple conversations in the same project.

**Non-Goals**

- No raw terminal or shell emulation inside the mobile app.
- No Windows support.
- No Claude support.
- No `~/.codex` mirroring as the primary session model.
- No generic project CRUD UI.
- No attempt to reproduce iTerm2 visually.
- No public-internet-first deployment design; private-network access is sufficient.

**Product Definition**

The new product is:

`Android Flutter Agent Workbench + Mac-only Codex Daemon`

The daemon owns process execution, session state, and real-time event delivery. The Android app owns the mobile interaction model. Codex CLI remains the execution engine but is not exposed as a raw terminal interface.

This is not a "remote chat UI" and not a "mobile terminal." It is a structured workbench for agent-driven development from a phone.

**Primary User Workflow**

The expected workflow is:

1. Open the app on Android.
2. See the fixed list of projects derived from `~/code`.
3. Enter a project quickly.
4. View the project's ongoing conversations as a horizontally scrollable strip of conversation avatars/cards.
5. Open one conversation while still seeing status for the others.
6. Read the conversation, Codex work states, and any errors.
7. Send a normal message when starting or continuing work.
8. Use explicit actions for confirmation and interruption when needed.
9. Switch rapidly to another conversation or project without losing context.

The mobile interaction should feel like "chat plus live work status plus fast conversation switching," not like "typing commands into a terminal."

**Project Model**

Projects are discovered, not manually managed.

- The workspace root is `~/code`.
- Each first-level folder under `~/code` is a project.
- The project name is the folder name.
- The project ID is the absolute path.
- The app does not expose "create project" or "edit project" flows.

Only a small amount of product-owned metadata is needed:

- `pinned`
- `lastOpenedAt`
- `lastActiveConversationId`

Startup behavior should scan the workspace once. Later versions may add file watching, but manual refresh is sufficient for the initial design.

**Conversation Model**

The core unit is a conversation, not a task list and not a shell session.

- A project contains multiple conversations.
- A conversation is a durable container for messages and execution history.
- A conversation may have many execution rounds over time.
- One conversation can have only one active run at a time.
- Multiple conversations may run in parallel.

This separation is required so the app can present stable conversation switching while still handling interruption, confirmation, completion, and failure at run granularity.

**Run Model**

Each active execution round is represented as a run attached to a conversation.

A run tracks:

- current status
- start and end timestamps
- whether confirmation is required
- action timeline
- error details if the round fails

The user interacts with a conversation, but the daemon manages the currently active run inside that conversation.

**State Model**

The daemon should use a small, explicit state model:

- `idle`
- `running`
- `waiting_confirmation`
- `interrupted`
- `completed`
- `failed`

For user-facing copy, `completed` and `idle` may be merged into something like "done / ready to continue," but the backend should keep the states distinct.

State transitions must be deterministic and owned by the daemon. The app should never infer state from partial text output.

**Output Model**

Each conversation view must display three parallel information layers:

1. `Conversation layer`
   - normal user and assistant messages
2. `Action layer`
   - what Codex is doing now or has done during the current run
   - examples: reading files, searching, editing, running tests, waiting for confirmation
3. `Error layer`
   - meaningful failure causes and execution problems
   - examples: API unavailable, process exited, timeout, tool failure, permission issue

Action and error information must be first-class UI content, not hidden debug details.

The user explicitly wants to see Codex working state and operational failures from the phone, especially when an upstream API or provider is down.

**Mobile Interaction Model**

The Android app should use a conversation-workbench layout:

- Project list as the entry point.
- Project detail opens a conversation workspace.
- The workspace shows a horizontal conversation strip at the top.
- Each conversation item shows:
  - avatar or initial
  - title
  - current state badge
  - latest short preview
- The active conversation fills the main area.
- The main area displays the message stream interleaved with action and error cards.
- The bottom area contains:
  - a normal chat input
  - explicit `Confirm` and `Interrupt` actions when available

The conversation strip is the mobile replacement for the user's current multi-column desktop workflow. The phone does not need literal columns, but it must preserve "several ongoing conversations visible at once and fast to switch."

Action and error items should be shown expanded by default rather than hidden behind a collapsed disclosure.

**Input Model**

The app should keep input simple:

- `New conversation` starts a fresh conversation in the current project with a normal natural-language message.
- `Continue conversation` means sending another normal message in an existing conversation.
- The app should not expose shell commands or command-style prompts.
- The app should not force templates or structured prompt builders in the initial version.

This keeps the interaction close to the user's real workflow, where the phone is used for normal conversational steering rather than shell typing.

**Core Actions**

The initial product should support these actions:

- `New conversation`
- `Continue conversation`
- `Confirm continue`
- `Interrupt conversation`
- `Rename conversation`
- `Archive conversation`

Additional helper actions like "summarize" may exist later, but they are not required for the initial product definition.

The highest-priority actions are:

1. rapid conversation switching across projects
2. stable live execution visibility
3. confirm / interrupt control

**Recovery and Parallelism**

The system must be designed around mobile instability without losing work:

- If the phone disconnects or the app backgrounds, the daemon keeps running on the Mac.
- On reconnect, the app fetches current snapshots and resumes the live stream.
- The source of truth for conversations and runs is the daemon's own store, not `~/.codex`.
- Multiple conversations may run in parallel.
- The project list and conversation strip must surface conversation status without opening each conversation.

This design optimizes for "what is currently running, waiting, blocked, or failed" rather than for terminal restoration.

**Backend Architecture**

The Mac daemon should be split into these modules:

1. `Workspace Scanner`
   - scans `~/code`
   - builds the fixed project list
2. `Project Metadata Store`
   - stores product-owned metadata such as pinning and recent activity
3. `Conversation Store`
   - stores conversations, messages, runs, action events, and error events
4. `Codex Process Manager`
   - starts and supervises Codex child processes
   - handles output, exit status, interruption, and orphan cleanup
5. `Run Coordinator`
   - translates app actions into Codex execution behavior
   - enforces one active run per conversation
6. `Event Broker`
   - publishes real-time updates to connected clients

The daemon should own all state transitions. The mobile client should act as a thin but polished remote controller.

**Client Architecture**

The Android app should be organized around:

1. `Project Home`
2. `Conversation Workspace`
3. `Conversation View`
4. `Realtime Connection Layer`
5. `Local Snapshot Cache`

The client should optimize for:

- fast app resume
- quick project re-entry
- smooth conversation switching
- immediate visibility into running, waiting, completed, and failed conversations

**Transport**

Use:

- `HTTP` for snapshots and action endpoints
- `WebSocket` for live updates

The app should load a full snapshot first, then subscribe to incremental events. After reconnect, it should refresh the current snapshot instead of relying on perfect event replay.

Private network access via tools such as Tailscale is acceptable and preferred over public exposure in the initial version.

**Resource and Event Shape**

The daemon should expose stable resources:

- `Project`
- `Conversation`
- `Message`
- `Run`

It should also emit real-time events such as:

- `conversation.updated`
- `message.created`
- `run.started`
- `run.chunk`
- `run.waiting_confirmation`
- `run.interrupted`
- `run.completed`
- `run.failed`
- `run.action`
- `run.error`

The important rule is that the client receives structured display-ready events, not raw terminal bytes.

**Persistence**

Use local daemon-owned persistence:

- `SQLite` for conversations, messages, runs, and event/state indices
- small JSON config files only for lightweight daemon configuration

This product should no longer treat Codex's own internal local state as the canonical store for mobile workbench sessions.

**Technology Direction**

The recommended technology direction is:

- `Node.js` for the Mac daemon
- `Flutter` for the Android app
- `SQLite` for durable local state
- `HTTP + WebSocket` for transport

This keeps the existing server-side execution experience that already exists in the repository while replacing the product boundary and client shape.

**Repository Direction**

The repository should be reoriented around two primary products:

- `daemon/`
- `app/`

Likely removal or retirement targets:

- Windows launcher scripts
- Windows controller logic
- Claude-specific launch/config paths
- Codex mirror-store assumptions tied to `~/.codex`
- the current Vue web UI as the primary product surface

Potentially reusable ideas from the current codebase:

- child-process launch and supervision patterns
- lightweight service/API structure
- state-store concepts that can be adapted to the new daemon-owned model

**Migration Direction**

The refactor should proceed as a product migration, not as a small compatibility tweak.

The intended migration sequence is:

1. Carve out a Mac-only Codex daemon from the current server-side logic.
2. Replace mirrored Codex-session assumptions with daemon-owned persistence.
3. Define stable conversation/run APIs and event streams.
4. Build the Flutter Android client against those APIs.
5. Retire Windows, Claude, and web-primary flows.

This should be treated as a new product evolution from the current repository, not as a thin platform-porting exercise.

**Testing Direction**

The implementation plan should include testing for:

- workspace scanning from `~/code`
- project metadata behavior
- conversation creation and continuation
- one-active-run-per-conversation enforcement
- multiple parallel conversations
- interruption behavior
- confirmation behavior
- run failure capture and display payload shape
- reconnect snapshot correctness
- mobile client rendering of message/action/error streams

Good tests should validate externally visible behavior and state transitions, not internal implementation details.

**Open Decisions Already Resolved**

The design intentionally fixes the following decisions:

- Mac-only
- Codex-only
- Android-first client
- Flutter client
- no raw terminal
- fixed workspace root at `~/code`
- folder name as project name
- daemon-owned session model
- action visibility required
- error visibility required
- action/error items shown expanded by default

**Summary**

The target system is a focused mobile agent workbench for Android, backed by a Mac daemon that owns Codex conversations and execution state. The experience is optimized for rapid project entry, rapid conversation switching, visible work progress, visible failures, and lightweight conversational control from a phone.
