import 'dart:convert';

import 'package:agent_workbench/src/data/api_client.dart';
import 'package:agent_workbench/src/logging/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('defaultBaseUri uses the Android emulator host bridge', () {
    expect(
      ApiClient.defaultBaseUri,
      Uri.parse('http://10.0.2.2:3333'),
    );
  });

  test('fetchProjects maps daemon project payloads into project summaries',
      () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://127.0.0.1:3333'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/projects');
        return http.Response(
          jsonEncode({
            'projects': [
              {
                'id': '/Users/rex/code/alpha-api',
                'name': 'alpha-api',
                'path': '/Users/rex/code/alpha-api',
                'pinned': true,
                'runningConversationCount': 2,
                'lastSummary': 'Reading billing_controller.dart',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final projects = await client.fetchProjects();

    expect(projects, hasLength(1));
    expect(projects.first.name, 'alpha-api');
    expect(projects.first.path, '/Users/rex/code/alpha-api');
    expect(projects.first.runningConversationCount, 2);
    expect(projects.first.lastSummary, 'Reading billing_controller.dart');
    expect(projects.first.pinned, isTrue);
  });

  test(
      'fetchConversationTimeline merges messages and run events in timestamp order',
      () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://127.0.0.1:3333'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/conversations/conv-1/messages') {
          return http.Response(
            jsonEncode({
              'messages': [
                {
                  'id': 'msg-1',
                  'conversationId': 'conv-1',
                  'role': 'user',
                  'text': 'Start with the callback path',
                  'createdAt': '2026-04-16T10:00:00.000Z',
                },
                {
                  'id': 'msg-2',
                  'conversationId': 'conv-1',
                  'role': 'assistant',
                  'text': 'I found the billing controller.',
                  'createdAt': '2026-04-16T10:00:02.000Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path == '/conversations/conv-1/events') {
          return http.Response(
            jsonEncode({
              'events': [
                {
                  'kind': 'run.action',
                  'payload': {'label': 'Reading billing_controller.dart'},
                  'createdAt': '2026-04-16T10:00:01.000Z',
                },
                {
                  'kind': 'run.error',
                  'payload': {'message': 'API unavailable'},
                  'createdAt': '2026-04-16T10:00:03.000Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        throw StateError('Unexpected path: ${request.url.path}');
      }),
    );

    final timeline = await client.fetchConversationTimeline('conv-1');

    expect(timeline, hasLength(4));
    expect(timeline[0].kind, 'message');
    expect(timeline[0].text, 'Start with the callback path');
    expect(timeline[1].kind, 'action');
    expect(timeline[1].label, 'Reading billing_controller.dart');
    expect(timeline[2].kind, 'message');
    expect(timeline[2].text, 'I found the billing controller.');
    expect(timeline[3].kind, 'error');
    expect(timeline[3].message, 'API unavailable');
  });

  test('checkHealth returns true when the daemon health endpoint is ok',
      () async {
    final client = ApiClient(
      baseUri: Uri.parse('http://127.0.0.1:3333'),
      authToken: 'top-secret',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/health');
        expect(request.headers['authorization'], 'Bearer top-secret');
        return http.Response(
          jsonEncode({
            'ok': true,
            'product': 'android-agent-workbench-daemon',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final ok = await client.checkHealth();

    expect(ok, isTrue);
  });

  test('checkHealth writes detailed network logs without exposing the token',
      () async {
    final logger = AppLogger(detailedLoggingEnabled: true);
    final client = ApiClient(
      baseUri: Uri.parse('http://127.0.0.1:3333'),
      authToken: 'top-secret',
      logger: logger,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await client.checkHealth();

    final text = logger.formatVisibleLogs();
    expect(text, contains('GET /health (auth: bearer)'));
    expect(text, contains('GET /health -> 200'));
    expect(text, isNot(contains('top-secret')));
  });

  test('watchEvents appends the auth token to the websocket url', () async {
    late Uri capturedUri;
    final client = ApiClient(
      baseUri: Uri.parse('https://daemon.example.com:3333'),
      authToken: 'ws-secret',
      webSocketFactory: (uri) {
        capturedUri = uri;
        throw StateError('stop after capturing websocket uri');
      },
    );

    await expectLater(
      client.watchEvents(),
      emitsError(isA<StateError>()),
    );

    expect(capturedUri.scheme, 'wss');
    expect(capturedUri.host, 'daemon.example.com');
    expect(capturedUri.path, '/ws');
    expect(capturedUri.queryParameters['token'], 'ws-secret');
  });
}
