'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { createApp } = require('../src/app');

const db = {
  ping: async () => ({ primary: 'ok', replica: 'ok' }),
  listNotes: async () => [{ id: 1, title: 't', body: '' }],
  addNote: async () => 42,
};

async function withServer(state, fn) {
  const app = createApp({ config: { color: 'blue', version: 'test' }, db, storage: null, instanceId: 'i-test', state });
  const server = app.listen(0);
  try {
    await fn(`http://127.0.0.1:${server.address().port}`);
  } finally {
    server.close();
  }
}

test('GET /health returns ok', () =>
  withServer({ ready: true }, async (base) => {
    const res = await fetch(`${base}/health`);
    assert.strictEqual(res.status, 200);
  }));

test('GET /api/status reports colour, version and db state', () =>
  withServer({ ready: true }, async (base) => {
    const body = await (await fetch(`${base}/api/status`)).json();
    assert.strictEqual(body.status, 'ok');
    assert.strictEqual(body.color, 'blue');
    assert.strictEqual(body.version, 'test');
  }));

test('status is 503 until the database is ready', () =>
  withServer({ ready: false }, async (base) => {
    assert.strictEqual((await fetch(`${base}/api/status`)).status, 503);
  }));

test('POST /api/notes validates input and creates notes', () =>
  withServer({ ready: true }, async (base) => {
    const headers = { 'content-type': 'application/json' };
    const bad = await fetch(`${base}/api/notes`, { method: 'POST', headers, body: JSON.stringify({}) });
    assert.strictEqual(bad.status, 400);
    const ok = await fetch(`${base}/api/notes`, { method: 'POST', headers, body: JSON.stringify({ title: 'hello' }) });
    assert.strictEqual(ok.status, 201);
    assert.strictEqual((await ok.json()).id, 42);
  }));
