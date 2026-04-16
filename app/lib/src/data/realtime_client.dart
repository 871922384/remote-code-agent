import 'dart:async';
import '../models/conversation_event.dart';

class RealtimeClient {
  Stream<ConversationEvent> subscribe(String conversationId) async* {
    yield ConversationEvent.action(label: 'reading files');
    yield ConversationEvent.error(message: 'API unavailable');
  }
}
