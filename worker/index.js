// Executado apenas no Cloudflare Worker. Nunca importar no Astro/client-side.
const encoder = new TextEncoder();
const json = (body, status = 200, headers = {}) => new Response(JSON.stringify(body), {
  status, headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', ...headers }
});
const cookieName = 'versin_mystery_002';
const routePrefix = '/sinal/';
const thirdPrefix = '/eco/';
const thirdCookieName = 'versin_mystery_003';
const sessionSeconds = 3600;
function hex(bytes) { return Array.from(new Uint8Array(bytes)).map(x => x.toString(16).padStart(2, '0')).join(''); }
async function signature(key, payload) {
  const cryptoKey = await crypto.subtle.importKey('raw', encoder.encode(key), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return hex(await crypto.subtle.sign('HMAC', cryptoKey, encoder.encode(payload)));
}
function constantTimeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const x = encoder.encode(a), y = encoder.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}
function notFound() { return new Response('Not Found', { status: 404, headers: { 'cache-control': 'no-store' } }); }
async function authenticated(request, env, routeToken) {
  const value = (request.headers.get('cookie') || '')
    .split(';').map(part => part.trim())
    .find(part => part.startsWith(cookieName + '='))?.slice(cookieName.length + 1);
  if (!value || !env.ENIGMATIC_SESSION_KEY) return false;
  const [token, expiry, mac, extra] = value.split('.');
  if (extra !== undefined || !/^[a-f0-9]{40}$/.test(token || '') ||
      !/^\d{10,13}$/.test(expiry || '') || !/^[a-f0-9]{64}$/.test(mac || '')) return false;
  if (!constantTimeEqual(token, routeToken)) return false;
  if (Number(expiry) < Math.floor(Date.now() / 1000)) return false;
  const expected = await signature(env.ENIGMATIC_SESSION_KEY, token + '.' + expiry);
  return constantTimeEqual(mac, expected);
}


function cookieFrom(request, name) {
  return (request.headers.get('cookie') || '').split(';').map(x => x.trim())
    .find(x => x.startsWith(name + '='))?.slice(name.length + 1);
}
async function authenticatedThird(request, env, token) {
  const value = cookieFrom(request, thirdCookieName);
  if (!value || !env.ENIGMATIC_SESSION_KEY) return false;
  const [ownToken, expiry, mac, extra] = value.split('.');
  if (extra !== undefined || !/^[a-f0-9]{40}$/.test(ownToken || '') ||
      !/^\d{10,13}$/.test(expiry || '') || !/^[a-f0-9]{64}$/.test(mac || '')) return false;
  if (!constantTimeEqual(ownToken, token) || Number(expiry) < Math.floor(Date.now()/1000)) return false;
  return constantTimeEqual(mac, await signature(env.ENIGMATIC_SESSION_KEY, '003.' + ownToken + '.' + expiry));
}

