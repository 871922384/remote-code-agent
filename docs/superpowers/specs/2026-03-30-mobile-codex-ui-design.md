# Mobile Codex-Style UI Design

## Summary

This document defines a simple visualization upgrade for the existing Remote Agent service. The goal is to keep the current backend API and dual-engine support (`Claude` and `Codex`) while reshaping the frontend into a mobile-first, Codex-style single-session workspace.

The first version focuses on presentation and interaction improvements only. It does not add multi-session history, persistent storage, or new backend capabilities.

## Goals

- Keep the existing `/api/ping`, `/api/chat`, and `/api/kill/:id` API behavior unchanged.
- Preserve the current `Claude / Codex` engine switch.
- Make the UI feel like a mobile version of desktop Codex rather than a generic admin panel.
- Prioritize a single active session with strong streaming feedback.
- Keep the deployment model unchanged by reworking the existing static page instead of introducing a frontend framework.

## Non-Goals

- No backend protocol changes.
- No session history persistence.
- No multi-conversation management.
- No file tree or IDE-style side panels.
- No full Markdown renderer.
- No user account system.

## User Experience

The page should feel like a focused mobile work console for one remote coding agent. The default experience is:

1. Open the page and authenticate with the token.
2. See whether the service is online.
3. Choose `Claude` or `Codex`.
4. Enter a prompt in a fixed bottom composer.
5. Watch the active agent stream progress in a single timeline-like feed.
6. Stop the run at any time.
7. Open a lightweight settings drawer only when changing `cwd`, clearing the session, or checking connection details.

The core interaction model is "one agent currently working" rather than "a chat app with many messages."

## Information Architecture

The page will be reorganized into a single-column mobile-first layout with five functional sections:

### 1. Top Bar

Purpose:

- Show product identity.
- Show online/offline state.
- Provide access to settings.

Contents:

- Compact product title.
- Connection status indicator and label.
- Settings button.

The top bar must stay light and uncluttered on narrow screens.

### 2. Engine Switch

Purpose:

- Let the user switch between `Claude` and `Codex` without adding visual noise.

Contents:

- A segmented control directly below the top bar.

Behavior:

- Exactly one engine is active at a time.
- Switching engines updates the state used by the next request only.
- The control remains accessible on mobile without taking over the page.

### 3. Session Feed

Purpose:

- Show the active workstream in a way that feels like Codex operating, not a classic chat bubble exchange.

Contents:

- User prompt cards.
- Agent run cards.
- Tool activity sections.
- Error and completion states.

Behavior:

- New user prompts append to the feed.
- Starting a request immediately creates a new active agent card.
- Streaming output appends into the current active agent card.
- Finishing or stopping a request updates the card state in place.

### 4. Composer

Purpose:

- Keep prompt entry always available.

Contents:

- Multi-line textarea.
- Primary action button that toggles between send and stop.

Behavior:

- Fixed to the bottom of the viewport.
- Supports mobile-friendly sizing and spacing.
- Sends on `Ctrl+Enter` where supported, but must remain usable through the main button on touch devices.

### 5. Settings Drawer

Purpose:

- Hold low-frequency controls that should not live in the main layout.

Contents:

- Current working directory input.
- Clear session action.
- Token or connection status summary.

Behavior:

- Opens as an overlay or slide-up panel on mobile.
- Closes without leaving the current session view.

## Visual Direction

The UI should keep the dark tone of the current page but shift away from a terminal-dashboard aesthetic.

Visual principles:

- Mobile-first spacing and proportions.
- Soft card surfaces with clear separation between layers.
- Minimal chrome around controls.
- Monospace text for streamed output only.
- Cleaner sans-serif typography for labels, headings, and navigation.
- Clear status colors for active, warning, error, and completed states.

The page should feel calm, focused, and operational. It should not feel like a monitoring dashboard or a consumer messaging app.

## Component Model

The implementation should stay in the current static page but be mentally organized into the following UI units:

- `AppShell`
- `TopBar`
- `EngineSwitch`
- `SessionFeed`
- `UserPromptCard`
- `AgentRunCard`
- `Composer`
- `SettingsDrawer`
- `AuthScreen`

These do not need to become separate JavaScript modules in the first version, but the markup, styles, and state handling should be reorganized to reflect these boundaries.

## Message and Run Presentation

### User Prompt Card

