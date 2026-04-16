# Android Agent Workbench UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Flutter client UI around the approved Intercom-inspired workbench design using `TDesign Flutter` as the component foundation and product-specific wrappers for the core workbench surfaces.

**Architecture:** Keep `tdesign_flutter` as the primitive widget layer for buttons, inputs, tags, and dialog affordances, while moving product identity into a small theme/token layer plus custom workbench widgets. The implementation should stay incremental: first establish theme and tokens, then refit project home, then workspace switching, then the conversation timeline and composer.

**Tech Stack:** Flutter 3.41, Dart 3.11, `tdesign_flutter`, `flutter_test`, `shared_preferences`

---

### Task 1: Add TDesign Foundation and Workbench Theme Tokens

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/lib/app.dart`
- Create: `app/lib/src/theme/workbench_tokens.dart`
- Create: `app/lib/src/theme/workbench_theme.dart`
- Test: `app/test/app_theme_test.dart`

- [ ] **Step 1: Write the failing app theme test**

```dart
// app/test/app_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/app.dart';

void main() {
  testWidgets('wraps the app in the workbench theme with the warm background', (tester) async {
    await tester.pumpWidget(const AgentWorkbenchApp());

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.scaffoldBackgroundColor, const Color(0xFFF7F8FC));
    expect(find.text('Projects'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the theme test to verify the current shell fails**

Run: `cd app && flutter test test/app_theme_test.dart`  
Expected: FAIL because `scaffoldBackgroundColor` is not `Color(0xFFF7F8FC)` and there is no workbench theme layer

- [ ] **Step 3: Add `tdesign_flutter` and the product theme wrappers**

```yaml
# app/pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.2.2
  shared_preferences: ^2.3.2
  tdesign_flutter: ^0.2.7
  web_socket_channel: ^3.0.1
```

```dart
// app/lib/src/theme/workbench_tokens.dart
import 'package:flutter/material.dart';

class WorkbenchTokens {
  static const Color background = Color(0xFFF7F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primaryBlue = Color(0xFF276EF1);
  static const Color textPrimary = Color(0xFF1F2430);
  static const Color textSecondary = Color(0xFF667085);
  static const Color softBorder = Color(0xFFDCE3F1);
  static const Color running = Color(0xFF2F6BFF);
  static const Color waiting = Color(0xFFE3A93B);
  static const Color completed = Color(0xFF25B59B);
  static const Color failed = Color(0xFFE56A6A);

  static const double pagePadding = 20;
  static const double cardRadius = 24;
  static const double chipRadius = 18;
}
```

```dart
// app/lib/src/theme/workbench_theme.dart
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import 'workbench_tokens.dart';

ThemeData buildWorkbenchMaterialTheme() {
  return ThemeData(
    scaffoldBackgroundColor: WorkbenchTokens.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: WorkbenchTokens.primaryBlue,
      surface: WorkbenchTokens.surface,
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: WorkbenchTokens.textPrimary),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: WorkbenchTokens.textPrimary),
      bodyMedium: TextStyle(fontSize: 15, color: WorkbenchTokens.textPrimary),
      bodySmall: TextStyle(fontSize: 13, color: WorkbenchTokens.textSecondary),
    ),
  );
}

class WorkbenchTheme extends StatelessWidget {
  const WorkbenchTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TDTheme(
      data: TDTheme.defaultData(),
      systemData: buildWorkbenchMaterialTheme(),
      child: child,
    );
  }
}
```

```dart
// app/lib/app.dart
import 'package:flutter/material.dart';
import 'src/features/projects/project_home_screen.dart';
import 'src/theme/workbench_theme.dart';

class AgentWorkbenchApp extends StatelessWidget {
  const AgentWorkbenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkbenchTheme(
      child: MaterialApp(
        title: 'Agent Workbench',
        theme: buildWorkbenchMaterialTheme(),
        home: const ProjectHomeScreen(),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the app theme test**

Run: `cd app && flutter test test/app_theme_test.dart`  
Expected: PASS with `wraps the app in the workbench theme with the warm background`

- [ ] **Step 5: Commit the TDesign/theme foundation**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/app.dart app/lib/src/theme/workbench_tokens.dart app/lib/src/theme/workbench_theme.dart app/test/app_theme_test.dart
git commit -m "feat: add tdesign foundation and workbench theme"
```

### Task 2: Replace the Project List with Premium Project Cards

**Files:**
- Modify: `app/lib/src/models/project_summary.dart`
- Modify: `app/lib/src/data/api_client.dart`
- Modify: `app/lib/src/features/projects/project_home_screen.dart`
- Create: `app/lib/src/features/projects/project_card.dart`
- Test: `app/test/project_home_screen_test.dart`

- [ ] **Step 1: Write the failing project card test**

```dart
// app/test/project_home_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/app.dart';

void main() {
  testWidgets('shows the premium project cards with running counts and summaries', (tester) async {
    await tester.pumpWidget(const AgentWorkbenchApp());
    await tester.pumpAndSettle();

    expect(find.text('Your workspaces'), findsOneWidget);
    expect(find.text('2 conversations running'), findsOneWidget);
    expect(find.text('Pick up where you left off'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the project home test to verify the old list layout fails**

Run: `cd app && flutter test test/project_home_screen_test.dart`  
Expected: FAIL because the page still renders plain `ListTile`s and old copy

- [ ] **Step 3: Add project metadata and the premium card widget**

```dart
// app/lib/src/models/project_summary.dart
class ProjectSummary {
  const ProjectSummary({
    required this.id,
    required this.name,
    required this.path,
    required this.lastSummary,
    required this.runningConversationCount,
    this.pinned = false,
  });

  final String id;
  final String name;
  final String path;
  final String lastSummary;
  final int runningConversationCount;
  final bool pinned;
}
```

```dart
// app/lib/src/data/api_client.dart
const List<ProjectSummary> seededProjects = [
  ProjectSummary(
    id: '/Users/rex/code/alpha-api',
    name: 'alpha-api',
    path: '~/code/alpha-api',
    lastSummary: 'Billing callback thread needs your review.',
    runningConversationCount: 2,
    pinned: true,
  ),
  ProjectSummary(
    id: '/Users/rex/code/beta-admin',
    name: 'beta-admin',
    path: '~/code/beta-admin',
    lastSummary: 'No active conversations right now.',
    runningConversationCount: 0,
  ),
];
```

```dart
// app/lib/src/features/projects/project_card.dart
import 'package:flutter/material.dart';
import '../../models/project_summary.dart';
import '../../theme/workbench_tokens.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
  });

  final ProjectSummary project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: WorkbenchTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WorkbenchTokens.cardRadius),
        side: const BorderSide(color: WorkbenchTokens.softBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(WorkbenchTokens.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(project.lastSummary, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Text(
                project.runningConversationCount == 1
                    ? '1 conversation running'
                    : '${project.runningConversationCount} conversations running',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

```dart
// app/lib/src/features/projects/project_home_screen.dart
import 'package:flutter/material.dart';
import '../../data/api_client.dart';
import '../../models/project_summary.dart';
import '../../theme/workbench_tokens.dart';
import '../workspace/workspace_screen.dart';
import 'project_card.dart';

class ProjectHomeScreen extends StatelessWidget {
  const ProjectHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = ApiClient();
    return FutureBuilder<List<ProjectSummary>>(
      future: client.fetchProjects(),
      initialData: seededProjects,
      builder: (context, snapshot) {
        final projects = snapshot.data ?? const <ProjectSummary>[];
        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(WorkbenchTokens.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your workspaces', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text('Pick up where you left off', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      itemCount: projects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final project = projects[index];
                        return ProjectCard(
                          project: project,
                          onTap: () async {
                            final conversations = await client.fetchConversations(project.id);
                            if (!context.mounted) return;
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => WorkspaceScreen(
                                projectName: project.name,
                                conversations: conversations,
                              ),
                            ));
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run the project home test**

Run: `cd app && flutter test test/project_home_screen_test.dart`  
Expected: PASS with `shows the premium project cards with running counts and summaries`

- [ ] **Step 5: Commit the project home redesign**

```bash
git add app/lib/src/models/project_summary.dart app/lib/src/data/api_client.dart app/lib/src/features/projects/project_home_screen.dart app/lib/src/features/projects/project_card.dart app/test/project_home_screen_test.dart
git commit -m "feat: redesign project home with premium cards"
```

### Task 3: Rebuild the Project Workspace Around Conversation Strip Items

**Files:**
- Modify: `app/lib/src/models/conversation_summary.dart`
- Modify: `app/lib/src/data/api_client.dart`
- Modify: `app/lib/src/features/workspace/workspace_screen.dart`
- Modify: `app/lib/src/features/workspace/conversation_strip.dart`
- Create: `app/lib/src/features/workspace/conversation_state_badge.dart`
- Create: `app/lib/src/features/workspace/conversation_strip_item.dart`
- Test: `app/test/workspace_screen_test.dart`

- [ ] **Step 1: Write the failing workspace test**

```dart
// app/test/workspace_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/src/features/workspace/workspace_screen.dart';
import 'package:agent_workbench/src/models/conversation_summary.dart';

void main() {
  testWidgets('renders the workspace header, conversation strip, and new conversation button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScreen(
          projectName: 'alpha-api',
          conversations: const [
            ConversationSummary(
              id: 'c-1',
              title: 'Fix billing callback',
              status: 'running',
              lastMessagePreview: 'Reading billing_controller.dart',
            ),
          ],
        ),
      ),
    );

    expect(find.text('alpha-api'), findsOneWidget);
    expect(find.text('New conversation'), findsOneWidget);
    expect(find.text('Reading billing_controller.dart'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the workspace test to verify the current layout fails**

Run: `cd app && flutter test test/workspace_screen_test.dart`  
Expected: FAIL because there is no `New conversation` action and the strip items are still generic `Chip`s

- [ ] **Step 3: Add conversation strip wrappers and the workspace CTA**

```dart
// app/lib/src/features/workspace/conversation_state_badge.dart
import 'package:flutter/material.dart';
import '../../theme/workbench_tokens.dart';

class ConversationStateBadge extends StatelessWidget {
  const ConversationStateBadge(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'running' => WorkbenchTokens.running,
      'waiting_confirmation' => WorkbenchTokens.waiting,
      'completed' => WorkbenchTokens.completed,
      'failed' => WorkbenchTokens.failed,
      _ => WorkbenchTokens.textSecondary,
    };

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
```

```dart
// app/lib/src/features/workspace/conversation_strip_item.dart
import 'package:flutter/material.dart';
import '../../models/conversation_summary.dart';
import '../../theme/workbench_tokens.dart';
import 'conversation_state_badge.dart';

class ConversationStripItem extends StatelessWidget {
  const ConversationStripItem({
    super.key,
    required this.conversation,
  });

  final ConversationSummary conversation;

  @override
  Widget build(BuildContext context) {
    final initial = conversation.title.isEmpty ? '?' : conversation.title.characters.first;
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkbenchTokens.surface,
        borderRadius: BorderRadius.circular(WorkbenchTokens.chipRadius),
        border: Border.all(color: WorkbenchTokens.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(child: Text(initial)),
              const SizedBox(width: 10),
              Expanded(child: Text(conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ConversationStateBadge(conversation.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            conversation.lastMessagePreview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
```

```dart
// app/lib/src/features/workspace/conversation_strip.dart
import 'package:flutter/material.dart';
import '../../models/conversation_summary.dart';
import 'conversation_strip_item.dart';

class ConversationStrip extends StatelessWidget {
  const ConversationStrip({super.key, required this.conversations});

  final List<ConversationSummary> conversations;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: conversations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => ConversationStripItem(conversation: conversations[index]),
      ),
    );
  }
}
```

```dart
// app/lib/src/features/workspace/workspace_screen.dart
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../models/conversation_event.dart';
import '../../models/conversation_summary.dart';
import '../../theme/workbench_tokens.dart';
import '../conversation/conversation_screen.dart';
import 'conversation_strip.dart';

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({
    super.key,
    required this.projectName,
    required this.conversations,
  });

  final String projectName;
  final List<ConversationSummary> conversations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WorkbenchTokens.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(projectName, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              ConversationStrip(conversations: conversations),
              const SizedBox(height: 20),
              TDButton(
                text: 'New conversation',
                type: TDButtonType.fill,
                isBlock: true,
                onTap: () {},
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: conversations.map((conversation) {
                    return ListTile(
                      title: Text(conversation.lastMessagePreview),
                      trailing: Text(conversation.status),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ConversationScreen(
                            title: conversation.title,
                            events: const [
                              ConversationEvent.message(text: 'Look into the billing callback', role: 'user'),
                              ConversationEvent.action(label: 'Reading billing_controller.dart'),
                            ],
                            canConfirm: false,
                            canInterrupt: true,
                          ),
                        ));
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the workspace test**

Run: `cd app && flutter test test/workspace_screen_test.dart`  
Expected: PASS with `renders the workspace header, conversation strip, and new conversation button`

- [ ] **Step 5: Commit the workspace redesign**

```bash
git add app/lib/src/models/conversation_summary.dart app/lib/src/data/api_client.dart app/lib/src/features/workspace/workspace_screen.dart app/lib/src/features/workspace/conversation_strip.dart app/lib/src/features/workspace/conversation_state_badge.dart app/lib/src/features/workspace/conversation_strip_item.dart app/test/workspace_screen_test.dart
git commit -m "feat: redesign workspace conversation strip"
```

### Task 4: Rebuild the Conversation View with Product Cards and TDesign Controls

**Files:**
- Modify: `app/lib/src/features/conversation/conversation_screen.dart`
- Modify: `app/lib/src/features/conversation/conversation_timeline.dart`
- Modify: `app/lib/src/features/conversation/conversation_composer.dart`
- Create: `app/lib/src/features/conversation/message_card.dart`
- Create: `app/lib/src/features/conversation/action_card.dart`
- Create: `app/lib/src/features/conversation/error_card.dart`
- Test: `app/test/conversation_screen_test.dart`

- [ ] **Step 1: Write the failing conversation screen test**

```dart
// app/test/conversation_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_workbench/src/features/conversation/conversation_screen.dart';
import 'package:agent_workbench/src/models/conversation_event.dart';

void main() {
  testWidgets('shows product cards and the tdesign composer actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ConversationScreen(
          title: 'Fix billing callback',
          events: const [
            ConversationEvent.message(text: 'Start with the callback path', role: 'user'),
            ConversationEvent.action(label: 'Reading billing_controller.dart'),
            ConversationEvent.error(message: 'API unavailable'),
          ],
          canConfirm: true,
          canInterrupt: true,
        ),
      ),
    );

    expect(find.text('Reading billing_controller.dart'), findsOneWidget);
    expect(find.text('API unavailable'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Interrupt'), findsOneWidget);
    expect(find.text('Continue the conversation'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the conversation screen test to verify the current generic cards fail**

Run: `cd app && flutter test test/conversation_screen_test.dart`  
Expected: FAIL because the conversation view still uses generic `Card`, `ListTile`, and plain `TextField`

- [ ] **Step 3: Add product card widgets and the TDesign composer**

```dart
// app/lib/src/features/conversation/action_card.dart
import 'package:flutter/material.dart';
import '../../theme/workbench_tokens.dart';

class ActionCard extends StatelessWidget {
  const ActionCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WorkbenchTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WorkbenchTokens.softBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings_suggest, color: WorkbenchTokens.running),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
```

```dart
// app/lib/src/features/conversation/error_card.dart
import 'package:flutter/material.dart';

class ErrorCard extends StatelessWidget {
  const ErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE56A6A)),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
```

```dart
// app/lib/src/features/conversation/message_card.dart
import 'package:flutter/material.dart';
import '../../theme/workbench_tokens.dart';

class MessageCard extends StatelessWidget {
  const MessageCard({
    super.key,
    required this.text,
    required this.role,
  });

  final String text;
  final String role;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFEAF1FF) : WorkbenchTokens.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: WorkbenchTokens.softBorder),
        ),
        child: Text(text),
      ),
    );
  }
}
```

```dart
// app/lib/src/features/conversation/conversation_timeline.dart
import 'package:flutter/material.dart';
import '../../models/conversation_event.dart';
import 'action_card.dart';
import 'error_card.dart';
import 'message_card.dart';

class ConversationTimeline extends StatelessWidget {
  const ConversationTimeline({super.key, required this.events});

  final List<ConversationEvent> events;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        if (event.kind == 'action') return ActionCard(label: event.label!);
        if (event.kind == 'error') return ErrorCard(message: event.message!);
        return MessageCard(text: event.text!, role: event.role!);
      },
    );
  }
}
```

```dart
// app/lib/src/features/conversation/conversation_composer.dart
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

class ConversationComposer extends StatelessWidget {
  const ConversationComposer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TDInput(
            hintText: 'Continue the conversation',
            showBottomDivider: false,
            needClear: true,
          ),
          const SizedBox(height: 12),
          TDButton(
            text: 'Send',
            type: TDButtonType.fill,
            isBlock: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
```

```dart
// app/lib/src/features/conversation/conversation_screen.dart
import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../models/conversation_event.dart';
import 'conversation_composer.dart';
import 'conversation_timeline.dart';

class ConversationScreen extends StatelessWidget {
  const ConversationScreen({
    super.key,
    required this.title,
    required this.events,
    required this.canConfirm,
    required this.canInterrupt,
  });

  final String title;
  final List<ConversationEvent> events;
  final bool canConfirm;
  final bool canInterrupt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(child: ConversationTimeline(events: events)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (canConfirm)
                  Expanded(
                    child: TDButton(
                      text: 'Confirm',
                      type: TDButtonType.fill,
                      onTap: () {},
                    ),
                  ),
                if (canConfirm && canInterrupt) const SizedBox(width: 12),
                if (canInterrupt)
                  Expanded(
                    child: TDButton(
                      text: 'Interrupt',
                      type: TDButtonType.outline,
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          ),
          const ConversationComposer(),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the full Flutter UI suite**

Run: `cd app && flutter test`  
Expected: PASS with all app tests green

- [ ] **Step 5: Commit the conversation UI redesign**

```bash
git add app/lib/src/features/conversation/conversation_screen.dart app/lib/src/features/conversation/conversation_timeline.dart app/lib/src/features/conversation/conversation_composer.dart app/lib/src/features/conversation/message_card.dart app/lib/src/features/conversation/action_card.dart app/lib/src/features/conversation/error_card.dart app/test/conversation_screen_test.dart
git commit -m "feat: redesign conversation timeline with workbench cards"
```

### Task 5: Polish Copy and Status Presentation Across Screens

**Files:**
- Modify: `app/lib/src/data/api_client.dart`
- Modify: `app/lib/src/features/projects/project_card.dart`
- Modify: `app/lib/src/features/workspace/conversation_state_badge.dart`
- Modify: `app/lib/src/features/conversation/error_card.dart`
- Test: `app/test/project_home_screen_test.dart`
- Test: `app/test/workspace_screen_test.dart`
- Test: `app/test/conversation_screen_test.dart`

- [ ] **Step 1: Write the failing copy/state assertions**

```dart
// app/test/project_home_screen_test.dart
expect(find.text('Pick up where you left off'), findsOneWidget);

// app/test/workspace_screen_test.dart
expect(find.text('Running'), findsWidgets);

// app/test/conversation_screen_test.dart
expect(find.text('The model provider could not be reached right now.'), findsOneWidget);
```

- [ ] **Step 2: Run the focused UI tests**

Run: `cd app && flutter test test/project_home_screen_test.dart test/workspace_screen_test.dart test/conversation_screen_test.dart`  
Expected: FAIL because the state copy and error secondary text are not yet present

- [ ] **Step 3: Add final copy polish**

```dart
// app/lib/src/features/conversation/error_card.dart
class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    required this.message,
    this.detail = 'The model provider could not be reached right now.',
  });

  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(detail),
        ],
      ),
    );
  }
}
```

```dart
// app/lib/src/features/workspace/conversation_state_badge.dart
class ConversationStateBadge extends StatelessWidget {
  const ConversationStateBadge(this.status, {super.key});

  final String status;

  String get label => switch (status) {
    'running' => 'Running',
    'waiting_confirmation' => 'Waiting',
    'completed' => 'Done',
    'failed' => 'Failed',
    _ => 'Idle',
  };

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'running' => WorkbenchTokens.running,
      'waiting_confirmation' => WorkbenchTokens.waiting,
      'completed' => WorkbenchTokens.completed,
      'failed' => WorkbenchTokens.failed,
      _ => WorkbenchTokens.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the focused UI tests again**

Run: `cd app && flutter test test/project_home_screen_test.dart test/workspace_screen_test.dart test/conversation_screen_test.dart`  
Expected: PASS with the final copy/state assertions green

- [ ] **Step 5: Commit the UI polish**

```bash
git add app/lib/src/data/api_client.dart app/lib/src/features/projects/project_card.dart app/lib/src/features/workspace/conversation_state_badge.dart app/lib/src/features/conversation/error_card.dart app/test/project_home_screen_test.dart app/test/workspace_screen_test.dart app/test/conversation_screen_test.dart
git commit -m "feat: polish workbench copy and status presentation"
```
