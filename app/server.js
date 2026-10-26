'use strict';
const { loadConfig } = require('./src/config');
const { createDb } = require('./src/db');
const { createApp } = require('./src/app');
const { createStorage } = require('./src/storage');
const { getInstanceId } = require('./src/metadata');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const config = await loadConfig();
  const db = createDb(config.db);
  const storage = createStorage({ bucket: config.bucket, region: config.region });
  const instanceId = await getInstanceId();
  const state = { ready: false };

  // Listen immediately so the ALB health check passes while the DB initialises.
  const server = createApp({ config, db, storage, instanceId, state }).listen(config.port, () =>
    console.log(JSON.stringify({ level: 'info', msg: 'listening', port: config.port, color: config.color, version: config.version }))
  );

  (async () => {
    for (let attempt = 1; ; attempt++) {
      try {
        await db.init();
        state.ready = true;
        console.log(JSON.stringify({ level: 'info', msg: 'database ready' }));
        return;
      } catch (e) {
        console.error(JSON.stringify({ level: 'warn', msg: 'database init failed', attempt, error: e.code || e.message }));
        await sleep(5000);
      }
    }
  })();

  const shutdown = () => server.close(async () => { await db.close().catch(() => {}); process.exit(0); });
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

main().catch((e) => { console.error(e); process.exit(1); });
