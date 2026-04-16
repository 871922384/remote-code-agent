# Android Daemon Live Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Flutter seeded data with real daemon-backed projects, conversations, timeline snapshots, and live run updates.

**Architecture:** Enrich daemon read models first so the client can render the existing workbench UI without guessing. Then add a lightweight client scope and a real `ApiClient` that loads snapshots over HTTP and listens to `/ws` for live updates. Keep widget structure close to the current UI and add only the statefulness needed for loading, sending, and live refresh.

**Tech Stack:** Node.js, Express, SQLite, Flutter, Dart, `http`, `web_socket_channel`, `flutter_test`, Node test runner

---

### Task 1: Enrich daemon conversation and project snapshots

**Files:**
- Modify: `daemon/src/conversations/conversation-repo.js`
- Modify: `daemon/src/conversations/conversation-service.js`
- Modify: `daemon/src/projects/project-service.js`
- Modify: `daemon/tests/conversations.test.js`

- [ ] **Step 1: Write the failing daemon summary tests**

```js
test('conversation service returns workbench summaries with preview and active run metadata', async () => {
  // create conversation
  // append a message
  // assert listConversations() includes lastMessagePreview and status
})

test('project service returns running conversation counts and latest summary copy', () => {
  // seed project and conversation data
  // assert listProjects() includes runningConversationCount and lastSummary
})
```

- [ ] **Step 2: Run the daemon tests to verify they fail**

Run: `cd daemon && npm test`
Expected: FAIL because summaries only expose bare conversation rows and project reads do not compute workbench metadata.

- [ ] **Step 3: Add repo/service helpers for status and preview updates**

```js
// conversation-repo.js
updateStatus({ conversationId, status, now })
touch({ conversationId, now })

// conversation-service.js
listConversations(projectId) {
  // include lastMessagePreview, activeRunId, requiresConfirmation
}
```

- [ ] **Step 4: Add project-level derived metadata**

```js
// project-service.js
return {
  ...project,
  pinned: Boolean(metadata?.pinned),
  lastOpenedAt: metadata?.last_opened_at || null,
  lastActiveConversationId: metadata?.last_active_conversation_id || null,
  runningConversationCount,
  lastSummary,
}
```

- [ ] **Step 5: Run daemon tests again**

Run: `cd daemon && npm test`
Expected: PASS for conversation and project metadata coverage.

- [ ] **Step 6: Commit**

```bash
git add daemon/src/conversations/conversation-repo.js daemon/src/conversations/conversation-service.js daemon/src/projects/project-service.js daemon/tests/conversations.test.js
git commit -m "feat: enrich daemon workspace summaries"
```

### Task 2: Expose conversation event snapshots and deterministic run state

**Files:**
- Modify: `daemon/src/runs/run-service.js`
- Modify: `daemon/src/http/app.js`
- Modify: `daemon/tests/runs.test.js`

- [ ] **Step 1: Write the failing run/event tests**

```js
test('run service updates conversation status and lists conversation events', async () => {
  // start a fake run
  // assert conversation status becomes completed
  // assert conversation event list contains run.action and run.error
})
```

- [ ] **Step 2: Run the daemon tests to verify they fail**

Run: `cd daemon && npm test`
Expected: FAIL because run transitions do not update conversation rows and there is no conversation-level event snapshot.

- [ ] **Step 3: Implement state propagation and event listing**

```js
// run-service.js
updateConversationStatus.run('running', startedAt, conversationId)
// publish { kind, runId, conversationId, createdAt, payload }

function listConversationEvents(conversationId) {
  return selectConversationEvents.all(conversationId).map(...)
}
```

- [ ] **Step 4: Add the HTTP route**

```js
app.get('/conversations/:conversationId/events', (req, res) => {
  res.json({
    events: runService ? runService.listConversationEvents(req.params.conversationId) : [],
  });
});
```

- [ ] **Step 5: Run daemon tests again**

Run: `cd daemon && npm test`
Expected: PASS with event snapshot and state transition coverage.

- [ ] **Step 6: Commit**

```bash
git add daemon/src/runs/run-service.js daemon/src/http/app.js daemon/tests/runs.test.js
git commit -m "feat: expose daemon conversation events"
```

### Task 3: Add a real Flutter API client and app scope

**Files:**
- Create: `app/lib/src/app_scope.dart`
- Modify: `app/lib/app.dart`
- Modify: `app/lib/src/data/api_client.dart`
- Modify: `app/lib/src/models/project_summary.dart`
- Modify: `app/lib/src/models/conversation_summary.dart`
- Modify: `app/lib/src/models/conversation_event.dart`
- Create: `app/lib/src/models/realtime_event.dart`
- Create: `app/test/api_client_test.dart`

- [ ] **Step 1: Write the failing Flutter client tests**

