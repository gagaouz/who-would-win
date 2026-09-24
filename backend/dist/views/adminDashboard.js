"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.serializeDashboardData = serializeDashboardData;
exports.renderDashboardHtml = renderDashboardHtml;
function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[character]));
}
/** The payload contains untrusted creature labels. Never let it end its script element. */
function serializeDashboardData(data) {
    return JSON.stringify(data).replace(/</g, '\\u003c').replace(/>/g, '\\u003e')
        .replace(/&/g, '\\u0026').replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029');
}
function renderDashboardHtml(data, nonce) {
    const number = (n) => n.toLocaleString('en-US');
    return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="theme-color" content="#faf7ee">
  <title>Creature inbox · Animal vs Animal</title>
  <style>${DASHBOARD_CSS}</style>
</head>
<body>
<a class="skip" href="#workspace">Skip to creature list</a>
<div class="app">
  <aside class="sidebar" aria-label="Dashboard navigation">
    <a href="/api/admin/dashboard" class="brand" aria-label="Animal vs Animal dashboard"><span class="brand-mark" aria-hidden="true">a<span>↔</span>a</span><span>Animal vs Animal<small>THE FIELD NOTES</small></span></a>
    <div class="sidebar-label">YOUR WORKSPACE</div>
    <nav class="tabs" role="tablist" aria-label="Dashboard views">
      <button type="button" role="tab" id="tab-creatures" data-tab="creatures" aria-controls="panel-creatures" aria-selected="true" tabindex="0"><span class="tab-icon" aria-hidden="true">${icon('paw')}</span><span>Typed creatures</span><span class="nav-count">${number(data.custom.totalUniqueCreatures)}</span></button>
      <button type="button" role="tab" id="tab-battles" data-tab="battles" aria-controls="panel-battles" aria-selected="false" tabindex="-1"><span class="tab-icon" aria-hidden="true">${icon('swords')}</span><span>Battle results</span></button>
      <button type="button" role="tab" id="tab-rankings" data-tab="rankings" aria-controls="panel-rankings" aria-selected="false" tabindex="-1"><span class="tab-icon" aria-hidden="true">${icon('podium')}</span><span>Rankings</span></button>
    </nav>
    <div class="sidebar-note"><span class="small-stamp">OWNER’S EDITION</span><p>A little curiosity.<br>A lot of creatures.</p><span class="note-art" aria-hidden="true">${icon('paw')}</span></div>
    <form method="post" action="/api/admin/logout" class="logout-form"><button class="signout" type="submit">${icon('exit')} Sign out</button></form>
  </aside>
  <main class="main" id="workspace">
    <header class="topbar"><span class="breadcrumb">Your app <span aria-hidden="true">/</span> Field notes</span><div class="top-actions"><span class="updated" id="updated-label">Snapshot</span><a class="refresh icon-button" href="/api/admin/dashboard" aria-label="Refresh dashboard">${icon('refresh')}</a><form method="post" action="/api/admin/logout" class="mobile-signout"><button class="icon-button" type="submit" aria-label="Sign out">${icon('exit')}</button></form></div></header>
    <div class="pulse" aria-label="Recorded server activity"><span><strong>${number(data.overview.battles24h)}</strong> past 24 hours</span><span><strong>${number(data.overview.battles7d)}</strong> past 7 days</span><span><strong>${number(data.overview.totalBattles)}</strong> all time</span><span class="pulse-scope">Cloud results only</span></div>

    <section class="panel" id="panel-creatures" role="tabpanel" aria-labelledby="tab-creatures">
      <div class="page-heading"><div><p class="eyebrow">THE IDEA BOX</p><h1>What are they typing?</h1><p class="lede">Every available creature name, in one place.</p></div><span class="heading-sticker" aria-hidden="true">Made of<br><b>curiosity.</b><span>✦</span></span></div>
      <div class="inbox-meta"><span class="list-total"><strong>${number(data.custom.totalUniqueCreatures)}</strong> unique names</span><span class="memory-tag">Temporary history</span><details class="history-info"><summary>What’s included?</summary><div class="info-copy"><strong>The complete available list</strong><p>Accepted custom lookups and battle requests received by this server, even if cloud generation fails. Names are grouped without a top-50 cutoff. Searches cover the entire available list.</p><p id="history-window"></p><p>Names clear when this server restarts. Previously erased names and creatures created only on a device are unavailable. Battle totals are stored separately and cover a longer history.</p><p id="history-capacity"></p></div></details></div>
      <div class="toolbar"><label class="searchbox">${icon('search')}<span class="sr-only">Search all typed creatures</span><input type="search" id="creature-search" placeholder="Find any typed creature…" autocomplete="off"></label><label class="sortbox"><span class="sr-only">Sort typed creatures</span><select id="creature-sort"><option value="recent">Newest first</option><option value="popular">Most activity</option><option value="az">Name A–Z</option><option value="battles">Most battles</option></select></label><button type="button" class="clear-filters" data-clear="creatures" hidden>Clear search</button></div>
      <div class="list-frame"><div class="list-head creature-head" aria-hidden="true"><span>CREATURE NAME</span><span>REQUESTS</span><span>BATTLES</span><span>LAST SEEN</span><span></span></div><div id="creature-list" class="data-list"></div><div id="creature-pager" class="pager"></div></div>
      <p class="list-footnote">Open a name for its wins, timestamps and recent opponents.</p>
    </section>

    <section class="panel" id="panel-battles" role="tabpanel" aria-labelledby="tab-battles" hidden>
      <div class="page-heading"><div><p class="eyebrow">FROM THE ARENA</p><h1>Who came out on top?</h1><p class="lede">The latest ${number(data.recent.length)} recorded cloud results.</p></div><span class="heading-sticker pink-sticker" aria-hidden="true">A friendly<br><b>rivalry.</b><span>↔</span></span></div>
      <div class="inbox-meta"><span class="list-total">Matchups, winners & arenas</span><details class="history-info"><summary>About these results</summary><div class="info-copy"><p>Local/offline battles are not sent to this server. Melee entries show the MVP versus one opposing fighter, not the complete teams. Historical custom names were removed; they appear as “Custom creature”.</p><p>Search and filters cover the latest ${number(data.recent.length)} loaded results. Narration is not saved in the battle history.</p></div></details></div>
      <div class="toolbar"><label class="searchbox">${icon('search')}<span class="sr-only">Search battle results</span><input type="search" id="battle-search" placeholder="Fighter, winner or arena…" autocomplete="off"></label><label class="sortbox"><span class="sr-only">Battle mode</span><select id="battle-mode"><option value="all">All modes</option><option value="full">Full battles</option><option value="quick">Quick battles</option><option value="melee">Melee summaries</option></select></label><button type="button" class="clear-filters" data-clear="battles" hidden>Clear filters</button></div>
      <div class="list-frame"><div class="list-head battle-head" aria-hidden="true"><span>MATCHUP</span><span>WINNER</span><span>WHEN</span><span></span></div><div id="battle-list" class="data-list"></div><div id="battle-pager" class="pager"></div></div>
    </section>

    <section class="panel" id="panel-rankings" role="tabpanel" aria-labelledby="tab-rankings" hidden>
      <div class="page-heading"><div><p class="eyebrow">THE CROWD FAVOURITES</p><h1>Meet the front-runners.</h1><p class="lede">Built-in creatures, ranked by full-mode battles.</p></div><span class="heading-sticker green-sticker" aria-hidden="true">A wild<br><b>lineup.</b><span>★</span></span></div>
      <div class="toolbar"><label class="searchbox">${icon('search')}<span class="sr-only">Search ranked creatures</span><input type="search" id="ranking-search" placeholder="Find a creature…" autocomplete="off"></label><label class="sortbox"><span class="sr-only">Rank creatures by</span><select id="ranking-sort"><option value="popular">Most picked</option><option value="wins">Most wins</option><option value="rate">Best win rate</option></select></label><button type="button" class="clear-filters" data-clear="rankings" hidden>Clear search</button></div>
      <div class="list-frame"><div class="list-head ranking-head" aria-hidden="true"><span>CREATURE</span><span>BATTLES</span><span>WINS</span><span>WIN RATE</span></div><div id="ranking-list" class="data-list"></div><div id="ranking-pager" class="pager"></div></div><p class="list-footnote">Win-rate rankings include creatures with at least 10 battles.</p>
    </section>
    <noscript><p class="notice">Enable JavaScript to search and page through this dashboard. <a href="/api/admin/custom-creatures">Read the complete available creature report</a>.</p></noscript>
    <footer class="workspace-footer"><span>Animal vs Animal</span><span>Private owner dashboard · Times shown on your device</span></footer>
  </main>
</div>
<script nonce="${escapeHtml(nonce)}">const dashboardData = ${serializeDashboardData(data)};
${DASHBOARD_JS}
</script>
</body>
</html>`;
}
function icon(name) {
    const paths = {
        paw: '<ellipse cx="8" cy="6" rx="2" ry="3"/><ellipse cx="16" cy="6" rx="2" ry="3"/><ellipse cx="3" cy="11" rx="2" ry="2.5"/><ellipse cx="21" cy="11" rx="2" ry="2.5"/><path d="M6 19c0-3 3-8 6-8s6 5 6 8c0 4-4 1-6 1s-6 3-6-1Z"/>',
        swords: '<path d="m4 3 7 8-3 3-5-7V3h1Zm16 0-7 8 3 3 5-7V3h-1ZM5 14l5 5m4-5 5 5M7 17l-4 4m14-4 4 4"/>',
        podium: '<path d="M3 12h5v9H3Zm5-7h8v16H8Zm8 10h5v6h-5ZM10 2h4"/>',
        search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
        refresh: '<path d="M20 7v5h-5M4 17v-5h5M6.5 6a8 8 0 0 1 13 4M17.5 18a8 8 0 0 1-13-4"/>',
        exit: '<path d="M9 4H4v16h5m6-12 4 4-4 4M9 12h10"/>',
    };
    return `<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] ?? ''}</svg>`;
}
const DASHBOARD_CSS = String.raw `
@font-face{font-family:Nunito;src:url('/api/admin/assets/Nunito.ttf') format('truetype');font-weight:200 900;font-display:swap}
@font-face{font-family:Fredoka;src:url('/api/admin/assets/Fredoka.ttf') format('truetype');font-weight:300 700;font-display:swap}
:root{color-scheme:light;--paper:oklch(97.6% .013 85);--surface:oklch(99% .006 85);--ink:#2d1b4e;--muted:#73677d;--line:#e6dfdf;--sun:#ffd764;--lavender:#ece5f7;--green:#e6eddf;--pink:#f6d6df;--accent:#634b89;--radius:12px;--space-sm:8px;--space-md:16px;--space-lg:24px}
*{box-sizing:border-box}html{scroll-behavior:auto}body{margin:0;background:var(--paper);color:var(--ink);font:500 1rem/1.45 Nunito,sans-serif;-webkit-font-smoothing:antialiased}button,input,select{font:inherit}button,a,summary{-webkit-tap-highlight-color:transparent}button,select,summary{cursor:pointer}button,a,summary,select,input{touch-action:manipulation}button{color:inherit}a{color:inherit}button:focus-visible,a:focus-visible,summary:focus-visible,select:focus-visible,input:focus-visible{outline:3px solid var(--accent);outline-offset:3px}button:disabled{opacity:.38;cursor:default}[hidden]{display:none!important}.sr-only{position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%);white-space:nowrap}.skip{position:fixed;top:-100px;left:16px;z-index:20;background:var(--sun);padding:12px}.skip:focus{top:12px}.app{min-height:100dvh}.sidebar{padding:16px 16px 0}.brand{display:flex;align-items:center;gap:10px;text-decoration:none;font-weight:850;font-size:.95rem}.brand small{display:none}.brand-mark{width:40px;height:36px;border:2px solid var(--ink);border-radius:10px 10px 10px 3px;box-shadow:2px 2px 0 var(--ink);display:flex;align-items:center;justify-content:center;background:var(--sun);font:500 1.125rem Fredoka,sans-serif;letter-spacing:-.05em}.brand-mark span{font:600 .8rem Nunito,sans-serif;padding:0 1px}.sidebar-label,.sidebar-note,.logout-form{display:none}.tabs{display:flex;gap:4px;margin-top:17px;border-bottom:1px solid var(--line)}.tabs button{position:relative;display:flex;flex:1;justify-content:center;align-items:center;gap:7px;min-height:48px;padding:10px 6px;background:transparent;border:0;border-bottom:3px solid transparent;font-size:.8125rem;font-weight:800;white-space:nowrap;color:var(--muted)}.tabs button[aria-selected=true]{border-bottom-color:var(--ink);color:var(--ink)}.tab-icon,.nav-count{display:none}.main{min-width:0;padding:0 16px 16px}.topbar{display:flex;justify-content:space-between;align-items:center;min-height:46px;font-size:.75rem;color:var(--muted)}.breadcrumb{display:none}.top-actions{display:flex;gap:6px;align-items:center;width:100%;justify-content:flex-end}.updated{margin-right:auto}.icon-button{display:inline-flex;align-items:center;justify-content:center;width:44px;height:44px;background:transparent;border:0;border-radius:10px;text-decoration:none}.icon-button:hover{background:var(--lavender)}form{margin:0}.pulse{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 0 13px;border-bottom:1px solid var(--line);font-size:.69rem;color:var(--muted)}.pulse strong{color:var(--ink);font-size:.875rem;display:block;font-variant-numeric:tabular-nums}.pulse-clarify,.pulse-scope{display:none}.page-heading{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:24px 0 18px}.eyebrow{font-size:.625rem;font-weight:900;letter-spacing:.17em;color:var(--accent);margin:0 0 7px}h1{font:500 1.875rem/1.12 Fredoka,sans-serif;letter-spacing:-.025em;margin:0}.lede{font-size:.8125rem;margin:8px 0 0;color:var(--muted)}.heading-sticker{display:none}.inbox-meta{display:flex;flex-wrap:wrap;gap:8px 12px;align-items:center;font-size:.75rem;margin-bottom:12px}.list-total{font-weight:750}.list-total strong{font-size:1rem;font-weight:900}.memory-tag{background:var(--lavender);padding:4px 8px;border-radius:5px;font-size:.625rem;font-weight:850;letter-spacing:.015em}.history-info{margin-left:auto;position:relative}.history-info>summary{list-style:none;min-height:36px;display:flex;align-items:center;color:var(--accent);text-decoration:underline;text-underline-offset:3px}.history-info>summary::-webkit-details-marker{display:none}.history-info[open]{width:100%;order:5}.info-copy{background:var(--surface);padding:12px 16px;border:1px solid var(--line);border-radius:var(--radius);max-width:70ch;font-size:.8125rem}.info-copy p{margin:8px 0}.toolbar{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}.searchbox{display:flex;align-items:center;gap:10px;background:var(--surface);border:1px solid #d9d0dd;border-radius:9px;padding:0 12px;flex:1;min-width:0}.searchbox svg{flex:none;color:#897990}.searchbox input{border:0;background:transparent;color:var(--ink);min-width:0;width:100%;height:44px;font-size:1rem;outline-offset:-2px}.searchbox input::placeholder{color:#897d8d;font-size:.8125rem}.sortbox{min-width:0}.sortbox select{border:1px solid #d9d0dd;border-radius:9px;background:var(--surface);padding:0 25px 0 10px;height:46px;font-size:.75rem;color:var(--ink);max-width:140px}.clear-filters{width:100%;text-align:left;border:0;background:transparent;padding:3px 0;color:var(--accent);font-size:.75rem;text-decoration:underline;min-height:36px}.list-frame{background:var(--surface);border:1px solid #dcd3dd;border-radius:var(--radius);overflow:hidden}.list-head{display:none}.data-row{border-bottom:1px solid var(--line);padding:0 14px}.data-row:last-child{border-bottom:0}.row-summary{list-style:none;display:grid;align-items:center;min-height:70px;gap:8px;padding:12px 0;font-size:.875rem;grid-template-columns:minmax(0,1fr) auto 14px}.row-summary::-webkit-details-marker{display:none}.row-summary:focus-visible{outline-offset:-3px}.name-cell{display:flex;align-items:center;gap:10px;min-width:0}.avatar{flex:none;width:34px;height:34px;background:var(--lavender);border-radius:9px 9px 9px 3px;display:grid;place-items:center;font:500 1.0625rem Fredoka,sans-serif}.tone-1{background:#f5e4ba}.tone-2{background:#dcebe1}.tone-3{background:#f3dce4}.tone-4{background:#dfe8f1}.name-stack{min-width:0}.name-stack strong{display:block;overflow-wrap:anywhere;font-weight:850;line-height:1.25}.name-stack small{display:block;color:var(--muted);margin-top:5px;font-size:.69rem}.data-number{font-weight:800;font-variant-numeric:tabular-nums}.desktop-cell{display:none}.row-time{font-size:.69rem;color:var(--muted);white-space:nowrap}.chevron{color:#908196;transition:transform 140ms ease}.data-row[open] .chevron{transform:rotate(90deg)}.row-details{padding:0 0 16px 44px;font-size:.8125rem}.row-details dl{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin:0 0 12px}.row-details dt{color:var(--muted);font-size:.69rem;margin-bottom:2px}.row-details dd{margin:0;font-weight:750;overflow-wrap:anywhere}.row-details p{margin:8px 0;color:var(--muted)}.opponent-list{display:flex;flex-wrap:wrap;gap:6px;margin-top:6px}.opponent-chip{border:1px solid var(--line);padding:4px 8px;border-radius:6px;overflow-wrap:anywhere}.pager{display:flex;align-items:center;flex-wrap:wrap;gap:8px;justify-content:space-between;padding:12px 14px;border-top:1px solid var(--line);font-size:.75rem;color:var(--muted);background:#fcfaf5}.pager-status{font-variant-numeric:tabular-nums;min-width:85px}.pager-controls{display:flex;align-items:center;gap:4px}.page-button{width:40px;height:40px;border:1px solid var(--line);border-radius:8px;background:var(--surface);font-size:1rem}.page-button:hover:enabled{background:var(--lavender)}.page-number{font-size:.69rem;padding:0 7px;font-variant-numeric:tabular-nums}.page-size{display:flex;align-items:center;gap:6px}.page-size select{height:36px;border:1px solid var(--line);border-radius:6px;background:var(--surface);color:var(--ink);font-size:.75rem}.page-size span{display:none}.list-footnote{font-size:.69rem;color:var(--muted);margin:10px 2px 0}.workspace-footer{display:flex;gap:8px;flex-wrap:wrap;justify-content:space-between;margin-top:28px;padding-top:14px;border-top:1px solid var(--line);font-size:.625rem;color:#7c7083}.workspace-footer>span:first-child{font-weight:850}.empty-state{padding:40px 24px;text-align:center}.empty-art{margin:auto auto 18px;display:grid;place-items:center;width:64px;height:64px;color:var(--ink);background:var(--sun);border:2px solid var(--ink);border-radius:50% 50% 42% 42%;box-shadow:3px 3px 0 var(--ink);font:500 1.75rem Fredoka,sans-serif;transform:rotate(-7deg)}.empty-state h2{font:500 1.25rem Fredoka,sans-serif;margin:0 0 8px}.empty-state p{max-width:44ch;margin:0 auto;color:var(--muted);font-size:.8125rem}.empty-state button{margin-top:16px;min-height:44px;border:1px solid var(--ink);border-radius:9px;background:var(--sun);font-weight:800;padding:8px 16px}.battle-summary{grid-template-columns:minmax(0,1fr) 14px}.winner-inline{color:#38694c!important;font-weight:800}.mode-label{font-size:.625rem;font-weight:800;text-transform:uppercase;letter-spacing:.04em}.battle-head{grid-template-columns:minmax(0,1fr) 160px 90px 14px}.ranking-row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:12px;align-items:center;min-height:64px;padding:12px 14px;border-bottom:1px solid var(--line);font-size:.875rem}.rank-number{font:500 1.125rem Fredoka,sans-serif;color:var(--accent);width:26px;flex:none}.rank-metric{font-weight:900;font-variant-numeric:tabular-nums}.ranking-mobile-meta{font-size:.69rem;margin-top:4px;color:var(--muted)}.notice{padding:16px;background:var(--pink)}
@media(min-width:700px){.main{padding:0 28px 24px}.sidebar{padding:20px 28px 0}.tab-icon{display:inline-flex}.nav-count{display:inline-flex;padding:1px 6px;border-radius:4px;background:#ded2ef;font-size:.69rem}.topbar{min-height:56px}.breadcrumb{display:block;white-space:nowrap}.breadcrumb span{margin:0 12px;color:#b2a6b7}.top-actions{width:auto;gap:12px}.updated{margin:0}.pulse{justify-content:flex-start;gap:28px;font-size:.75rem;padding:14px 0}.pulse strong{display:inline;margin-right:5px;font-size:1rem}.pulse-scope{display:block;margin-left:auto;font-size:.69rem}.page-heading{padding:30px 0 24px}.eyebrow{font-size:.69rem}h1{font-size:2.5rem}.lede{font-size:.875rem}.heading-sticker{flex:none;display:block;position:relative;margin-right:12px;transform:rotate(8deg);padding:13px 22px;border:2px solid var(--ink);box-shadow:3px 3px 0 var(--ink);border-radius:50%;background:var(--sun);font:400 1rem/1.15 Fredoka,sans-serif;text-align:center}.heading-sticker b{font-weight:550}.heading-sticker span{position:absolute;right:-9px;top:-4px;font-size:1.5rem}.pink-sticker{background:var(--pink)}.green-sticker{background:#d3e5c3}.inbox-meta{font-size:.8125rem}.list-total strong{font-size:1.125rem}.memory-tag{font-size:.69rem}.toolbar{gap:10px}.sortbox select{max-width:none;min-width:166px;font-size:.8125rem}.clear-filters{width:auto;padding:0 8px}.list-head{display:grid;gap:12px;padding:14px 20px;background:#f5f1e9;border-bottom:1px solid var(--line);font-size:.625rem;font-weight:900;letter-spacing:.1em;color:var(--muted)}.creature-head,.creature-summary{grid-template-columns:minmax(0,1fr) 75px 75px 100px 14px}.data-row{padding:0 20px}.row-summary{min-height:62px;gap:12px;padding:10px 0}.data-number{font-size:.8125rem}.row-time{font-size:.75rem}.desktop-cell{display:block}.mobile-cell{display:none}.row-details{padding:4px 0 20px 44px;max-width:760px}.row-details dl{grid-template-columns:repeat(4,minmax(0,1fr));gap:16px}.pager{padding:12px 20px;gap:16px}.page-size span{display:block}.page-number{font-size:.75rem}.list-footnote{font-size:.75rem}.battle-summary{grid-template-columns:minmax(0,1fr) 160px 90px 14px}.winner-cell{font-weight:850;color:#38694c;font-size:.8125rem;overflow-wrap:anywhere}.ranking-head,.ranking-row{grid-template-columns:minmax(0,1fr) 100px 100px 100px}.ranking-row{padding:12px 20px}.ranking-mobile-meta{display:none}.ranking-desktop-metric{display:block}.workspace-footer{font-size:.69rem}.empty-state{padding:50px 24px}}
@media(min-width:1100px){.app{display:grid;grid-template-columns:232px minmax(0,1fr)}.sidebar{position:sticky;top:0;height:100dvh;border-right:1px solid #e1d9de;padding:28px 20px 20px;display:flex;flex-direction:column;background:#f0ecdf}.brand{gap:12px;font-size:.8125rem}.brand small{display:block;font-size:.5rem;letter-spacing:.15em;margin-top:4px;color:var(--muted)}.brand-mark{width:41px;height:39px;flex:none}.sidebar-label{display:block;margin:48px 10px 10px;color:#8e8099;font-size:.625rem;font-weight:850;letter-spacing:.1em}.tabs{display:flex;flex-direction:column;border:0;margin:0;gap:6px}.tabs button{justify-content:flex-start;flex:none;padding:12px 10px;border:0;border-radius:9px;font-size:.8125rem;gap:11px;min-height:48px}.tabs button[aria-selected=true]{background:var(--ink);color:#fcf8ef}.tabs button[aria-selected=true] .nav-count{color:var(--ink);background:var(--sun)}.nav-count{margin-left:auto}.sidebar-note{display:block;position:relative;margin:auto 10px 28px;padding-top:48px;color:#7c7083}.small-stamp{font-size:.5rem;font-weight:900;letter-spacing:.16em}.sidebar-note p{font:400 1.1875rem/1.3 Fredoka,sans-serif;color:#756080;margin-top:10px}.note-art{display:block;transform:rotate(-16deg);margin-top:22px;color:#b7a3bf}.note-art svg{width:50px;height:50px;stroke-width:1}.logout-form{display:block;border-top:1px solid #dcd3dc;padding-top:12px}.signout{min-height:44px;background:none;border:0;display:flex;align-items:center;gap:10px;color:var(--muted);font-size:.8125rem;padding:8px 10px}.main{padding:0 40px 24px;width:100%;max-width:1360px;margin:0 auto}.topbar{min-height:77px}.mobile-signout{display:none}.page-heading{padding-top:36px}.pulse-clarify{display:inline}.pulse{gap:32px}.page-heading .heading-sticker{margin-right:22px}.toolbar{margin-top:16px}.tabs button:hover:not([aria-selected=true]){background:#e4ddeb}}
@media(max-width:370px){.sidebar{padding:12px 12px 0}.main{padding:0 12px 12px}.tabs button{font-size:.75rem}.tabs{gap:0}.sortbox select{max-width:116px;padding-left:7px}h1{font-size:1.625rem}.memory-tag{font-size:.56rem}.history-info{margin-left:0}.searchbox{padding:0 9px;gap:6px}.searchbox input::placeholder{font-size:.75rem}.pager{padding:10px;gap:6px}.page-number{padding:0 2px}.page-button{width:36px}.row-details{padding-left:0}}
@media(max-width:699px){.brand{font-size:.8125rem;padding-right:92px}.topbar{position:absolute;top:12px;right:12px;min-height:44px}.top-actions{gap:0}.updated{display:none}.pulse{padding:9px 0}.page-heading{padding:18px 0 12px}.eyebrow{display:none}h1{font-size:1.625rem}.lede{font-size:.75rem;margin-top:5px}.panel:first-of-type .lede{display:none}.inbox-meta{margin-bottom:8px}.row-summary{min-height:64px;padding:9px 0}.workspace-footer{margin-top:18px}}
@media(min-width:700px){.name-stack .mobile-cell{display:none}}
@media(max-width:370px){.creature-summary{grid-template-columns:minmax(0,1fr) 14px}.creature-summary>.row-time{display:none}.page-button{width:40px;height:44px}.page-size select{height:44px}}
@media(prefers-reduced-motion:reduce){*,*::before,*::after{transition:none!important;animation:none!important}}
`;
const DASHBOARD_JS = String.raw `
(function () {
  'use strict';
  var d = dashboardData;
  var initialSize = window.matchMedia('(max-width:699px)').matches ? 5 : 10;
  var state = { creatures: { page: 1, size: initialSize }, battles: { page: 1, size: initialSize }, rankings: { page: 1, size: initialSize } };
  var active = 'creatures';
  var relative = new Intl.RelativeTimeFormat(undefined, {numeric:'auto'});
  var number = function(v) { return Number(v || 0).toLocaleString(); };
  var date = function(v) { return new Date(v).toLocaleString(undefined,{dateStyle:'medium',timeStyle:'short'}); };
  var ago = function(v) {
    if (!v || !Number.isFinite(Date.parse(v))) return '—';
    var delta = Date.parse(v) - Date.now(), abs = Math.abs(delta);
    var unit = abs < 3600000 ? 'minute' : abs < 86400000 ? 'hour' : 'day';
    return relative.format(Math.round(delta / (unit === 'minute' ? 60000 : unit === 'hour' ? 3600000 : 86400000)), unit);
  };
  var text = function(tag, label, cls) { var e = document.createElement(tag); if (label != null) e.textContent = String(label); if (cls) e.className = cls; return e; };
  var el = function(id) { return document.getElementById(id); };
  var label = function(value) { return value === 'custom' ? 'Custom creature' : value; };
  var captured = d.custom.capturedSince || d.custom.generatedAt;
  el('updated-label').textContent = 'Updated ' + new Date(d.custom.generatedAt).toLocaleTimeString(undefined,{hour:'numeric',minute:'2-digit'});
  el('history-window').textContent = 'This server began collecting on ' + date(captured) + '. Names expire after ' + (d.custom.retentionDays || 90) + ' days of inactivity.';
  el('history-capacity').textContent = 'Temporary capacity: ' + number(d.custom.capacity || 5000) + ' distinct names.' + (d.custom.evictedCount ? ' ' + number(d.custom.evictedCount) + ' older names were removed when capacity was reached.' : '') + (d.custom.expiredCount ? ' ' + number(d.custom.expiredCount) + ' entries expired.' : '');

  function setTab(key, updateHash) {
    if (['creatures','battles','rankings'].indexOf(key) === -1) key = 'creatures';
    active = key;
    document.querySelectorAll('[data-tab]').forEach(function(button) {
      var selected = button.dataset.tab === key;
      button.setAttribute('aria-selected',String(selected)); button.tabIndex = selected ? 0 : -1;
    });
    document.querySelectorAll('[role="tabpanel"]').forEach(function(panel) {panel.hidden = panel.id !== 'panel-' + key;});
    if (updateHash) history.replaceState(null,'','#' + key);
    document.querySelector('.skip').textContent = 'Skip to ' + (key === 'creatures' ? 'creature list' : key);
    document.title = ({creatures:'Creature inbox', battles:'Battle results', rankings:'Rankings'})[key] + ' · Animal vs Animal';
  }
  var tabButtons = Array.prototype.slice.call(document.querySelectorAll('[data-tab]'));
  tabButtons.forEach(function(button,index) {
    button.addEventListener('click',function(){setTab(button.dataset.tab,true);});
    button.addEventListener('keydown',function(event){
      var next = index;
      if (event.key === 'ArrowRight' || event.key === 'ArrowDown') next = (index+1)%tabButtons.length;
      else if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') next = (index-1+tabButtons.length)%tabButtons.length;
      else if (event.key === 'Home') next = 0;
      else if (event.key === 'End') next = tabButtons.length-1;
      else return;
      event.preventDefault(); tabButtons[next].focus(); setTab(tabButtons[next].dataset.tab,true);
    });
  });
  setTab(location.hash.slice(1),false);
  window.addEventListener('hashchange',function(){setTab(location.hash.slice(1),false);});
  document.querySelector('.refresh').addEventListener('click',function(event){event.preventDefault();location.href='/api/admin/dashboard?refresh='+Date.now()+'#'+active;});

  function timeNode(iso) {var e=text('time',ago(iso),'row-time');e.dateTime=iso;e.title=date(iso);return e;}
  function infoPair(dl, heading, value) { var div=text('div');div.append(text('dt',heading),text('dd',value));dl.append(div); }
  function empty(list, heading, message, filtered, key) {
    var wrap=text('div',null,'empty-state');wrap.append(text('div',filtered?'?':'✦','empty-art'),text('h2',heading),text('p',message));
    if(filtered){var button=text('button','Clear filters');button.type='button';button.addEventListener('click',function(){clear(key);});wrap.append(button);}
    list.append(wrap);
  }
  function pageRows(key, rows, list, createRow) {
    var s=state[key],pages=Math.max(1,Math.ceil(rows.length/s.size));s.page=Math.min(s.page,pages);
    var offset=(s.page-1)*s.size;
    rows.slice(offset,offset+s.size).forEach(function(row,index){list.append(createRow(row,offset+index));});
    var pager=el(({creatures:'creature',battles:'battle',rankings:'ranking'})[key]+'-pager');pager.replaceChildren();
    var status=text('span',rows.length ? number(offset+1)+'–'+number(Math.min(offset+s.size,rows.length))+' of '+number(rows.length) : '0 results','pager-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');pager.append(status);
    var sizeLabel=text('label',null,'page-size');sizeLabel.append(text('span','Per page'));var select=text('select');select.setAttribute('aria-label','Rows per page for '+key);
    [5,10,25,50].forEach(function(size){var o=text('option',String(size));o.value=String(size);o.selected=s.size===size;select.append(o);});
    select.addEventListener('change',function(){s.size=Number(select.value);s.page=1;render(key);pager.querySelector('select').focus({preventScroll:true});});sizeLabel.append(select);pager.append(sizeLabel);
    var controls=text('div',null,'pager-controls');
    var previous=text('button','←','page-button'),next=text('button','→','page-button');previous.type=next.type='button';previous.setAttribute('aria-label','Previous '+key+' page');next.setAttribute('aria-label','Next '+key+' page');previous.disabled=s.page===1;next.disabled=s.page===pages;
    function navigate(direction){s.page+=direction;render(key);var target=pager.querySelector('[aria-label="'+(direction>0?'Next ':'Previous ')+key+' page"]');if(target.disabled)target=pager.querySelector('button:not(:disabled)');if(target)target.focus({preventScroll:true});var top=list.parentElement.getBoundingClientRect().top;if(top<0)list.parentElement.scrollIntoView({block:'start'});}
    previous.addEventListener('click',function(){navigate(-1);});next.addEventListener('click',function(){navigate(1);});
    controls.append(previous,text('span',s.page+' / '+pages,'page-number'),next);pager.append(controls);
  }
  function creatureRow(c,index) {
    var details=text('details',null,'data-row creature-row'),summary=text('summary',null,'row-summary creature-summary');
    var name=text('div',null,'name-cell'),stack=text('div',null,'name-stack');
    var requests=(c.lookupCount||0)+(c.attemptCount||0);
    stack.append(text('strong',c.displayName),text('small',number(requests)+(requests===1?' request':' requests')+' · '+number(c.count)+(c.count===1?' battle':' battles'),'mobile-cell'));
    name.append(text('span',Array.from(c.displayName)[0] || '?','avatar tone-'+index%5),stack);
    summary.append(name,text('span',number((c.lookupCount||0)+(c.attemptCount||0)),'data-number desktop-cell'),text('span',number(c.count),'data-number desktop-cell'),timeNode(c.lastSeen),text('span','›','chevron'));
    var body=text('div',null,'row-details'),dl=text('dl');
    infoPair(dl,'Creature lookups',number(c.lookupCount));infoPair(dl,'Battle requests',number(c.attemptCount));infoPair(dl,'Completed appearances',number(c.count));infoPair(dl,'Wins',number(c.wins));infoPair(dl,'Win rate',c.count?Math.round(c.wins/c.count*100)+'%':'No battles yet');
    infoPair(dl,'First seen',date(c.firstSeen));infoPair(dl,'Last seen',date(c.lastSeen));body.append(dl);
    var opponents=Array.from(new Set((c.opponentNames || []).slice().reverse()));
    if(opponents.length){body.append(text('p','Recent opponents'));var chips=text('div',null,'opponent-list');opponents.forEach(function(o){chips.append(text('span',o,'opponent-chip'));});body.append(chips);}
    else body.append(text('p','No completed cloud battle with this creature on this server yet.'));
    details.append(summary,body);return details;
  }
  function renderCreatures() {
    var query=el('creature-search').value.trim().toLocaleLowerCase(),sort=el('creature-sort').value;
    var rows=d.custom.topCreatures.filter(function(c){return !query || [c.displayName,c.name].concat(c.opponentNames || []).join(' ').toLocaleLowerCase().includes(query);});
    rows.sort(function(a,b){if(sort==='az')return a.displayName.localeCompare(b.displayName);if(sort==='popular')return ((b.lookupCount||0)+(b.attemptCount||0))-((a.lookupCount||0)+(a.attemptCount||0))||Date.parse(b.lastSeen)-Date.parse(a.lastSeen);if(sort==='battles')return b.count-a.count||Date.parse(b.lastSeen)-Date.parse(a.lastSeen);return Date.parse(b.lastSeen)-Date.parse(a.lastSeen)||a.displayName.localeCompare(b.displayName);});
    document.querySelector('[data-clear="creatures"]').hidden=!query;
    var list=el('creature-list');list.replaceChildren();
    if(!rows.length)empty(list,query?'No creature matches that search.':'Your next curious idea lands here.',query?'Try another name or clear your search.':'No typed names are available on this server yet. New accepted cloud lookups and custom battles will appear after you refresh. Earlier names were erased.',!!query,'creatures');
    pageRows('creatures',rows,list,creatureRow);
  }
  function battleRow(r) {
    var details=text('details',null,'data-row battle-row'),summary=text('summary',null,'row-summary battle-summary');
    var stack=text('div',null,'name-stack');stack.append(text('strong',label(r.fighter1)+' vs '+label(r.fighter2)));
    stack.append(text('small',r.mode.toUpperCase()+' · '+(r.environment || 'Default arena')+' · '+ago(r.createdAt)));
    stack.append(text('small','Winner: '+label(r.winner),'winner-inline mobile-cell'));
    var time=timeNode(r.createdAt);time.classList.add('desktop-cell');summary.append(stack,text('span',label(r.winner),'winner-cell desktop-cell'),time,text('span','›','chevron'));
    var body=text('div',null,'row-details'),dl=text('dl');infoPair(dl,'Winner',label(r.winner));infoPair(dl,'Arena',r.environment||'Default arena');infoPair(dl,'Mode',r.mode==='melee'?'Melee summary':r.mode);infoPair(dl,'Time',date(r.createdAt));body.append(dl);
    if(r.fighter1==='custom'||r.fighter2==='custom')body.append(text('p','Historical typed names are not retained with this result.'));
    if(r.mode==='melee')body.append(text('p','Shows the MVP and one opposing fighter.'));
    details.append(summary,body);return details;
  }
  function renderBattles() {
    var query=el('battle-search').value.trim().toLocaleLowerCase(),mode=el('battle-mode').value;
    var rows=d.recent.filter(function(r){return(mode==='all'||r.mode===mode)&&(!query||[label(r.fighter1),label(r.fighter2),label(r.winner),r.environment||'',r.mode].join(' ').toLocaleLowerCase().includes(query));});
    var filtered=!!query||mode!=='all';document.querySelector('[data-clear="battles"]').hidden=!filtered;
    var list=el('battle-list');list.replaceChildren();if(!rows.length)empty(list,filtered?'No results match these filters.':'The arena is quiet.',filtered?'Try another fighter or mode.':'Recorded cloud battles will appear here after you refresh.',filtered,'battles');
    pageRows('battles',rows,list,battleRow);
  }
  function renderRankings() {
    var query=el('ranking-search').value.trim().toLocaleLowerCase(),sort=el('ranking-sort').value;
    var source=sort==='wins'?d.animals.topByWins:sort==='rate'?d.animals.topByWinRate:d.animals.topByPopularity;
    var rows=source.map(function(r,i){return Object.assign({rank:i+1},r);}).filter(function(r){return!query||r.name.toLocaleLowerCase().includes(query);});
    document.querySelector('[data-clear="rankings"]').hidden=!query;
    var list=el('ranking-list');list.replaceChildren();if(!rows.length)empty(list,query?'No ranked creature matches.':'No rankings just yet.',query?'Try another creature name.':'Creatures will rank here as cloud battles are recorded.',!!query,'rankings');
    pageRows('rankings',rows,list,function(r){var row=text('div',null,'ranking-row'),name=text('div',null,'name-cell'),stack=text('div',null,'name-stack');stack.append(text('strong',r.name),text('div',number(r.battles)+' battles · '+number(r.wins)+' wins · '+(r.winRate*100).toFixed(1)+'%','ranking-mobile-meta'));name.append(text('span',String(r.rank).padStart(2,'0'),'rank-number'),stack);row.append(name,text('span',number(r.battles),'data-number desktop-cell'),text('span',number(r.wins),'data-number desktop-cell'),text('span',(r.winRate*100).toFixed(1)+'%','data-number desktop-cell'));var metric=sort==='wins'?number(r.wins):sort==='rate'?(r.winRate*100).toFixed(1)+'%':number(r.battles);row.append(text('span',metric,'rank-metric mobile-cell'));return row;});
  }
  function render(key){({creatures:renderCreatures,battles:renderBattles,rankings:renderRankings})[key]();}
  function clear(key){if(key==='creatures')el('creature-search').value='';if(key==='battles'){el('battle-search').value='';el('battle-mode').value='all';}if(key==='rankings')el('ranking-search').value='';state[key].page=1;render(key);}
  [['creature-search','creatures','input'],['creature-sort','creatures','change'],['battle-search','battles','input'],['battle-mode','battles','change'],['ranking-search','rankings','input'],['ranking-sort','rankings','change']].forEach(function(item){el(item[0]).addEventListener(item[2],function(){state[item[1]].page=1;render(item[1]);});});
  document.querySelectorAll('[data-clear]').forEach(function(button){button.addEventListener('click',function(){clear(button.dataset.clear);});});
  renderCreatures();renderBattles();renderRankings();
}());
`;
