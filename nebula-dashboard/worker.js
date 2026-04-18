const HTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nebula Mesh</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: #111; color: #ddd; font-family: -apple-system, system-ui, sans-serif; font-size: 14px; min-height: 100vh; }
  header { border-bottom: 1px solid #222; padding: 12px 20px; display: flex; align-items: center; gap: 16px; }
  .logo { font-weight: 600; font-size: 14px; color: #eee; }
  .logo small { font-weight: 400; font-size: 11px; color: #666; margin-left: 8px; }
  .spacer { flex: 1; }
  .stats { display: flex; gap: 20px; font-size: 12px; color: #888; }
  .stats span + span { margin-left: 0; }
  .stats b { color: #ccc; }
  #refresh-btn { background: none; border: 1px solid #333; color: #888; cursor: pointer; font: inherit; font-size: 12px; padding: 5px 12px; border-radius: 4px; }
  #refresh-btn:hover { border-color: #555; color: #bbb; }
  #refresh-btn:disabled { opacity: 0.4; cursor: default; }
  main { max-width: 760px; margin: 0 auto; padding: 20px 16px; }
  .error-box { background: #2a1515; border: 1px solid #4a2020; border-radius: 4px; color: #e88; font-size: 13px; padding: 12px 16px; margin-bottom: 16px; display: none; }
  #loading { text-align: center; padding: 60px 0; color: #555; font-size: 13px; display: none; }
  .section { border: 1px solid #222; border-radius: 6px; margin-bottom: 10px; overflow: hidden; }
  .section-header {
    width: 100%; display: flex; align-items: center; gap: 8px;
    padding: 10px 14px; background: #181818; border: none; border-bottom: 1px solid #222;
    cursor: pointer; text-align: left; font: inherit; font-size: 13px; font-weight: 600; color: #aaa;
  }
  .section-header:hover { background: #1c1c1c; }
  .section-header.collapsed { border-bottom: none; }
  .section-count { font-weight: 400; font-size: 11px; color: #555; }
  .chevron { font-size: 8px; color: #444; margin-left: auto; transition: transform 0.15s; }
  .chevron.open { transform: rotate(90deg); }
  .section-body.hidden { display: none; }
  .host-row { display: flex; align-items: center; gap: 10px; padding: 8px 14px; border-bottom: 1px solid #1a1a1a; }
  .host-row:last-child { border-bottom: none; }
  .host-row:hover { background: #161616; }
  .dot { width: 6px; height: 6px; border-radius: 50%; flex-shrink: 0; }
  .dot.online { background: #4ade80; }
  .dot.offline { background: #333; }
  .host-name { flex: 1; min-width: 0; }
  .badges { display: flex; gap: 4px; align-items: center; }
  .badge { font-size: 10px; padding: 1px 5px; border-radius: 3px; border: 1px solid; }
  .last-seen { font-size: 11px; color: #555; }
  .ip {
    font-family: 'SF Mono', 'Menlo', monospace; font-size: 12px; color: #8ac;
    cursor: pointer; padding: 1px 6px; border-radius: 3px;
  }
  .ip:hover { background: #1a2a3a; }
  .ip.copied { color: #4ade80; }
</style>
</head>
<body>
<header>
  <div class="logo">Nebula Mesh<small>defined.net</small></div>
  <div class="spacer"></div>
  <div class="stats" id="stats" style="display:none">
    <span><b id="stat-hosts">0</b> hosts</span>
    <span><b id="stat-online">0</b> online</span>
    <span><b id="stat-roles">0</b> roles</span>
  </div>
  <button id="refresh-btn" onclick="load()">Refresh</button>
</header>
<main>
  <div id="error-box" class="error-box"></div>
  <div id="loading">Loading…</div>
  <div id="sections"></div>
</main>
<script>
const COLLAPSED_BY_DEFAULT = ['role-VB6LURCQ4UFFSQZLL7PWOMD7QA'];
async function fetchAll(path) {
  let results = [], cursor = null;
  do {
    const url = new URL('/api' + path, location.origin);
    url.searchParams.set('pageSize', '500');
    if (cursor) url.searchParams.set('cursor', cursor);
    const res = await fetch(url.toString());
    if (!res.ok) throw new Error(res.status + ' ' + res.statusText);
    const json = await res.json();
    results = results.concat(json.data);
    cursor = json.metadata?.hasNextPage ? json.metadata.nextCursor : null;
  } while (cursor);
  return results;
}
function timeAgo(iso) {
  if (!iso) return null;
  const s = (Date.now() - new Date(iso)) / 1000;
  if (s < 60) return Math.floor(s) + 's ago';
  if (s < 3600) return Math.floor(s/60) + 'm ago';
  if (s < 86400) return Math.floor(s/3600) + 'h ago';
  return Math.floor(s/86400) + 'd ago';
}
function isOnline(h) { return h.metadata?.lastSeenAt && (Date.now() - new Date(h.metadata.lastSeenAt)) < 300000; }
function makeBadge(label, color) {
  const b = document.createElement('span');
  b.className = 'badge'; b.textContent = label;
  b.style.cssText = 'color:' + color + ';border-color:' + color + '44;background:' + color + '11';
  return b;
}
function makeHostRow(h) {
  const row = document.createElement('div'); row.className = 'host-row';
  const dot = document.createElement('div'); dot.className = 'dot ' + (isOnline(h) ? 'online' : 'offline');
  const name = document.createElement('span'); name.className = 'host-name'; name.textContent = h.name;
  const badges = document.createElement('div'); badges.className = 'badges';
  if (h.isLighthouse) badges.appendChild(makeBadge('LH', '#fbbf24'));
  if (h.isRelay) badges.appendChild(makeBadge('RELAY', '#a78bfa'));
  if (h.isBlocked) badges.appendChild(makeBadge('BLOCKED', '#f87171'));
  
  const ago = timeAgo(h.metadata?.lastSeenAt);
  if (h.metadata?.lastSeenAt) {
    const ls = document.createElement('relative-time');
    ls.className = 'last-seen';
    ls.setAttribute('datetime', h.metadata.lastSeenAt);
    ls.setAttribute('format', 'relative');
    badges.appendChild(ls);
  }
  const ip = document.createElement('span'); ip.className = 'ip'; ip.textContent = h.ipAddress;
  ip.addEventListener('dblclick', () => {
    navigator.clipboard.writeText(h.ipAddress).then(() => {
      ip.classList.add('copied');
      const orig = ip.textContent; ip.textContent = 'Copied!';
      setTimeout(() => { ip.textContent = orig; ip.classList.remove('copied'); }, 1000);
    });
  });
  ip.title = 'Double-click to copy';
  row.appendChild(dot); row.appendChild(name); row.appendChild(badges); row.appendChild(ip);
  return row;
}
function makeSection({ title, hosts, accent = '#8ac', open = true }) {
  if (!hosts.length) return null;
  const wrap = document.createElement('div'); wrap.className = 'section';
  const btn = document.createElement('button'); btn.className = 'section-header' + (open ? '' : ' collapsed');
  const titleEl = document.createElement('span'); titleEl.textContent = title;
  const count = document.createElement('span'); count.className = 'section-count'; count.textContent = hosts.length;
  const chev = document.createElement('span'); chev.className = 'chevron' + (open ? ' open' : ''); chev.textContent = '▶';
  btn.appendChild(titleEl); btn.appendChild(count); btn.appendChild(chev);
  const body = document.createElement('div'); body.className = 'section-body' + (open ? '' : ' hidden');
  hosts.forEach(h => body.appendChild(makeHostRow(h)));
  btn.onclick = () => { const c = body.classList.toggle('hidden'); btn.classList.toggle('collapsed', c); chev.classList.toggle('open', !c); };
  wrap.appendChild(btn); wrap.appendChild(body);
  return wrap;
}
class RelativeTimeElement extends HTMLElement {
  static get observedAttributes() {
    return ['datetime', 'threshold', 'prefix', 'format'];
  }

  connectedCallback() {
    this.update();
  }

  disconnectedCallback() {
    this.stopTimer();
  }

  attributeChangedCallback() {
    this.update();
  }

  scheduleUpdate(ms) {
    this.stopTimer();
    this.timer = setTimeout(() => this.update(), ms);
  }

  stopTimer() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }

  get datetime() {
    return this.getAttribute('datetime') || '';
  }

  get threshold() {
    return this.getAttribute('threshold') || 'P14D';
  }

  get prefix() {
    return this.getAttribute('prefix') || 'on';
  }

  get format() {
    return this.getAttribute('format') || 'relative';
  }

  parseThreshold(iso) {
    const match = iso.match(/^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/);
    if (!match) return 30 * 24 * 60 * 60 * 1000;
    const days = parseInt(match[1] || 0, 10);
    const hours = parseInt(match[2] || 0, 10);
    const minutes = parseInt(match[3] || 0, 10);
    const seconds = parseInt(match[4] || 0, 10);
    return ((days * 24 + hours) * 60 + minutes) * 60 * 1000 + seconds * 1000;
  }

  update() {
    const datetime = this.datetime;
    if (!datetime) return;

    const date = new Date(datetime);
    if (isNaN(date.getTime())) return;

    const now = Date.now();
    const diff = now - date.getTime();
    const absDiff = Math.abs(diff);
    const thresholdMs = this.parseThreshold(this.threshold);

    if (this.format === 'datetime' || absDiff > thresholdMs) {
      this.textContent = this.formatDatetime(date);
      this.scheduleUpdate(3600000);
    } else {
      this.textContent = this.formatRelative(diff);
      const delay = this.getNextUpdateDelay(absDiff);
      if (delay !== null) this.scheduleUpdate(delay);
    }
  }

  getNextUpdateDelay(absDiff) {
    const seconds = Math.floor(absDiff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (seconds < 60) {
      return 1000;
    } else if (minutes < 60) {
      return 60000;
    } else if (hours < 24) {
      return 60000 * 5;
    } else if (days < 7) {
      return 3600000;
    } else if (days < 30) {
      return 3600000 * 6;
    } else {
      return null;
    }
  }

  getRtf() {
    if (!this._rtf || this._rtfLang !== navigator.language) {
      this._rtfLang = navigator.language;
      this._rtf = new Intl.RelativeTimeFormat(navigator.language, {
        numeric: 'auto',
        style: 'long'
      });
    }
    return this._rtf;
  }

  formatRelative(diff) {
    const rtf = this.getRtf();

    const absDiff = Math.abs(diff);
    const sign = diff > 0 ? -1 : 1;
    const seconds = Math.floor(absDiff / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    const date = new Date(Date.now() - diff);
    const now = new Date();
    const months = (now.getFullYear() - date.getFullYear()) * 12 + (now.getMonth() - date.getMonth());
    const years = Math.floor(Math.abs(months) / 12) * sign;

    if (seconds < 60) {
      return rtf.format(sign * seconds, 'second');
    } else if (minutes < 60) {
      return rtf.format(sign * minutes, 'minute');
    } else if (hours < 24) {
      return rtf.format(sign * hours, 'hour');
    } else if (days < 30) {
      return rtf.format(sign * days, 'day');
    } else if (Math.abs(months) < 12) {
      return rtf.format(months, 'month');
    } else {
      return rtf.format(years, 'year');
    }
  }

  formatDatetime(date) {
    const now = new Date();
    const sameYear = date.getFullYear() === now.getFullYear();
    
    const options = {
      month: 'short',
      day: 'numeric',
      ...(sameYear ? {} : { year: 'numeric' })
    };

    const prefix = this.prefix;
    const formatted = new Intl.DateTimeFormat(navigator.language, options).format(date);
    return prefix ? prefix + ' ' + formatted : formatted;
  }
}

customElements.define('relative-time', RelativeTimeElement);
async function load() {
  const btn = document.getElementById('refresh-btn');
  const loader = document.getElementById('loading');
  const errBox = document.getElementById('error-box');
  const secs = document.getElementById('sections');
  const stats = document.getElementById('stats');
  btn.disabled = true; btn.textContent = '…';
  loader.style.display = 'block'; errBox.style.display = 'none';
  secs.innerHTML = ''; stats.style.display = 'none';
  try {
    const [hosts, roles] = await Promise.all([fetchAll('/v1/hosts'), fetchAll('/v1/roles')]);
    const roleMap = Object.fromEntries(roles.map(r => [r.id, r]));
    const lighthouses = hosts.filter(h => h.isLighthouse);
    const relays = hosts.filter(h => h.isRelay && !h.isLighthouse);
    const byRole = {}, noRole = [];
    hosts.filter(h => !h.isLighthouse && !h.isRelay).forEach(h => {
      if (h.roleID && roleMap[h.roleID]) (byRole[h.roleID] ??= []).push(h);
      else noRole.push(h);
    });
    [
      makeSection({ title: 'Lighthouses', hosts: lighthouses, accent: '#fbbf24' }),
      makeSection({ title: 'Relays', hosts: relays, accent: '#a78bfa' }),
      ...Object.entries(byRole).map(([id, hs]) => makeSection({
        title: roleMap[id]?.name ?? id, hosts: hs, accent: '#8ac',
        open: !COLLAPSED_BY_DEFAULT.includes(id)
      })),
      makeSection({ title: 'No Role', hosts: noRole, accent: '#555', open: noRole.length < 20 }),
    ].filter(Boolean).forEach(f => secs.appendChild(f));
    document.getElementById('stat-hosts').textContent = hosts.length;
    document.getElementById('stat-online').textContent = hosts.filter(isOnline).length;
    document.getElementById('stat-roles').textContent = roles.length;
    stats.style.display = 'flex';
  } catch(e) {
    errBox.textContent = 'Error: ' + e.message; errBox.style.display = 'block';
  } finally {
    loader.style.display = 'none'; btn.disabled = false; btn.textContent = 'Refresh';
  }
}
load();
setInterval(load, 30000);
<\/script>
</body>
</html>`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/api/")) {
      const target = new URL(
        "https://api.defined.net" + url.pathname.slice(4) + url.search
      );
      const apiRes = await fetch(target.toString(), {
        headers: {
          Authorization: `Bearer ${env.DN_API_KEY}`,
          "Content-Type": "application/json",
        },
      });
      const body = await apiRes.text();
      return new Response(body, {
        status: apiRes.status,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      });
    }

    return new Response(HTML, {
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  },
};