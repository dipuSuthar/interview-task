'use strict';
// IMDSv2 lookup of the EC2 instance id. Returns "local" when not on EC2.
async function getInstanceId() {
  try {
    const token = await fetch('http://169.254.169.254/latest/api/token', {
      method: 'PUT',
      headers: { 'X-aws-ec2-metadata-token-ttl-seconds': '300' },
      signal: AbortSignal.timeout(1000),
    }).then((r) => r.text());
    return await fetch('http://169.254.169.254/latest/meta-data/instance-id', {
      headers: { 'X-aws-ec2-metadata-token': token },
      signal: AbortSignal.timeout(1000),
    }).then((r) => r.text());
  } catch {
    return 'local';
  }
}
module.exports = { getInstanceId };
