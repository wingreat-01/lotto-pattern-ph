// Run this on YOUR computer (home/mobile internet), not on a server.
// PCSO blocks datacenter IPs, so the Cloudflare Worker can't scrape it,
// but your own connection usually can. This script fetches recent draws
// and uploads them to the Worker's KV cache.
//
//   cd backend/cloudflare-worker
//   node tools/sync-from-pc.mjs            # from 2026-07-01 to today
//   node tools/sync-from-pc.mjs 2026-07-15 # custom start date
//
// Requires Node 18+ and `npx wrangler login` done once.
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { queryPcso, GAMES } from '../src-index.js';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const file = path.join(root, 'recent-results.json');
const from = process.argv[2] || '2026-07-01';
const to = new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Manila' });
const sleep = ms => new Promise(r => setTimeout(r, ms));

// Split the range into ~3-month chunks to keep each PCSO query small.
function chunks(a, b) {
  const out = [];
  let cur = new Date(`${a}T00:00:00Z`);
  const end = new Date(`${b}T00:00:00Z`);
  while (cur <= end) {
    const next = new Date(cur); next.setUTCDate(next.getUTCDate() + 90);
    const stop = next > end ? end : new Date(next.getTime() - 86400000);
    out.push([cur.toISOString().slice(0, 10), stop.toISOString().slice(0, 10)]);
    cur = new Date(stop.getTime() + 86400000);
  }
  return out;
}

const existing = existsSync(file) ? JSON.parse(readFileSync(file, 'utf8')).results || [] : [];
const byKey = new Map(existing.map(r => [`${r.game}:${r.drawDate}`, r]));
let added = 0;

for (const [key, game] of Object.entries(GAMES)) {
  for (const [a, b] of chunks(from, to)) {
    try {
      const rows = await queryPcso(game, a, b);
      for (const r of rows) {
        const k = `${r.game}:${r.drawDate}`;
        if (!byKey.has(k)) added++;
        byKey.set(k, r);
      }
      console.log(`${key} ${a}..${b}: ${rows.length} draws`);
    } catch (e) {
      console.error(`${key} ${a}..${b} FAILED: ${e.message}`);
      if (/403/.test(e.message)) {
        console.error('PCSO is blocking this connection too. Try another network (e.g. phone hotspot).');
        process.exit(1);
      }
    }
    await sleep(1500);
  }
}

const results = [...byKey.values()].sort((x, y) => y.drawDate.localeCompare(x.drawDate));
writeFileSync(file, JSON.stringify({ syncedAt: new Date().toISOString(), results }));
console.log(`Saved ${results.length} draws (${added} new). Uploading to Cloudflare KV...`);
execSync('npx wrangler kv key put --binding=RESULTS_CACHE dataset:recent --path=recent-results.json --remote',
  { cwd: root, stdio: 'inherit' });
console.log('Done.');
