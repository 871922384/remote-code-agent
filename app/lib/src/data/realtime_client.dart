import 'dart:async';
import '../models/conversation_event.dart';

class RealtimeClient {
  Stream<ConversationEvent> subscribe(String conversationId) async* {
    yield const ConversationEvent.action(label: 'reading files');
    yield const ConversationEvent.error(message: 'API unavailable');
  }
}