export default {
  async fetch(request, env) {
    const pathname = new URL(request.url).pathname;
    if (pathname === '/api/arquivo/abrir') {
      if (request.method !== 'POST') return json({ next: null }, 405, { Allow: 'POST' });
      const origin = request.headers.get('origin');
      if (origin && origin !== new URL(request.url).origin) return json({ next: null }, 403);
      const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
      const allowed = await env.ENIGMATIC_LIMIT.limit({ key: 'enigmatic:'+ip });
      if (!allowed.success) return json({ next: null }, 429);
      if (!env.ENIGMATIC_ANSWER || !env.ENIGMATIC_SESSION_KEY) return json({ next: null }, 503);
      let value;
      try {
        const body = await request.json();
        value = typeof body.value === 'string' ? body.value.trim() : '';
      } catch { return json({ next: null }, 400); }
      if (!/^\d{1,8}$/.test(value) || !constantTimeEqual(value, env.ENIGMATIC_ANSWER)) return json({ next: null });
      // Token gerado no servidor a cada resposta correta (160 bits).
      const token = hex(crypto.getRandomValues(new Uint8Array(20)));
      const expiry = String(Math.floor(Date.now() / 1000) + sessionSeconds);
      const mac = await signature(env.ENIGMATIC_SESSION_KEY, token + '.' + expiry);
      const next = routePrefix + token;
      const cookie = `${cookieName}=${token}.${expiry}.${mac}; Max-Age=${sessionSeconds}; Path=${routePrefix}; HttpOnly; Secure; SameSite=Strict`;
      return json({ next }, 200, { 'Set-Cookie': cookie });
    }
    // O POST de avanço exige o cookie da fase 002 (enviado somente para /sinal/).
    const advance = pathname.match(/^\/sinal\/([a-f0-9]{40})\/avancar$/);
    if (advance) {
      if (request.method !== 'POST') return notFound();
      const origin = request.headers.get('origin');
      if (origin && origin !== new URL(request.url).origin) return notFound();
      if (!(await authenticated(request, env, advance[1]))) return notFound();
      const ip = request.headers.get('CF-Connecting-IP') || 'unknown';
      if (!(await env.ENIGMATIC_LIMIT.limit({key:'enigmatic3:' + ip})).success) return json({next:null},429);
      const token = hex(crypto.getRandomValues(new Uint8Array(20)));
      const expiry = String(Math.floor(Date.now()/1000) + sessionSeconds);
      const mac = await signature(env.ENIGMATIC_SESSION_KEY, '003.' + token + '.' + expiry);
      const cookie = `${thirdCookieName}=${token}.${expiry}.${mac}; Max-Age=${sessionSeconds}; Path=${thirdPrefix}; HttpOnly; Secure; SameSite=Strict`;
      return json({next:thirdPrefix + token},200,{'Set-Cookie':cookie});
    }
    if (/^\/sinal\/[a-f0-9]{40}\/?$/.test(pathname)) {
      if (request.method !== 'GET' && request.method !== 'HEAD') return notFound();
      const routeToken = pathname.split('/')[2];
      if (!(await authenticated(request, env, routeToken))) return notFound();
      const page = String.raw`<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>Arquivo 002 · VERSIN</title><style>
      :root{color-scheme:dark}*{box-sizing:border-box}body{background:#0c0a14;color:#f8f4ff;font:16px system-ui;min-height:100vh;display:grid;place-items:center;margin:0;padding:24px}.panel{padding:38px 30px;border:1px solid #84633d;border-radius:18px;width:min(100%,620px);text-align:center;background:#181222}.label{color:#eac47b;letter-spacing:.2em;font-size:11px}h1{font-size:clamp(30px,5vw,48px);letter-spacing:-.04em}p{color:#c8bfd1;line-height:1.7}.secret-line{position:relative;margin-top:20px;display:flex;align-items:center;justify-content:center;flex-direction:column;gap:10px}.secret-line p{margin:0}.discover{border:1px solid #937043;color:#f0d18d;background:#291e30;border-radius:10px;padding:10px 15px;font:600 13px system-ui;cursor:default;pointer-events:none;user-select:none;opacity:0;visibility:hidden;transform:translateY(-5px);transition:opacity .25s,transform .25s,visibility .25s}.secret-line.revealed .discover,.panel:has(.digit-trigger:hover) .discover,.panel:has(.digit-trigger:focus-visible) .discover{opacity:1;visibility:visible;transform:translateY(0)}.digit-trigger{appearance:none;display:inline-flex;align-items:center;justify-content:center;vertical-align:middle;position:relative;z-index:5;min-width:22px;min-height:32px;padding:0 6px;margin:-8px -6px;border:0;background:transparent;color:inherit;font:inherit;letter-spacing:inherit;line-height:1;cursor:pointer;pointer-events:auto;touch-action:manipulation;-webkit-tap-highlight-color:transparent}.digit-trigger:focus-visible{outline:1px solid #eac47b;outline-offset:3px}.discover:focus-visible{outline:2px solid #eac47b;outline-offset:3px}@media(prefers-reduced-motion:reduce){.discover{transition:none}}</style></head>
      <body><main class="panel"><div class="label">VERSIN / ARQUIVO 00<button class="digit-trigger" id="hidden-trigger" type="button" aria-label="Abrir próximo arquivo">2</button></div><h1>A segunda camada.</h1><p>Às vezes, a resposta está diante dos nossos olhos, mas não conseguimos enxergá-la.</p><div class="secret-line" id="secret-line"><p>Porque enxergar significa evoluir a dificuldade.</p><span class="discover" id="advance" aria-hidden="true">Avançar para o próximo arquivo ↗</span></div></main>
      <script>
      const trigger=document.getElementById('hidden-trigger');
      const line=document.getElementById('secret-line');
      const advanceButton=document.getElementById('advance');
      let opening=false;
      function reveal(){line.classList.add('revealed');}
      trigger.addEventListener('pointerenter',reveal);
      trigger.addEventListener('focus',reveal);
      async function advance(event){
        event.preventDefault();
        event.stopPropagation();
        if(opening)return;
        reveal();opening=true;
        const original='Avançar para o próximo arquivo ↗';
        advanceButton.textContent='Abrindo o próximo arquivo…';
        trigger.disabled=true;
        try{
          const response=await fetch(location.pathname.replace(/\/$/,'')+'/avancar',{
            method:'POST',credentials:'same-origin',cache:'no-store'
          });
          if(!response.ok){
            if(response.status===429)throw Error('Aguarde um minuto e tente novamente.');
            if(response.status===404||response.status===403)throw Error('Sessão expirada. Volte ao convite e resolva o primeiro arquivo novamente.');
            throw Error('Não foi possível abrir o arquivo. Tente novamente.');
          }
          const data=await response.json();
          if(typeof data.next!=='string'||!/^\/eco\/[a-f0-9]{40}$/.test(data.next))
            throw Error('O próximo arquivo não foi encontrado.');
          location.assign(data.next);
        }catch(error){
          opening=false;trigger.disabled=false;
          advanceButton.textContent=error.message||original;
        }
      }
      trigger.addEventListener('click',advance);
      </script></body></html>`;
      return new Response(request.method === 'HEAD' ? null : page, { headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store', 'x-robots-tag': 'noindex, nofollow', 'referrer-policy':'no-referrer' } });
    }
    if (/^\/eco\/[a-f0-9]{40}\/?$/.test(pathname)) {
      if (request.method !== 'GET' && request.method !== 'HEAD') return notFound();
      const token=pathname.split('/')[2];
      if (!(await authenticatedThird(request,env,token))) return notFound();
      const page=`<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>Arquivo 003 · VERSIN</title><style>:root{color-scheme:dark}body{background:#0c0a14;color:#f8f4ff;font:16px system-ui;min-height:100vh;display:grid;place-items:center;margin:0;padding:24px}.panel{padding:38px;border:1px solid #84633d;border-radius:18px;max-width:620px;text-align:center;background:#181222}.label{color:#eac47b;letter-spacing:.2em;font-size:11px}h1{font-size:clamp(30px,5vw,48px)}p{color:#c8bfd1;line-height:1.7}</style></head><body><main class="panel"><div class="label">VERSIN / ARQUIVO 003</div><h1>A terceira camada.</h1><p>O próximo arquivo foi encontrado.</p></main></body></html>`;
      return new Response(request.method==='HEAD'?null:page,{headers:{'content-type':'text/html; charset=utf-8','cache-control':'no-store','x-robots-tag':'noindex, nofollow','referrer-policy':'no-referrer'}});
    }
    return env.ASSETS.fetch(request);
  }
};