```dart
test('fetchProjects maps daemon project payloads into project summaries', () async {
  // MockClient returns /projects JSON
  // expect name/path/runningConversationCount/lastSummary
});

test('fetchConversationTimeline merges messages and run events in timestamp order', () async {
  // MockClient returns messages + events payloads
  // expect action/error/message timeline order
});
```

- [ ] **Step 2: Run the focused Flutter tests to verify they fail**

Run: `cd app && flutter test test/api_client_test.dart`
Expected: FAIL because the current client only returns seeded constants.

- [ ] **Step 3: Implement the real API client**

```dart
class ApiClient {
  ApiClient({
    Uri? baseUri,
    http.Client? httpClient,
    WebSocketChannel Function(Uri uri)? webSocketFactory,
  }) : ...

  Future<List<ProjectSummary>> fetchProjects() async { ... }
  Future<List<ConversationSummary>> fetchConversations(String projectId) async { ... }
  Future<List<ConversationEvent>> fetchConversationTimeline(String conversationId) async { ... }
  Future<ConversationSummary> createConversation(...) async { ... }
  Future<void> appendUserMessage(...) async { ... }
  Future<String?> startRun(...) async { ... }
  Future<void> interruptRun(String runId) async { ... }
  Stream<RealtimeEvent> watchEvents() { ... }
}
```

- [ ] **Step 4: Add app scope wiring**

```dart
class WorkbenchScope extends InheritedWidget {
  const WorkbenchScope({super.key, required this.apiClient, required super.child});
  final ApiClient apiClient;
}
```

- [ ] **Step 5: Run the focused Flutter tests again**

Run: `cd app && flutter test test/api_client_test.dart`
Expected: PASS with real HTTP mapping covered.

- [ ] **Step 6: Commit**

```bash
git add app/lib/app.dart app/lib/src/app_scope.dart app/lib/src/data/api_client.dart app/lib/src/models/project_summary.dart app/lib/src/models/conversation_summary.dart app/lib/src/models/conversation_event.dart app/lib/src/models/realtime_event.dart app/test/api_client_test.dart
git add -f app/lib/src/data/api_client.dart
git commit -m "feat: add live daemon api client"
```

### Task 4: Switch project, workspace, and conversation screens to live daemon data

**Files:**
- Modify: `app/lib/src/features/projects/project_home_screen.dart`
- Modify: `app/lib/src/features/workspace/conversation_strip.dart`
- Modify: `app/lib/src/features/workspace/conversation_strip_item.dart`
- Modify: `app/lib/src/features/workspace/workspace_screen.dart`
- Modify: `app/lib/src/features/conversation/conversation_composer.dart`
- Modify: `app/lib/src/features/conversation/conversation_screen.dart`
- Modify: `app/test/app_theme_test.dart`
- Modify: `app/test/project_home_screen_test.dart`
- Modify: `app/test/workspace_screen_test.dart`
- Modify: `app/test/conversation_screen_test.dart`

- [ ] **Step 1: Write the failing widget updates**

```dart
testWidgets('project home loads projects from the injected api client', ...)
testWidgets('workspace opens a live conversation screen and refreshes after return', ...)
testWidgets('conversation screen loads timeline events and sends a message', ...)
```

- [ ] **Step 2: Run the focused Flutter widget tests to verify they fail**

Run: `cd app && flutter test test/project_home_screen_test.dart test/workspace_screen_test.dart test/conversation_screen_test.dart`
Expected: FAIL because screens still depend on seeded data and static event lists.

- [ ] **Step 3: Make the screens live**

```dart
// project_home_screen.dart
final client = WorkbenchScope.of(context).apiClient;

// workspace_screen.dart
// load conversations on init, open ConversationScreen with projectId + conversationId

// conversation_screen.dart
// fetch snapshot, subscribe to watchEvents(), send messages, start runs, interrupt active run
```

- [ ] **Step 4: Run the full Flutter suite**

Run: `cd app && flutter test`
Expected: PASS with live-client widget coverage and no regressions.

- [ ] **Step 5: Commit**

```bash
git add app/lib/src/features/projects/project_home_screen.dart app/lib/src/features/workspace/conversation_strip.dart app/lib/src/features/workspace/conversation_strip_item.dart app/lib/src/features/workspace/workspace_screen.dart app/lib/src/features/conversation/conversation_composer.dart app/lib/src/features/conversation/conversation_screen.dart app/test/app_theme_test.dart app/test/project_home_screen_test.dart app/test/workspace_screen_test.dart app/test/conversation_screen_test.dart
git commit -m "feat: connect flutter workbench to live daemon"
```

### Task 5: Final verification

**Files:**
- No planned file changes

- [ ] **Step 1: Run daemon verification**

Run: `cd daemon && npm test`
Expected: PASS

- [ ] **Step 2: Run Flutter verification**

Run: `cd app && flutter test`
Expected: PASS

- [ ] **Step 3: Sanity-check the worktree**

Run: `git status --short`
Expected: clean worktree
