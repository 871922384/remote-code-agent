# Android Agent Workbench UI Design

**Problem**

The product direction is already defined: a Mac-only Codex daemon plus an Android app for managing multiple ongoing agent conversations from a phone.

What remains undefined is the UI system that turns that product shape into a stable, high-quality mobile experience. The UI must satisfy two constraints at the same time:

1. It should feel friendly, bright, and polished, taking clear inspiration from Intercom's product tone rather than from terminal software.
2. It should still behave like a serious engineering workbench, with fast conversation switching, visible agent actions, visible failures, and reliable mobile controls.

The UI also needs an implementation strategy. Building every visual primitive from scratch in Flutter would slow delivery and increase inconsistency risk. We need a component foundation that can be adapted to the desired design language without forcing the product into a generic enterprise look.

**Design Direction**

The chosen direction is:

`Intercom-inspired friendliness + premium mobile tool layout + engineering workbench clarity`

This means:

- bright and welcoming, not dark or terminal-like
- blue-led but not blue-saturated
- spacious, touch-friendly, and easy to scan with one hand
- more premium-product homepage than inbox-clone homepage
- message views that feel conversational, but not playful or social
- action and error visibility treated as first-class system feedback

**Visual Positioning**

The visual system should split its personality by screen:

- `Project Home`: premium product surface
- `Project Workspace`: operational overview surface
- `Conversation View`: calm, readable conversation surface

The result should not look like a customer support dashboard, even though the tone is inspired by Intercom.

**Implementation Foundation**

The implementation should use `TDesign Flutter` as the primary component library foundation:

- Official overview reference: https://tdesign.tencent.com/flutter/overview

This is the recommended approach.

**Why TDesign Flutter Fits**

- It gives the app a mature Flutter component baseline rather than forcing a fully custom widget system.
- It reduces implementation instability in common controls such as buttons, text fields, sheets, dialogs, switches, navigation structures, and list primitives.
- It supports faster UI iteration while still allowing the product to impose its own theme, spacing, status treatment, and page composition.

**How TDesign Flutter Should Be Used**

TDesign should be treated as:

- the base component layer
- not the visual identity
- not the page system
- not the final product style

The product should override and adapt TDesign through:

- custom color tokens
- custom radius and spacing tokens
- custom typography choices
- custom page composition
- a small set of product-specific widgets where generic components are not sufficient

In other words:

`TDesign supplies the stable primitives; the workbench UI supplies the product identity.`

**When to Use TDesign Directly**

Use TDesign components directly for:

- primary and secondary buttons
- text input fields
- modal sheets
- confirmation dialogs
- toast or feedback patterns
- tabs where appropriate
- base list rows
- badges and tags
- loading and empty states
- settings and utility screens

**When to Wrap TDesign**

Wrap TDesign components for:

- project cards
- conversation strip items
- status chips
- message cards
- action cards
- error cards
- bottom composer area

The product should expose its own wrappers so the app code uses stable workbench-level components rather than raw library widgets everywhere.

**When to Build Custom Widgets**

Build custom widgets where the product interaction is too specific for a generic library pattern:

- horizontal conversation avatar/card strip
- interleaved conversation timeline with message/action/error blocks
- compact run state summaries
- project cards that mix preview text, active-counts, and status treatment
- action/error blocks designed for expanded-by-default operational transparency

These are core to the product identity and should not be forced into generic list-cell shapes.

**Design Principles**

1. `Friendly, not cute`
   The app should feel approachable and modern without becoming playful or toy-like.

2. `Premium, not sterile`
   The homepage should feel more like a high-quality software product than a utilitarian control panel.

3. `Operational clarity over decorative novelty`
   Action states and failures must be readable at a glance.

4. `Comfortable touch targets`
   The app is designed primarily for one-handed phone use.

5. `Conversation-first, not terminal-first`
   Input remains normal conversational input, never command-entry UI.

6. `Status always visible`
   Running, waiting, failed, and completed states must remain visible across project and conversation surfaces.

**Color System**

The palette should be Intercom-adjacent in spirit, but more premium and restrained in application.

Core colors:

- `Primary Blue`
  Used for primary actions, active selections, and running-state emphasis.
- `Surface White`
  Used for primary cards and elevated surfaces.
- `App Background`
  A very light warm-neutral background rather than pure white.
- `Text Primary`
  Deep gray rather than full black.
- `Text Secondary`
  Mid gray for metadata and supporting labels.
- `Soft Border`
  Very light gray-blue border for separation.

State colors:

- `Running`: clean bright blue
- `Waiting`: soft amber
- `Completed`: clean teal-green
- `Failed`: soft coral-red
- `Idle`: cool gray

Color usage rule:

- Blue is the brand anchor, but must not dominate full-screen backgrounds.

**Typography**

Typography should support a calm product tone:

- page titles with moderate authority
- section titles with clean emphasis
- body copy optimized for long reading
- metadata lighter and quieter
- status labels short and direct

The app should keep a limited hierarchy, ideally no more than 4-5 effective text sizes across the main UI.

**Spacing and Shape**

The UI should feel spacious and touch-friendly:

- generous outer page padding
- large card padding
- stable gaps between cards and timeline blocks
- slightly larger-than-default corner radii
- extremely light shadow usage

The product should avoid compressed layouts, especially on core workflow screens.

**Page Architecture**

The UI consists of three main screens:

1. `Project Home`
2. `Project Workspace`
3. `Conversation View`

