const express = require('express');

function createApp() {
  const app = express();
  app.use(express.json({ limit: '1mb' }));
  app.get('/health', (_req, res) => {
    res.json({
      ok: true,
      product: 'android-agent-workbench-daemon',
      time: new Date().toISOString(),
    });
  });
  return app;
}

module.exports = {
  createApp,
};
