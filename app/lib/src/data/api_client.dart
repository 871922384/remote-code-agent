import '../models/conversation_summary.dart';
import '../models/project_summary.dart';

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

const List<ConversationSummary> seededConversations = [
  ConversationSummary(
    id: 'c-1',
    title: 'Fix billing callback',
    status: 'running',
    lastMessagePreview: 'Reading billing_controller.dart',
  ),
];

class ApiClient {
  Future<List<ProjectSummary>> fetchProjects() async {
    return seededProjects;
  }

  Future<List<ConversationSummary>> fetchConversations(String projectId) async {
    return seededConversations;
  }
}
