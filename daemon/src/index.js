require('dotenv').config();
const { createApp } = require('./http/app');
const { loadConfig } = require('./config');

const config = loadConfig();
const app = createApp();

app.listen(config.port, config.host, () => {
  console.log(`[daemon] listening on http://${config.host}:${config.port}`);
});
