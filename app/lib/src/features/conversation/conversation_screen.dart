import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

import '../../app_scope.dart';
import '../../models/conversation_event.dart';
import '../../models/realtime_event.dart';
import 'conversation_composer.dart';
import 'conversation_timeline.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.title,
    required this.projectId,
    this.conversationId,
    this.events = const [],
    this.canConfirm = false,
    this.canInterrupt = false,
  });

  final String title;
  final String projectId;
  final String? conversationId;
  final List<ConversationEvent> events;
  final bool canConfirm;
  final bool canInterrupt;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _controller = TextEditingController();

  StreamSubscription<RealtimeEvent>? _eventsSubscription;
  List<ConversationEvent> _events = const [];
  String? _conversationId;
  String? _activeRunId;
  bool _canConfirm = false;
  bool _canInterrupt = false;
  bool _loading = true;
  bool _sending = false;
  bool _didLoad = false;
  late String _title;

  @override
  void initState() {
    super.initState();
    _events = widget.events;
    _conversationId = widget.conversationId;
    _canConfirm = widget.canConfirm;
    _canInterrupt = widget.canInterrupt;
    _loading = widget.conversationId != null && widget.events.isEmpty;
    _title = widget.title;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _eventsSubscription = WorkbenchScope.of(context)
        .apiClient
        .watchEvents()
        .listen(
          _handleRealtimeEvent,
          onError: _handleRealtimeError,
        );
    if (_conversationId != null) {
      _loadTimeline();
    }
  }

  Future<void> _loadTimeline() async {
    final conversationId = _conversationId;
    if (conversationId == null) return;
    final timeline = await WorkbenchScope.of(context)
        .apiClient
        .fetchConversationTimeline(conversationId);
    if (!mounted) return;
    setState(() {
      _events = timeline;
      _loading = false;
    });
  }

  void _handleRealtimeEvent(RealtimeEvent event) {
    if (_conversationId == null || event.conversationId != _conversationId) {
      return;
    }

    WorkbenchScope.of(context).logger.debug(
      'realtime',
      'Received ${event.kind} for ${event.conversationId}',
    );
    setState(() {
      switch (event.kind) {
        case 'run.started':
          _activeRunId = event.runId;
          _canInterrupt = true;
          _canConfirm = false;
          break;
        case 'run.completed':
        case 'run.interrupted':
        case 'run.failed':
          _activeRunId = null;
          _canInterrupt = false;
          _canConfirm = false;
          break;
        case 'run.waiting_confirmation':
          _activeRunId = event.runId;
          _canConfirm = true;
          _canInterrupt = false;
          break;
        default:
          final timelineEvent = ConversationEvent.fromRunEventJson({
            'kind': event.kind,
            'payload': event.payload,
            'createdAt': event.createdAt.toIso8601String(),
          });
          if (timelineEvent != null) {
            _events = [..._events, timelineEvent];
          }
      }
    });
  }

  void _handleRealtimeError(Object error, StackTrace stackTrace) {
    WorkbenchScope.of(context).logger.error(
      'realtime',
      'Realtime subscription failed: $error',
    );
    if (!mounted) return;
    setState(() {
      _events = [
        ..._events,
        ConversationEvent.error(
          message: error.toString(),
          createdAt: DateTime.now().toUtc(),
        ),
      ];
    });
  }

  String _buildTitle(String text) {
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 48) return collapsed;
    return '${collapsed.substring(0, 45)}...';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final now = DateTime.now().toUtc();
    setState(() {
      _sending = true;
      _events = [
        ..._events,
        ConversationEvent.message(
          text: text,
          role: 'user',
          createdAt: now,
        ),
      ];
      _controller.clear();
      _loading = false;
    });

    try {
      WorkbenchScope.of(context).logger.info(
        'ui',
        'Sending message in ${widget.projectId}',
        detailed: true,
      );
      var conversationId = _conversationId;
      if (conversationId == null) {
        final created =
            await WorkbenchScope.of(context).apiClient.createConversation(
                  projectId: widget.projectId,
                  title: _buildTitle(text),
                  openingMessage: text,
                );
        conversationId = created.id;
        _conversationId = created.id;
        _title = created.title;
      } else {
        await WorkbenchScope.of(context).apiClient.appendUserMessage(
              conversationId: conversationId,
              text: text,
            );
      }

      final runId = await WorkbenchScope.of(context).apiClient.startRun(
            conversationId: conversationId,
            cwd: widget.projectId,
            prompt: text,
          );

      if (!mounted) return;
      setState(() {
        _activeRunId = runId;
        _canInterrupt = runId != null;
      });
    } catch (error) {
      WorkbenchScope.of(context).logger.error(
        'ui',
        'Failed to send message: $error',
      );
      if (!mounted) return;
      setState(() {
        _events = [
          ..._events,
          ConversationEvent.error(
            message: error.toString(),
            createdAt: DateTime.now().toUtc(),
          ),
        ];
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _sending = false;
      });
    }
  }

  Future<void> _interruptRun() async {
    final runId = _activeRunId;
    if (runId == null) return;
    WorkbenchScope.of(context).logger.info(
      'ui',
      'Interrupting run $runId',
      detailed: true,
    );
    await WorkbenchScope.of(context).apiClient.interruptRun(runId);
    if (!mounted) return;
    setState(() {
      _activeRunId = null;
      _canInterrupt = false;
      _canConfirm = false;
    });
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ConversationTimeline(events: _events),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (_canConfirm)
                  Expanded(
                    child: TDButton(
                      text: 'Confirm',
                      type: TDButtonType.fill,
                      onTap: () {},
                    ),
                  ),
                if (_canConfirm && _canInterrupt) const SizedBox(width: 12),
                if (_canInterrupt)
                  Expanded(
                    child: TDButton(
                      text: 'Interrupt',
                      type: TDButtonType.outline,
                      onTap: _interruptRun,
                    ),
                  ),
              ],
            ),
          ),
          ConversationComposer(
            controller: _controller,
            onSend: _sendMessage,
            isSending: _sending,
          ),
        ],
      ),
    );
  }
}
