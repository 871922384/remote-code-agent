const express = require('express');

function createApp({ projectService } = {}) {
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
  return app;
}

module.exports = {
  createApp,
};
