const { WebSocketServer } = require('ws');
const { URL } = require('node:url');

function attachWebSocketServer(server, eventBroker, { authToken = null } = {}) {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (request, socket, head) => {
    const url = new URL(request.url, 'http://127.0.0.1');
    if (url.pathname !== '/ws') {
      return;
    }

    const token = url.searchParams.get('token');
    if (authToken && token !== authToken) {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }

    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request);
    });
  });

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
