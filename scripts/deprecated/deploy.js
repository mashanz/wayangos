const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const enc = JSON.parse(fs.readFileSync(path.join(__dirname, '../.secrets/cloudflare.enc'), 'utf8'));
const key = Buffer.from(enc.key, 'hex');
const iv = Buffer.from(enc.iv, 'hex');
const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
let token = decipher.update(enc.data, 'hex', 'utf8') + decipher.final('utf8');
token = token.trim();

const env = { ...process.env, CLOUDFLARE_API_TOKEN: token, CLOUDFLARE_ACCOUNT_ID: '7015227975bbf8897dd65c2d021e08ef' };

console.log('Creating WayangOS project on Cloudflare Pages...');
try {
  execSync('npx wrangler pages project create wayangos --production-branch main', { cwd: __dirname, env, stdio: 'inherit', timeout: 30000 });
} catch (e) {
  console.log('Project may already exist, continuing...');
}

console.log('Deploying landing page...');
try {
  execSync('npx wrangler pages deploy landing-page --project-name=wayangos --commit-dirty=true', { cwd: __dirname, env, stdio: 'inherit', timeout: 60000 });
  console.log('Done!');
} catch (e) {
  console.error('Deploy failed:', e.message);
}
