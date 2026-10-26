'use strict';
const fs = require('fs');

async function loadDbConfig(env) {
  let db;
  if (env.DB_SECRET_ID) {
    // Production path: credentials come from AWS Secrets Manager via the instance role.
    const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
    const client = new SecretsManagerClient({ region: env.AWS_REGION });
    const res = await client.send(new GetSecretValueCommand({ SecretId: env.DB_SECRET_ID }));
    const s = JSON.parse(res.SecretString);
    db = {
      host: s.host,
      readHost: s.read_host || s.host,
      port: Number(s.port || 3306),
      user: s.username,
      password: s.password,
      database: s.dbname,
    };
  } else {
    // Local development path (docker-compose).
    db = {
      host: env.DB_HOST || '127.0.0.1',
      readHost: env.DB_READ_HOST || env.DB_HOST || '127.0.0.1',
      port: Number(env.DB_PORT || 3306),
      user: env.DB_USER || 'app',
      password: env.DB_PASSWORD || 'app',
      database: env.DB_NAME || 'appdb',
    };
  }
  if (env.DB_SSL_CA && fs.existsSync(env.DB_SSL_CA)) {
    db.ssl = { ca: fs.readFileSync(env.DB_SSL_CA, 'utf8'), rejectUnauthorized: true };
  }
  return db;
}

async function loadConfig(env = process.env) {
  return {
    port: Number(env.PORT || 3000),
    color: env.APP_COLOR || 'local',
    version: env.APP_VERSION || 'dev',
    region: env.AWS_REGION || 'ap-south-1',
    bucket: env.S3_BUCKET || '',
    db: await loadDbConfig(env),
  };
}

module.exports = { loadConfig };
