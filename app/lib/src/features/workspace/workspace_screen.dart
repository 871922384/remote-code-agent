import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../app_scope.dart';
import '../../models/conversation_summary.dart';
import '../../theme/workbench_tokens.dart';
import '../conversation/conversation_screen.dart';
import 'conversation_state_badge.dart';
import 'conversation_strip.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.conversations = const [],
  });

  final String projectId;
  final String projectName;
  final List<ConversationSummary> conversations;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  List<ConversationSummary> _conversations = const [];
  bool _loading = true;
  bool _didLoad = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _conversations = widget.conversations;
    _loading = widget.conversations.isEmpty;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    WorkbenchScope.of(context).logger.info(
      'ui',
      'Loading recent activity for ${widget.projectName}',
      detailed: true,
    );
    try {
      final conversations =
          await WorkbenchScope.of(context).apiClient.fetchConversations(
                widget.projectId,
              );
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
      WorkbenchScope.of(context).logger.error(
        'ui',
        'Failed to load recent activity: $error',
      );
    }
  }

  Future<void> _openConversation({
    required String title,
    String? conversationId,
    String? activeRunId,
    bool requiresConfirmation = false,
  }) async {
    final scope = WorkbenchScope.of(context);
    scope.logger.info(
      'ui',
      conversationId == null
          ? 'Opening new conversation in ${widget.projectName}'
          : 'Opening conversation $conversationId',
      detailed: true,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkbenchScope(
          apiClient: scope.apiClient,
          logger: scope.logger,
          daemonConnection: scope.daemonConnection,
          updateDaemonConnection: scope.updateDaemonConnection,
          updateDetailedLogging: scope.updateDetailedLogging,
          apiClientFactory: scope.apiClientFactory,
          child: ConversationScreen(
            title: title,
            projectId: widget.projectId,
            conversationId: conversationId,
            canConfirm: requiresConfirmation,
            canInterrupt: activeRunId != null,
          ),
        ),
      ),
    );
    if (!mounted) return;
    await _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WorkbenchTokens.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.projectName,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Switch between active threads and keep the current run in view.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              ConversationStrip(
                conversations: _conversations,
                onTapConversation: (conversation) => _openConversation(
                  title: conversation.title,
                  conversationId: conversation.id,
                  activeRunId: conversation.activeRunId,
                  requiresConfirmation: conversation.requiresConfirmation,
                ),
              ),
              const SizedBox(height: 20),
              TDButton(
                text: 'New conversation',
                type: TDButtonType.fill,
                isBlock: true,
                onTap: () => _openConversation(title: 'New conversation'),
              ),
              const SizedBox(height: 20),
              Text(
                'Recent activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _loadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Couldn\'t load recent activity.',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _loadError!,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _loadError = null;
                                });
                                _loadConversations();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _conversations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final conversation = _conversations[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: WorkbenchTokens.surface,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: WorkbenchTokens.softBorder),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 8,
                              ),
                              title: Text(
                                conversation.lastMessagePreview,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child:
                                    ConversationStateBadge(conversation.status),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _openConversation(
                                title: conversation.title,
                                conversationId: conversation.id,
                                activeRunId: conversation.activeRunId,
                                requiresConfirmation:
                                    conversation.requiresConfirmation,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
