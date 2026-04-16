import 'dart:async';

import 'package:agent_workbench/src/data/api_client.dart';
import 'package:agent_workbench/src/logging/app_logger.dart';
import 'package:agent_workbench/src/models/conversation_event.dart';
import 'package:agent_workbench/src/models/conversation_summary.dart';
import 'package:agent_workbench/src/models/project_summary.dart';
import 'package:agent_workbench/src/models/realtime_event.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient({
    Uri? baseUri,
    String? authToken,
    this.projects = const [],
    this.conversations = const {},
    this.conversationsError,
    this.timelines = const {},
    this.healthOk = true,
    this.projectsError,
    Stream<RealtimeEvent>? events,
    this.healthCheckAuthToken,
    AppLogger? logger,
  })  : _events = events ?? const Stream.empty(),
        super(
          baseUri: baseUri ?? Uri.parse('http://127.0.0.1:3333'),
          authToken: authToken,
          logger: logger,
        );

  final List<ProjectSummary> projects;
  final Map<String, List<ConversationSummary>> conversations;
  final Object? conversationsError;
  final Map<String, List<ConversationEvent>> timelines;
  final Stream<RealtimeEvent> _events;
  final bool healthOk;
  final Object? projectsError;
  final String? healthCheckAuthToken;

  final List<String> appendedMessages = [];
  final List<String> startedPrompts = [];

  @override
  Future<List<ProjectSummary>> fetchProjects() async {
    if (projectsError != null) {
      throw projectsError!;
    }
    return projects;
  }

  @override
  Future<List<ConversationSummary>> fetchConversations(String projectId) async {
    if (conversationsError != null) {
      throw conversationsError!;
    }
    return conversations[projectId] ?? const [];
  }

  @override
  Future<List<ConversationEvent>> fetchConversationTimeline(
    String conversationId,
  ) async {
    return timelines[conversationId] ?? const [];
  }

  @override
  Future<ConversationSummary> createConversation({
    required String projectId,
    required String title,
    required String openingMessage,
  }) async {
    appendedMessages.add(openingMessage);
    return ConversationSummary(
      id: 'new-conversation',
      title: title,
      status: 'idle',
      lastMessagePreview: openingMessage,
      projectId: projectId,
    );
  }

  @override
  Future<void> appendUserMessage({
    required String conversationId,
    required String text,
  }) async {
    appendedMessages.add(text);
  }

  @override
  Future<String?> startRun({
    required String conversationId,
    required String cwd,
    required String prompt,
  }) async {
    startedPrompts.add(prompt);
    return 'run-1';
  }

  @override
  Stream<RealtimeEvent> watchEvents() => _events;

  @override
  Future<bool> checkHealth() async {
    if (healthCheckAuthToken != null && authToken != healthCheckAuthToken) {
      throw const ApiException('Unauthorized');
    }
    return healthOk;
  }
}
