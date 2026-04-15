const test = require('node:test');
const assert = require('node:assert/strict');
const { EventBroker } = require('../src/realtime/event-broker');

test('event broker replays published events to subscribers', async () => {
  const broker = new EventBroker();
  const seen = [];
  const unsubscribe = broker.subscribe((event) => {
    seen.push(event);
  });

  broker.publish({ kind: 'run.started', runId: 'run-1' });
  broker.publish({ kind: 'run.action', runId: 'run-1', payload: { label: 'reading files' } });
  unsubscribe();

  assert.deepEqual(seen, [
    { kind: 'run.started', runId: 'run-1' },
    { kind: 'run.action', runId: 'run-1', payload: { label: 'reading files' } },
  ]);
});
