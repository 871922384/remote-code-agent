const express = require('express');

function createApp({ projectService, conversationService, runService } = {}) {
  const app = express();
  app.use(express.json({ limit: '1mb' }));
  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      product: 'android-agent-workbench-daemon',
      time: new Date().toISOString(),
    });
  });
  app.get('/projects', (_req, res) => {
    res.json({ projects: projectService ? projectService.listProjects() : [] });
  });
  app.get('/projects/:projectId/conversations', (req, res) => {
    res.json({
      conversations: conversationService ? conversationService.listConversations(req.params.projectId) : [],
    });
  });
  app.post('/projects/:projectId/conversations', (req, res) => {
    const conversation = conversationService.createConversation({
      projectId: req.params.projectId,
      title: req.body.title,
      openingMessage: req.body.openingMessage,
    });
    res.status(201).json({ conversation });
  });
  app.get('/conversations/:conversationId/messages', (req, res) => {
    res.json({
      messages: conversationService ? conversationService.listMessages(req.params.conversationId) : [],
    });
  });
  app.get('/conversations/:conversationId/events', (req, res) => {
    res.json({
      events: runService ? runService.listConversationEvents(req.params.conversationId) : [],
    });
  });
  app.post('/conversations/:conversationId/messages', (req, res) => {
    const message = conversationService.appendUserMessage({
      conversationId: req.params.conversationId,
      text: req.body.text,
    });
    res.status(201).json({ message });
  });
  app.post('/conversations/:conversationId/runs', async (req, res, next) => {
    try {
      const run = await runService.startRun({
        conversationId: req.params.conversationId,
        cwd: req.body.cwd,
        prompt: req.body.prompt,
      });
      res.status(201).json({ run });
    } catch (error) {
      next(error);
    }
  });
  app.post('/runs/:runId/interrupt', (req, res) => {
    const ok = runService ? runService.interruptRun(req.params.runId) : false;
    res.status(ok ? 200 : 404).json({ ok });
  });
  app.post('/runs/:runId/confirm', async (req, res) => {
    const result = runService ? await runService.confirmRun(req.params.runId) : { ok: false };
    res.status(result.ok ? 200 : 404).json(result);
  });
  return app;
}

module.exports = {
  createApp,
};
