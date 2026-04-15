import '../models/conversation_summary.dart';
import '../models/project_summary.dart';

const List<ProjectSummary> seededProjects = [
  ProjectSummary(
    id: '/Users/rex/code/alpha-api',
    name: 'alpha-api',
    path: '~/code/alpha-api',
    pinned: true,
  ),
  ProjectSummary(
    id: '/Users/rex/code/beta-admin',
    name: 'beta-admin',
    path: '~/code/beta-admin',
  ),
];

const List<ConversationSummary> seededConversations = [
  ConversationSummary(
    id: 'c-1',
    title: '修复支付回调',
    status: 'running',
    lastMessagePreview: '正在检查 controller',
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
