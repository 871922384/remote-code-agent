import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/conversation_event.dart';
import '../models/conversation_summary.dart';
import '../models/project_summary.dart';
import '../models/realtime_event.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => 'ApiException: $message';
}

class ApiClient {
  static Uri get defaultBaseUri => Uri.parse(
        const String.fromEnvironment(
          'AGENT_DAEMON_BASE_URL',
          defaultValue: 'http://127.0.0.1:3333',
        ),
      );

  ApiClient({
    Uri? baseUri,
    http.Client? httpClient,
    WebSocketChannel Function(Uri uri)? webSocketFactory,
  })  : baseUri = baseUri ?? defaultBaseUri,
        _httpClient = httpClient ?? http.Client(),
        _webSocketFactory = webSocketFactory ?? WebSocketChannel.connect;

  final Uri baseUri;
  final http.Client _httpClient;
  final WebSocketChannel Function(Uri uri) _webSocketFactory;

  Future<List<ProjectSummary>> fetchProjects() async {
    final json = await _getJson('/projects');
    final projects = (json['projects'] as List<dynamic>? ?? const []);
    return projects
        .map((project) =>
            ProjectSummary.fromJson(project as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<ConversationSummary>> fetchConversations(String projectId) async {
    final json = await _getJson(
      '/projects/${Uri.encodeComponent(projectId)}/conversations',
    );
    final conversations = (json['conversations'] as List<dynamic>? ?? const []);
    return conversations
        .map((conversation) =>
            ConversationSummary.fromJson(conversation as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<ConversationEvent>> fetchConversationTimeline(
    String conversationId,
  ) async {
    final responses = await Future.wait([
      _getJson('/conversations/$conversationId/messages'),
      _getJson('/conversations/$conversationId/events'),
    ]);

    final messages = (responses[0]['messages'] as List<dynamic>? ?? const [])
        .map((message) => ConversationEvent.fromMessageJson(
              message as Map<String, dynamic>,
            ));
    final events = (responses[1]['events'] as List<dynamic>? ?? const [])
        .map((event) => ConversationEvent.fromRunEventJson(
              event as Map<String, dynamic>,
            ))
        .whereType<ConversationEvent>();

    final timeline = [...messages, ...events];
    timeline.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return timeline;
  }

  Future<ConversationSummary> createConversation({
    required String projectId,
    required String title,
    required String openingMessage,
  }) async {
    final json = await _postJson(
      '/projects/${Uri.encodeComponent(projectId)}/conversations',
      body: {
        'title': title,
        'openingMessage': openingMessage,
      },
    );
    return ConversationSummary.fromJson(
      json['conversation'] as Map<String, dynamic>,
    );
  }

  Future<void> appendUserMessage({
    required String conversationId,
    required String text,
  }) async {
    await _postJson(
      '/conversations/$conversationId/messages',
      body: {'text': text},
    );
  }

  Future<String?> startRun({
    required String conversationId,
    required String cwd,
    required String prompt,
  }) async {
    final json = await _postJson(
      '/conversations/$conversationId/runs',
      body: {
        'cwd': cwd,
        'prompt': prompt,
      },
    );
    final run = json['run'] as Map<String, dynamic>?;
    return run?['id'] as String?;
  }

  Future<void> interruptRun(String runId) async {
    await _postJson('/runs/$runId/interrupt', body: const {});
  }

  Future<bool> checkHealth() async {
    final json = await _getJson('/health');
    return json['ok'] == true;
  }

  Stream<RealtimeEvent> watchEvents() async* {
    final channel = _webSocketFactory(_webSocketUri());
    try {
      await for (final raw in channel.stream) {
        final json = jsonDecode(raw as String) as Map<String, dynamic>;
        yield RealtimeEvent.fromJson(json);
      }
    } finally {
      await channel.sink.close();
    }
  }

  Uri _webSocketUri() {
    final scheme = switch (baseUri.scheme) {
      'https' => 'wss',
      _ => 'ws',
    };
    return baseUri.replace(
      scheme: scheme,
      path: '/ws',
      query: null,
      fragment: null,
    );
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _httpClient.get(_resolve(path));
    return _decodeJson(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _httpClient.post(
      _resolve(path),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeJson(response);
  }

  Uri _resolve(String path) {
    return baseUri.replace(
      path: path,
      query: null,
      fragment: null,
    );
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Request failed with status ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const ApiException('Expected a JSON object response.');
    }
    return json;
  }
}
