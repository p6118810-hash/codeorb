#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const projectDir = path.resolve(__dirname, '..');
const defaultEnvPath = path.resolve(projectDir, '../backend/.env');
const envPath = process.env.CODEORB_R2_ENV || defaultEnvPath;
const bucket = process.env.CODEORB_R2_BUCKET || '1000ai';
const publicBaseUrl = (process.env.CODEORB_R2_PUBLIC_URL || 'https://downloads.codeorb.app').replace(/\/$/, '');
const prefix = (process.env.CODEORB_R2_PREFIX || 'codeorb').replace(/^\/+|\/+$/g, '');

function loadEnv(file) {
  if (!fs.existsSync(file)) {
    throw new Error(`R2 env file not found: ${file}`);
  }

  const env = {};
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const index = trimmed.indexOf('=');
    if (index === -1) continue;
    const key = trimmed.slice(0, index).trim();
    let value = trimmed.slice(index + 1).trim();
    value = value.replace(/^['"]|['"]$/g, '');
    env[key] = value;
  }
  return env;
}

function contentType(filePath) {
  if (filePath.endsWith('.xml')) return 'application/xml; charset=utf-8';
  if (filePath.endsWith('.dmg')) return 'application/x-apple-diskimage';
  if (filePath.endsWith('.html')) return 'text/html; charset=utf-8';
  return 'application/octet-stream';
}

async function upload(client, filePath, key, cacheControl) {
  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: fs.createReadStream(filePath),
    ContentType: contentType(filePath),
    CacheControl: cacheControl,
  });
  await client.send(command);
  return `${publicBaseUrl}/${key}`;
}

async function main() {
  const [dmgArg, appcastArg] = process.argv.slice(2);
  if (!dmgArg || !appcastArg) {
    console.error('Usage: upload-codeorb-r2.js <CodeOrb.dmg> <appcast.xml>');
    process.exit(1);
  }

  const dmgPath = path.resolve(projectDir, dmgArg);
  const appcastPath = path.resolve(projectDir, appcastArg);
  if (!fs.existsSync(dmgPath)) throw new Error(`DMG not found: ${dmgPath}`);
  if (!fs.existsSync(appcastPath)) throw new Error(`appcast not found: ${appcastPath}`);

  const env = loadEnv(envPath);
  const accountId = process.env.CLOUDFLARE_R2_ACCOUNT_ID || env.CLOUDFLARE_R2_ACCOUNT_ID;
  const accessKeyId = process.env.CLOUDFLARE_R2_ACCESS_KEY_ID || env.CLOUDFLARE_R2_ACCESS_KEY_ID;
  const secretAccessKey = process.env.CLOUDFLARE_R2_SECRET_ACCESS_KEY || env.CLOUDFLARE_R2_SECRET_ACCESS_KEY;

  if (!accountId || !accessKeyId || !secretAccessKey) {
    throw new Error('R2 credentials are incomplete.');
  }

  const client = new S3Client({
    region: 'auto',
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
    credentials: { accessKeyId, secretAccessKey },
  });

  const dmgKey = `${prefix}/${path.basename(dmgPath)}`;
  const appcastKey = `${prefix}/appcast.xml`;
  const releaseNotesPath = appcastPath.replace(/appcast\.xml$/, path.basename(dmgPath, '.dmg') + '.html');
  const releaseNotesKey = `${prefix}/${path.basename(releaseNotesPath)}`;

  const dmgUrl = await upload(client, dmgPath, dmgKey, 'public, max-age=31536000, immutable');
  const appcastUrl = await upload(client, appcastPath, appcastKey, 'public, max-age=60, must-revalidate');

  let releaseNotesUrl = null;
  if (fs.existsSync(releaseNotesPath)) {
    releaseNotesUrl = await upload(client, releaseNotesPath, releaseNotesKey, 'public, max-age=31536000, immutable');
  }

  console.log(`DMG: ${dmgUrl}`);
  console.log(`appcast: ${appcastUrl}`);
  if (releaseNotesUrl) console.log(`release notes: ${releaseNotesUrl}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
