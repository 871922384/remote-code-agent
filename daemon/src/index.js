require('dotenv').config();
const { loadConfig } = require('./config');
const { openDatabase } = require('./db/open-db');
const { migrate } = require('./db/migrate');
const { createProjectService } = require('./projects/project-service');
const { createConversationService } = require('./conversations/conversation-service');
const { createRunService } = require('./runs/run-service');
const { EventBroker } = require('./realtime/event-broker');
const { attachWebSocketServer } = require('./realtime/ws-server');
const { createApp } = require('./http/app');

const config = loadConfig();
const db = openDatabase({ daemonDataDir: config.daemonDataDir });
migrate(db);

const eventBroker = new EventBroker();
const projectService = createProjectService({ workspaceRoot: config.workspaceRoot, db });
const conversationService = createConversationService({ db });
const runService = createRunService({ db, codexBin: config.codexBin, eventBroker });
const app = createApp({ projectService, conversationService, runService });

const server = app.listen(config.port, config.host, () => {
  console.log(`[daemon] listening on http://${config.host}:${config.port}`);
});

attachWebSocketServer(server, eventBroker);
