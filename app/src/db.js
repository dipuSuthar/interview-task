'use strict';
const mysql = require('mysql2/promise');

function makePool(host, cfg) {
  return mysql.createPool({
    host,
    port: cfg.port,
    user: cfg.user,
    password: cfg.password,
    database: cfg.database,
    ssl: cfg.ssl,
    waitForConnections: true,
    connectionLimit: 10,
    connectTimeout: 10000,
  });
}

function createDb(cfg) {
  const writer = makePool(cfg.host, cfg);
  const reader = cfg.readHost === cfg.host ? writer : makePool(cfg.readHost, cfg);

  async function check(pool) {
    try {
      await pool.query('SELECT 1');
      return 'ok';
    } catch (e) {
      return `error: ${e.code || e.message}`;
    }
  }

  return {
    async init() {
      await writer.query(`CREATE TABLE IF NOT EXISTS notes (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        title VARCHAR(120) NOT NULL,
        body VARCHAR(1000) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )`);
    },
    async ping() {
      return { primary: await check(writer), replica: await check(reader) };
    },
    async listNotes(limit = 50) {
      const [rows] = await reader.query(
        'SELECT id, title, body, created_at FROM notes ORDER BY id DESC LIMIT ?',
        [limit]
      );
      return rows;
    },
    async addNote(title, body) {
      const [res] = await writer.execute('INSERT INTO notes (title, body) VALUES (?, ?)', [title, body]);
      return res.insertId;
    },
    async close() {
      await writer.end();
      if (reader !== writer) await reader.end();
    },
  };
}

module.exports = { createDb };
