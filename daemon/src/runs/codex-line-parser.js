function parseCodexLine(line) {
  const payload = JSON.parse(line);
  if (payload.type === 'assistant') {
    return { kind: 'message.created', payload: { role: 'assistant', text: payload.text } };
  }
  if (payload.type === 'action') {
    return { kind: 'run.action', payload: { label: payload.name } };
  }
  if (payload.type === 'error') {
    return { kind: 'run.error', payload: { message: payload.message } };
  }
  return { kind: 'run.chunk', payload };
}

module.exports = {
  parseCodexLine,
};
