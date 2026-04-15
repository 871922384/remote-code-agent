const { WebSocketServer } = require('ws');

function attachWebSocketServer(server, eventBroker) {
  const wss = new WebSocketServer({ server, path: '/ws' });
  eventBroker.subscribe((event) => {
    const payload = JSON.stringify(event);
    for (const client of wss.clients) {
      if (client.readyState === 1) {
        client.send(payload);
      }
    }
  });
  return wss;
}

module.exports = {
  attachWebSocketServer,
};
