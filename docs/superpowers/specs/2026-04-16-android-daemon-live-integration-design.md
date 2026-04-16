# Android Daemon Live Integration Design

**Problem**

The Flutter client now looks like the intended Android workbench, but it still renders seeded data. That means the app cannot yet manage real Codex work from the phone.

The daemon already exposes the core execution primitives:

- project listing
- conversation creation and listing
- message persistence
- run creation
- run interruption
- WebSocket event broadcast

But the current client cannot consume those primitives, and the current daemon payloads are still too thin for the mobile workbench UI.

**Goal**

Connect the Flutter app to the daemon so the Android workbench can:

- load real projects from `~/code`
- load real conversations for a project
- create a new conversation from the phone
- continue an existing conversation
- start a real Codex run for each user message
- show persisted message history
- show persisted action and error history
- receive live run events over WebSocket
- reflect current run status in workspace and conversation UI

**Non-Goals**

- No settings UI for daemon URL in this slice
- No authentication layer in this slice
- No attempt to solve full confirmation-required flow if Codex does not emit a detectable event yet
- No local offline cache in this slice
- No background service work on Android in this slice

**Key Gaps**

The daemon and client have four concrete gaps that block live use:

1. Flutter only reads seeded data.
2. Conversation summaries do not expose enough data for the workspace UI.
3. Historical `run_events` are not available as an HTTP snapshot.
4. Realtime events do not always include `conversationId`, which makes filtering on the phone unreliable.

**Design**

The integration should stay thin and explicit.

**1. Daemon becomes the source of truth for workspace snapshots**

The Flutter client should read:

- `GET /projects`
- `GET /projects/:projectId/conversations`
- `GET /conversations/:conversationId/messages`
- `GET /conversations/:conversationId/events`

The daemon should enrich project and conversation reads with the fields the workbench UI already expects.

**2. Conversation summaries become workbench-ready**

Each conversation summary returned to the app should include:

- `id`
- `projectId`
- `title`
- `status`
- `createdAt`
- `updatedAt`
- `lastMessagePreview`
- `activeRunId`
- `requiresConfirmation`

This lets the workspace render state badges, short previews, and control affordances without inferring state from raw text.

**3. Run transitions update conversation state**

The daemon should update the owning conversation when a run:

- starts
- completes
- is interrupted
- fails

This keeps workspace state deterministic and allows the project and conversation lists to reflect real run status after reconnect.

**4. Historical and live timeline data share the same shape**

The app conversation screen should display one combined timeline:

- user messages
- assistant messages
- action items
- error items

Historical data should come from HTTP snapshots. New events should stream in over WebSocket and be appended live.

The client should treat these as timeline events rather than trying to maintain separate message and action panes.

**5. Client scope stays simple**

Add a lightweight app scope that exposes a single `ApiClient` instance. Avoid introducing heavy state-management frameworks in this slice.

The screens should remain close to the current structure:

- `ProjectHomeScreen`
- `WorkspaceScreen`
- `ConversationScreen`

Statefulness should only be added where live loading or mutation is required.

**Transport**

Use:

- HTTP for initial snapshots and mutations
- WebSocket for live updates

The client should allow the daemon base URL to come from a compile-time define so real devices can target a Mac on the local network without changing code.

**Error Handling**

The client should surface daemon-side or network failures as visible error cards or inline load-state text. Silent failures are not acceptable because the app is meant to expose agent health while away from the desk.

This slice should explicitly handle:

- daemon unavailable
- non-200 API responses
- malformed payloads
- WebSocket disconnects
- run start failures

**Testing**

The slice needs coverage at two boundaries:

- daemon tests for enriched summaries, run-state updates, and conversation events
- Flutter tests for JSON mapping, real-client loading, and conversation timeline behavior with injected fake clients

The goal is not full end-to-end device coverage in this commit. The goal is to make the live daemon contract explicit and safe to extend.