Use a compact card style with clear contrast from agent cards. The user prompt should read like an instruction handed to the agent.

### Agent Run Card

Each run card should contain:

- Engine label (`Claude` or `Codex`)
- Live state indicator
- Main streamed output area
- Optional tool/event sections

The run card is the main unit of visual identity for the page. It should make the system feel like an agent is actively working through a task.

### Event Styling

Different event types should be visually distinct:

- Plain output: normal streamed content
- Tool event: subdued utility styling
- Error event: high-contrast warning treatment
- Completion event: resolved and calmer state
- Interrupted event: explicit stopped state

## Frontend State Model

The frontend should continue using plain browser state, but the model should be cleaned up around the following values:

- `TOKEN`
- `engine`
- `streaming`
- `currentSessionId`
- `currentReader`
- `settingsDrawerOpen`
- `connectionStatus`
- `messages`
- `streamBuffer`

Where possible, rendered feed items should come from a message/run state structure rather than ad hoc DOM mutations.

## Data Flow

### Authentication

- The app checks for a stored token.
- If a token exists, it validates through `/api/ping`.
- If validation succeeds, the auth screen is hidden and the main shell is shown.
- If validation fails, the auth screen stays visible with an error.

### Request Lifecycle

1. User submits a prompt.
2. Frontend appends a user card.
3. Frontend appends an empty active agent run card.
4. Frontend calls `/api/chat`.
5. SSE events stream into the active run card.
6. Frontend stores the `sessionId` when present.
7. On stop, frontend cancels the reader and calls `/api/kill/:id`.
8. On completion, the active run card moves from running state to completed state.

### Ping Lifecycle

- The UI uses `/api/ping` to decide whether to show online or offline state.
- If requests fail unexpectedly, the visible connection state should degrade gracefully to offline or error.

## Error Handling

The first version should make failures much more legible than the current page.

Required cases:

- Invalid token
- Ping failure
- Chat HTTP failure
- Streaming connection failure
- CLI stderr output
- Manual interruption

Each case should produce a clear visual state in the relevant card or panel rather than disappearing into raw text only.

## Responsive Behavior

The page should be designed for mobile first.

### Narrow Screens

- Single-column layout only
- Fixed composer at bottom
- Settings presented as drawer or sheet
- Comfortable touch targets
- Feed cards stacked with breathable spacing

### Wide Screens

- The same single-column experience remains
- The content width can grow to a comfortable reading measure
- No return to the old multi-control horizontal layout

## Accessibility and Usability

The first version should include these practical safeguards:

- Sufficient contrast for text and status indicators
- Buttons with visible pressed and disabled states
- Input focus styles
- No tiny tap targets
- Scroll behavior that remains stable while output streams

## Implementation Scope

The first implementation pass should be limited to:

- Rebuilding the page layout into a mobile-first single-column shell
- Restyling and restructuring the session feed
- Moving `cwd` and low-frequency actions into a settings drawer
- Improving run-state rendering for streaming, completion, error, and interruption
- Preserving existing auth and backend integration

The first implementation pass should not include:

- Saving past runs
- Exporting logs
- Syntax highlighting libraries
- Markdown packages
- Server-side session tracking changes

## Verification Plan

After implementation, verify the following in both a mobile-width viewport and a desktop-width viewport:

1. Token authentication still works.
2. Online/offline state appears correctly.
3. Engine switching still affects requests.
4. A prompt can be submitted successfully.
5. Streaming output appears incrementally in the active run card.
6. Stop correctly interrupts the session and updates the UI.
7. Errors are visible and understandable.
8. Settings drawer can update `cwd` and clear the current feed.
9. Narrow-screen layout remains usable without horizontal overflow.

## Risks and Mitigations

### Risk: DOM updates stay too tightly coupled to raw stream text

Mitigation:

- Introduce a clearer run/message state model before polishing styles.

### Risk: Mobile fixed composer overlaps feed content

Mitigation:

- Reserve bottom padding in the feed and test with longer output.

### Risk: Visual redesign accidentally obscures diagnostic information

Mitigation:

- Keep raw output accessible inside the run card, but organize it with clearer visual grouping.

## Recommended Next Step

Write an implementation plan that focuses on:

1. Restructuring the HTML layout.
2. Rebuilding the CSS for mobile-first presentation.
3. Refactoring the JavaScript state and feed rendering.
4. Running viewport-based verification.
