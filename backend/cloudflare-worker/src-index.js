/**
 * LottoPattern PH results API for Cloudflare Workers.
 * Deploy with a KV namespace named RESULTS_CACHE (see wrangler.toml).
 * GET /api/results?game=lotto-642&from=2026-01-01&to=2026-01-31
 */
const PCSO_URL = 'https://www.pcso.gov.ph/SearchLottoResult.aspx';
// PCSO's firewall rejects obvious bot user-agents, so send browser-like headers.
const BROWSER_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  'Accept-Language': 'en-PH,en;q=0.9',
  'Upgrade-Insecure-Requests': '1',
};
const GAMES = {
  'lotto-642': { token: '6/42', min: 1, max: 42 },
  'mega-lotto-645': { token: '6/45', min: 1, max: 45 },
  'super-lotto-649': { token: '6/49', min: 1, max: 49 },
  'grand-lotto-655': { token: '6/55', min: 1, max: 55 },
  'ultra-lotto-658': { token: '6/58', min: 1, max: 58 },
};
const MONTHS = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Cache-Control': 'no-store',
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
    if (url.pathname === '/' || url.pathname === '/health') {
      return json({ ok: true, service: 'LottoPattern PH results API' });
    }
    if (url.pathname !== '/api/results') return json({ error: 'Not found' }, 404);
    const gameKey = url.searchParams.get('game') || '';
    const game = GAMES[gameKey];
    const from = url.searchParams.get('from') || '';
    const to = url.searchParams.get('to') || '';
    if (!game) return json({ error: 'Unsupported game. Use one of: ' + Object.keys(GAMES).join(', ') }, 400);
    if (!isDate(from) || !isDate(to) || from > to) return json({ error: 'Provide valid from/to dates in YYYY-MM-DD format.' }, 400);
    const span = (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000;
    if (span > 3650) return json({ error: 'Maximum date range is 10 years.' }, 400);

    const cacheKey = `results:v1:${gameKey}:${from}:${to}`;
    const force = url.searchParams.get('refresh') === '1';
    if (!force && env.RESULTS_CACHE) {
      const cached = await env.RESULTS_CACHE.get(cacheKey);
      if (cached) return json({ ...JSON.parse(cached), cached: true });
    }

    try {
      const results = await queryPcso(game, from, to);
      const payload = {
        source: 'PCSO Search Lotto Results',
        verifiedAt: new Date().toISOString(),
        game: gameKey,
        from,
        to,
        results,
        cached: false,
      };
      if (env.RESULTS_CACHE) {
        // Historical ranges are stable; latest windows refresh more frequently.
        const ttl = span <= 14 ? 300 : 86400;
        await env.RESULTS_CACHE.put(cacheKey, JSON.stringify(payload), { expirationTtl: ttl });
      }
      return json(payload);
    } catch (error) {
      // PCSO blocks Cloudflare IPs. Fall back to draws synced from a home PC
      // (see tools/sync-from-pc.mjs), stored in KV under "dataset:recent".
      try {
        const dataset = env.RESULTS_CACHE ? await env.RESULTS_CACHE.get('dataset:recent', 'json') : null;
        const rows = (dataset?.results || []).filter(r =>
          r.game === game.token.replace('/', '-') && r.drawDate >= from && r.drawDate <= to);
        if (rows.length) {
          return json({
            source: 'Synced from PCSO',
            syncedAt: dataset.syncedAt || null,
            game: gameKey, from, to,
            results: rows.sort((a, b) => b.drawDate.localeCompare(a.drawDate)),
            partial: true, // client merges this with the historical snapshot
            cached: false,
          });
        }
      } catch (_) { /* fall through to the error below */ }
      return json({ error: 'PCSO query failed', detail: String(error?.message || error), source: 'PCSO' }, 502);
    }
  },
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json; charset=utf-8' },
  });
}
function isDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const d = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(d.valueOf()) && d.toISOString().slice(0, 10) === value;
}
function attr(tag, name) {
  const match = tag.match(new RegExp(`\\b${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s>]+))`, 'i'));
  return match ? (match[1] ?? match[2] ?? match[3] ?? '') : '';
}
function cleanHtml(value) {
  return decodeEntities(value.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim());
}
function decodeEntities(value) {
  return value.replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&').replace(/&#39;|&apos;/gi, "'")
    .replace(/&quot;/gi, '"').replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&#x([\da-f]+);/gi, (_, n) => String.fromCharCode(parseInt(n, 16)));
}
function dateParts(iso) {
  const [y, m, d] = iso.split('-').map(Number);
  return { year: y, month: m, day: d };
}
function parseSelects(html) {
  const selects = [];
  for (const match of html.matchAll(/<select\b[^>]*>[\s\S]*?<\/select>/gi)) {
    const block = match[0];
    const open = block.match(/^<select\b[^>]*>/i)?.[0] || '';
    const name = attr(open, 'name');
    const options = [];
    for (const optionMatch of block.matchAll(/<option\b[^>]*>[\s\S]*?<\/option>/gi)) {
      const tag = optionMatch[0].match(/^<option\b[^>]*>/i)?.[0] || '';
      options.push({ value: attr(tag, 'value'), text: cleanHtml(optionMatch[0].replace(/^<option\b[^>]*>/i, '').replace(/<\/option>$/i, '')) });
    }
    selects.push({ name, options });
  }
  return selects;
}
function findOption(select, candidates) {
  return select.options.find(o => candidates.some(c => o.text.toLowerCase() === c.toLowerCase() || o.value.toLowerCase() === c.toLowerCase()));
}
function setDateValue(body, selects, prefix, iso) {
  const d = dateParts(iso);
  const specs = [
    [`ddl${prefix}Month`, [MONTHS[d.month - 1], String(d.month)]],
    [`ddl${prefix}Date`, [String(d.day), String(d.day).padStart(2, '0')]],
    [`ddl${prefix}Year`, [String(d.year)]],
  ];
  for (const [suffix, candidates] of specs) {
    // PCSO names the day control "...Date" for the start and "...Day" for the end.
    const alt = suffix.replace(/Date$/, 'Day');
    const select = selects.find(s => s.name.endsWith(suffix)) || selects.find(s => s.name.endsWith(alt));
    if (!select) throw new Error(`PCSO control ${suffix} not found; site form may have changed. Found: ${selects.map(s => s.name.split('$').pop()).join(', ')}`);
    const option = findOption(select, candidates);
    if (!option) throw new Error(`PCSO does not offer ${suffix} value for ${iso}.`);
    body[select.name] = option.value;
  }
}
async function queryPcso(game, from, to) {
  const getResponse = await fetch(PCSO_URL, { headers: BROWSER_HEADERS });
  if (!getResponse.ok) throw new Error(`PCSO initial page returned HTTP ${getResponse.status}`);
  const html = await getResponse.text();
  const form = html.match(/<form\b[^>]*>[\s\S]*?<\/form>/i)?.[0];
  if (!form) throw new Error('PCSO search form was not found.');

  const body = {};
  for (const match of form.matchAll(/<input\b[^>]*>/gi)) {
    const tag = match[0];
    const name = attr(tag, 'name');
    const type = (attr(tag, 'type') || 'text').toLowerCase();
    if (!name || ['submit', 'button', 'image'].includes(type)) continue;
    body[name] = attr(tag, 'value');
  }
  const selects = parseSelects(form);
  for (const select of selects) {
    if (select.name && select.options.length && !(select.name in body)) body[select.name] = select.options[0].value;
  }
  setDateValue(body, selects, 'Start', from);
  setDateValue(body, selects, 'End', to);
  const gameSelect = selects.find(s => s.name.endsWith('ddlSelectGame'));
  if (!gameSelect) throw new Error('PCSO game selector was not found.');
  const gameOption = gameSelect.options.find(o => o.text.includes(game.token));
  if (!gameOption) throw new Error(`PCSO game option ${game.token} was not found.`);
  body[gameSelect.name] = gameOption.value;
  const submitTag = [...form.matchAll(/<input\b[^>]*>/gi)].map(m => m[0]).find(tag => attr(tag, 'name').endsWith('btnSearch'));
  if (!submitTag) throw new Error('PCSO search button was not found.');
  body[attr(submitTag, 'name')] = attr(submitTag, 'value') || 'Search';

  const cookie = getResponse.headers.get('set-cookie')?.split(/,(?=\s*[^;,=\s]+=)/).map(v => v.split(';')[0].trim()).join('; ');
  const postResponse = await fetch(PCSO_URL, {
    method: 'POST',
    headers: {
      ...BROWSER_HEADERS,
      Origin: 'https://www.pcso.gov.ph',
      'Content-Type': 'application/x-www-form-urlencoded',
      ...(cookie ? { Cookie: cookie } : {}),
      Referer: PCSO_URL,
    },
    body: new URLSearchParams(body),
  });
  if (!postResponse.ok) throw new Error(`PCSO search returned HTTP ${postResponse.status}`);
  return parseResults(await postResponse.text(), game);
}
function parseResults(html, game) {
  const results = [];
  for (const rowMatch of html.matchAll(/<tr\b[^>]*>[\s\S]*?<\/tr>/gi)) {
    const cells = [...rowMatch[0].matchAll(/<td\b[^>]*>([\s\S]*?)<\/td>/gi)].map(m => cleanHtml(m[1]));
    if (cells.length < 3) continue;
    const combo = cells.find(v => /^\d{1,2}(?:\s*-\s*\d{1,2}){5}$/.test(v));
    const dateText = cells.find(v => /\d{1,2}\/\d{1,2}\/\d{4}/.test(v));
    if (!combo || !dateText) continue;
    const numbers = combo.split('-').map(v => Number(v.trim()));
    if (numbers.length !== 6 || numbers.some(n => n < game.min || n > game.max) || new Set(numbers).size !== 6) continue;
    const dateMatch = dateText.match(/(\d{1,2})\/(\d{1,2})\/(\d{4})/);
    const drawDate = `${dateMatch[3]}-${dateMatch[1].padStart(2, '0')}-${dateMatch[2].padStart(2, '0')}`;
    const dateIndex = cells.indexOf(dateText);
    results.push({
      game: game.token.replace('/', '-'),
      drawDate,
      numbers: numbers.sort((a, b) => a - b),
      jackpot: cells[dateIndex + 1] || null,
      winners: Number.isInteger(Number(cells[dateIndex + 2])) ? Number(cells[dateIndex + 2]) : null,
      source: PCSO_URL,
    });
  }
  const unique = new Map(results.map(r => [`${r.drawDate}:${r.numbers.join('-')}`, r]));
  return [...unique.values()].sort((a, b) => b.drawDate.localeCompare(a.drawDate));
}

export { queryPcso, GAMES };