This keeps the navigation model light and predictable on mobile.

**Project Home**

Purpose:

- fast project entry
- clear overview of where active work is happening

Layout:

- branded header with breathing room
- high-end product-style title area
- lightweight top actions such as refresh, settings, and connection state
- large project cards stacked vertically

Each project card should show:

- project identifier
- last active summary
- count of active/running conversations
- clear entry affordance

Visual tone:

- more premium-tool than inbox
- fewer, larger, calmer cards
- generous whitespace

**Project Workspace**

Purpose:

- communicate what is happening inside the selected project
- preserve the feeling of several ongoing sessions at once

Layout:

- project title and simple back affordance
- horizontal conversation strip near the top
- visible status on every conversation item
- selected conversation highlighted clearly
- lower area showing current conversation preview or summary content
- persistent `New conversation` entry point

The conversation strip is the mobile replacement for the user's current multi-column desktop work style.

**Conversation View**

Purpose:

- deep focus on one conversation
- continued control of the current run

Layout:

- top bar with conversation title and run state
- main scrolling timeline
- timeline interleaves:
  - message cards
  - action cards
  - error cards
- bottom composer with:
  - natural-language text input
  - send action
  - `Confirm` and `Interrupt` controls when relevant

Action and error blocks are shown expanded by default.

**Core Product Components**

The product should define and own these components:

1. `ProjectCard`
2. `ConversationStripItem`
3. `ConversationStateBadge`
4. `MessageCard`
5. `ActionCard`
6. `ErrorCard`
7. `ConversationComposer`

These should be product-level widgets even if they are partially built from TDesign internals.

**ProjectCard**

The project card should feel like a premium entry point, not a filesystem row.

Contents:

- project monogram or simple project mark
- project name
- recent summary
- active conversation count
- subtle status footer or accent

Interaction:

- large touch area
- soft pressed state
- no crowded metadata

**ConversationStripItem**

This is the most identity-critical mobile component.

Contents:

- avatar or initial block
- short title
- one-line summary
- visible state indicator

Behavior:

- horizontally scrollable
- selected item strongly differentiated
- unselected items still readable
- long-press actions for rename/archive

**MessageCard**

Message presentation should be calmer than consumer chat apps.

Rules:

- user and assistant messages remain distinguishable
- bubbles should be broader and less playful
- code and quote blocks must have stronger structure
- long reading takes priority over decorative chat styling

**ActionCard**

Action cards communicate what Codex is doing.

Examples:

- `Reading project files`
- `Searching for matching code`
- `Updating 2 files`
- `Running tests`
- `Waiting for confirmation`

Presentation:

- not chat bubbles
- soft system-card styling
- icon-led
- expanded by default

**ErrorCard**

Error cards communicate why work stalled or failed.

Examples:

- `API unavailable`
- `Process exited`
- `Tool call failed`
- `Request timed out`

Presentation:

- warm soft red surface
- clear headline
- readable supporting detail
- no terminal dump as the primary surface

**Composer**

The composer should remain conversational, not command-like.

Structure:

- large rounded input field
- explicit send action
- adjacent or nearby confirm/interrupt controls depending on state

The composer should feel like a polished product control surface, not a shell prompt.

**State Treatment**

Canonical backend states:

- `idle`
- `running`
- `waiting_confirmation`
- `interrupted`
- `completed`
- `failed`

UI treatment must keep state visible on:

- project cards
- conversation strip items
- conversation header
- action and error blocks

Recommended visible colors:

- blue for running
- amber for waiting
- green for completed
- coral for failed
- gray for idle/interrupted where appropriate

**Microcopy Direction**

The language should be:

- short
- warm
- calm
- direct
- not theatrical
- not overly technical by default

Examples of preferred labels:

- `New conversation`
- `Confirm`
- `Interrupt`
- `Running`
- `Waiting`
- `Failed`
- `Done`

Avoid:

- playful AI-assistant phrases
- terminal jargon in primary UI copy
- customer support clichés

**Motion**

Motion should be subtle and purposeful:

- soft card press feedback
- smooth horizontal strip scrolling
- simple state transitions
- no flashy animated handoff sequences

The UI should feel alive, not animated for its own sake.

**Accessibility**

The design should assume:

- outdoor and quick-glance usage on a phone
- one-handed interactions
- need for strong visual distinction between normal content and failure content

Minimum expectations:

- clear color contrast
- sufficiently large tap targets
- readable status without relying on color alone
- stable text hierarchy

**Implementation Guidance**

The recommended implementation stack is:

- TDesign Flutter for foundational widgets
- product-level design tokens layered on top
- custom workbench widgets for project/conversation/action/error structures

The team should not attempt to skin every TDesign component globally without discipline. Instead:

1. define product tokens first
2. map TDesign usage to those tokens
3. wrap library widgets behind product components
4. build custom widgets only where the product interaction is unique

This approach improves implementation stability without sacrificing product distinctiveness.

**Out of Scope**

- full custom design system from scratch
- terminal emulation aesthetics
- desktop/tablet-first layout optimization
- visually dense developer-console treatment
- generic chat-app mimicry

**Summary**

The app should be implemented as a friendly, premium-feeling Android workbench for remote Codex work. `TDesign Flutter` is the right component foundation, provided it is treated as a stable primitive layer and not as the final visual language. The final product identity must come from workbench-specific layout, tokens, and custom conversation/state components.
