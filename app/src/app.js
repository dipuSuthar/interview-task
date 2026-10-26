'use strict';
const express = require('express');

function createApp({ config, db, storage, instanceId, state }) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '10kb' }));
  app.use((req, res, next) => {
    res.set({
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'DENY',
      'Referrer-Policy': 'no-referrer',
    });
    next();
  });

  // Shallow liveness probe used by the ALB target group.
  app.get('/health', (req, res) => res.json({ status: 'ok' }));

  // Deep status used by deployment smoke tests.
  app.get('/api/status', async (req, res) => {
    const database = state.ready ? await db.ping() : { primary: 'initialising', replica: 'initialising' };
    const ok = state.ready && database.primary === 'ok' && database.replica === 'ok';
    res.status(ok ? 200 : 503).json({
      status: ok ? 'ok' : 'degraded',
      color: config.color,
      version: config.version,
      instance: instanceId,
      database,
      time: new Date().toISOString(),
    });
  });

  const requireReady = (req, res, next) =>
    state.ready ? next() : res.status(503).json({ error: 'service initialising' });

  app.get('/api/notes', requireReady, async (req, res, next) => {
    try {
      res.json(await db.listNotes());
    } catch (e) {
      next(e);
    }
  });

  app.post('/api/notes', requireReady, async (req, res, next) => {
    const { title, body = '' } = req.body || {};
    if (typeof title !== 'string' || !title.trim() || title.length > 120 || typeof body !== 'string' || body.length > 1000) {
      return res.status(400).json({ error: 'title (1-120 chars) required; body max 1000 chars' });
    }
    try {
      const id = await db.addNote(title.trim(), body);
      res.status(201).json({ id, title: title.trim(), body });
    } catch (e) {
      next(e);
    }
  });

  app.post('/api/storage/check', async (req, res, next) => {
    if (!storage) return res.status(501).json({ error: 'S3_BUCKET not configured' });
    try {
      res.json(await storage.check(instanceId));
    } catch (e) {
      next(e);
    }
  });

  app.get('/', (req, res) => {
    const bg = config.color === 'green' ? '#15803d' : config.color === 'blue' ? '#1d4ed8' : '#374151';
    res.type('html').send(`<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>DevOps Task</title>
<style>body{font-family:system-ui,sans-serif;margin:0;min-height:100vh;display:grid;place-items:center;background:${bg};color:#fff}
main{max-width:34rem;padding:2rem}code{background:rgba(255,255,255,.18);padding:.1rem .4rem;border-radius:4px}</style></head>
<body><main><h1>DevOps Practical Task</h1>
<p>Deployment colour: <strong>${config.color}</strong></p>
<p>Version: <code>${config.version}</code></p>
<p>Served by instance: <code>${instanceId}</code></p>
<p><a style="color:#fff" href="/api/status">/api/status</a> &middot; <a style="color:#fff" href="/api/notes">/api/notes</a></p>
</main></body></html>`);
  });

  app.use((req, res) => res.status(404).json({ error: 'not found' }));
  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error(JSON.stringify({ level: 'error', msg: err.message }));
    res.status(500).json({ error: 'internal error' });
  });
  return app;
}

module.exports = { createApp };
