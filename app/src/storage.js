'use strict';
function createStorage({ bucket, region }) {
  if (!bucket) return null;
  const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
  const s3 = new S3Client({ region });
  return {
    // Writes then reads a tiny object to prove the instance role can reach the app bucket.
    async check(instanceId) {
      const key = `healthchecks/${instanceId}.json`;
      const body = JSON.stringify({ at: new Date().toISOString() });
      await s3.send(new PutObjectCommand({ Bucket: bucket, Key: key, Body: body, ContentType: 'application/json' }));
      const got = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
      const text = await got.Body.transformToString();
      return { bucket, key, bytes: text.length };
    },
  };
}
module.exports = { createStorage };
