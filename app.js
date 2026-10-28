// Titli: bolo, aur Titli yaad rakhegi.
import { createHero } from './hero.js';
import { understand, answer, describe } from './brain.js';
import { THEMES, savedTheme, saveTheme, applyTheme } from './themes.js';

const $ = id => document.getElementById(id);
const app = $('app'), tiles = $('tiles'), greet = $('greet');
const KEY = 'titli.v1';
let theme = savedTheme();
applyTheme(theme);
// tile objects are pre-rendered per theme; the diya stays its own warm colour
const A = n => theme === 'gulaal' || n === 'diya' ? `assets/${n}.png` : `assets/${theme}/${n}.png`;
const inr = n => '₹' + Math.abs(Number(n)).toLocaleString('en-IN');
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const fmt = d => new Date(d).toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
const PEARL = { give: 'pPink', take: 'pCyan', doc: 'pViolet', remind: 'pViolet', note: 'pCyan' };
const GLOW = { give: 'var(--c1)', take: 'var(--c3)', doc: 'var(--c2)', remind: 'var(--c2)', note: 'var(--c3)' };
const MIC = '<svg width="18" height="22" viewBox="0 0 18 22" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"><rect x="5" y="1" width="8" height="13" rx="4" fill="#fff" stroke="none"/><path d="M1.5 10a7.5 7.5 0 0 0 15 0M9 17.5V21"/></svg>';
const STOP = '<svg width="16" height="16"><rect x="2" y="2" width="12" height="12" rx="3" fill="#fff"/></svg>';
const WA = '<svg width="22" height="22" viewBox="0 0 24 24" fill="#fff"><path d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2Zm5.2 13.9c-.2.6-1.3 1.2-1.8 1.2-.5.1-1 .3-3.3-.7-2.8-1.2-4.6-4-4.7-4.2-.1-.2-1.1-1.5-1.1-2.9s.7-2 1-2.3c.2-.3.5-.3.7-.3h.5c.2 0 .4 0 .6.5l.9 2.1c.1.2.1.3 0 .5l-.3.5-.4.5c-.1.1-.3.3-.1.6.2.3.7 1.2 1.6 2 1.1 1 2 1.3 2.3 1.4.3.1.5.1.6-.1l.9-1c.2-.3.4-.2.6-.1l2 1c.3.1.5.2.5.3.1.1.1.7-.1 1.3Z"/></svg>';

// ---------- memories ----------
function seed() {
  const day = n => new Date(Date.now() - n * 864e5).toISOString();
  return [
    ['Kal 10 baje gas cylinder book karna yaad dilana', 0],
    ['Imran se 1200 liye', 4],
    ['Maine Ramesh bhaiya ko do hazaar diye, Diwali tak lautayenge', 10],
    ['Aadhaar card almari ke drawer mein rakha hai', 20],
    ['Maine Ramesh bhaiya ko 1500 diye bacche ki fees ke liye', 49],
  ].map(([raw, ago]) => { const m = understand(raw).memory; m.created = day(ago); m.demo = true; return describe(m) });
}
let mems;
try { mems = JSON.parse(localStorage.getItem(KEY)) } catch { }
if (!Array.isArray(mems)) mems = seed();
const save = () => { try { localStorage.setItem(KEY, JSON.stringify(mems)) } catch { } };

// ---------- hero ----------
let hero = null;
try { hero = createHero($('heroCanvas'), $('heroTags'), THEMES[theme]); hero.setMemories(mems) } catch (e) { console.warn('3D hero unavailable', e) }

// ---------- speech ----------
const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
let rec = null, heard = '', timer = null, started = 0;
function speak(text) {
  if (!('speechSynthesis' in window)) return;
  speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(text); u.lang = 'hi-IN'; u.rate = .95;
  const v = speechSynthesis.getVoices().find(v => /hi[-_]IN/i.test(v.lang)); if (v) u.voice = v;
  speechSynthesis.speak(u);
}
function toast(t) { const e = $('toast'); e.textContent = t; e.classList.add('on'); clearTimeout(e._t); e._t = setTimeout(() => e.classList.remove('on'), 2400) }

function listen() {
  if (!SR) { openTyper(); toast('Is browser mein awaaz nahi chalti. Likh kar batayein.'); return }
  speechSynthesis?.cancel();
  heard = ''; rec = new SR(); rec.lang = 'hi-IN'; rec.interimResults = true; rec.continuous = false;
  rec.onresult = e => { heard = Array.from(e.results).map(r => r[0].transcript).join(' '); renderListen() };
  rec.onerror = e => { if (e.error === 'not-allowed' || e.error === 'service-not-allowed') { toast('Mic ki ijaazat chahiye. Ya likh kar batayein.'); openTyper() } };
  rec.onend = () => { rec = null; clearInterval(timer); if (heard.trim()) handle(heard); else if (app.dataset.mode === 'listen') home() };
  try { rec.start() } catch { return }
  started = Date.now(); clearInterval(timer); timer = setInterval(renderListen, 250);
  setMode('listen'); renderListen();
}
function stopListening() { if (rec) rec.stop() }

// ---------- modes ----------
function setMode(m, focus) {
  app.dataset.mode = m;
  hero?.setMode(m === 'saved' ? 'home' : m, focus);
  $('typer').classList.remove('on');
}
function hello() {
  const h = new Date().getHours();
  return h < 12 ? 'Suprabhat.' : h < 17 ? 'Namaste.' : h < 21 ? 'Shubh sandhya.' : 'Shubh ratri.';
}
function pill(label, icon, action) {
  $('pillLabel').textContent = label; $('orb').innerHTML = icon; $('pill').onclick = action;
}
const tile = (glow, cls, inner, tag = 'div', attrs = '') => `<${tag} class="gt ${cls}" style="--g:${glow}" ${attrs}>${inner}</${tag}>`;

function home() {
  setMode('home');
  $('metaLeft').textContent = new Date().toLocaleDateString('en-IN', { weekday: 'long', day: 'numeric', month: 'long' });
  $('metaLeft').className = ''; $('metaRight').textContent = 'Hindi · Hinglish';
  greet.className = 'greet'; greet.innerHTML = `${hello()}<br><b>Kya yaad rakhein?</b>`;
  $('capLeft').textContent = 'Titli ki udaan'; $('capRight').textContent = `${mems.length} yaadein`;
  const money = mems.filter(m => m.kind === 'give' || m.kind === 'take');
  const out = money.reduce((a, m) => a + (m.kind === 'give' ? m.amount : 0), 0);
  const people = new Set(money.filter(m => m.kind === 'give').map(m => m.person)).size;
  const next = mems.filter(m => m.kind === 'remind').sort((a, b) => (a.dueDate || 'z').localeCompare(b.dueDate || 'z'))[0];
  const docs = mems.filter(m => m.kind === 'doc');
  const recent = mems.slice(0, 3);
  tiles.innerHTML =
    tile('var(--c1)', '', `<div class="lb">Bahar hai</div><img class="obj" src="${A('ring')}" style="width:96px;right:-6px;top:-4px" alt=""><div class="bottom"><div class="big">${inr(out)}</div><div class="lb" style="font-weight:500;margin-top:3px">${people ? `${people} log ke paas` : 'Kisi ke paas nahi'}</div></div>`, 'button', `data-ask="paise"`) +
    (next ? tile('var(--c2)', '', `<div class="lb" style="color:var(--deep)">${esc(next.sub || 'Yaad')}</div><img class="obj" src="${A('gas')}" style="width:74px;right:4px;top:6px" alt=""><div class="bottom mid">${esc(next.title)}</div>`, 'button', `data-focus="${esc(next.created)}"`)
      : tile('var(--c2)', '', `<div class="lb" style="color:var(--deep)">Yaad dilana</div><img class="obj" src="${A('gas')}" style="width:74px;right:4px;top:6px" alt=""><div class="bottom mid" style="color:var(--mute)">“Kal 10 baje bijli bill bharna”</div>`)) +
    tile('var(--c3)', '', `<div class="lb">Kaagaz · ${docs.length}</div><img class="obj" src="${A('card')}" style="width:132px;right:-8px;bottom:-18px" alt="">`, 'button', docs[0] ? `data-focus="${esc(docs[0].created)}"` : '') +
    tile('var(--c4)', '', `<div class="lb">Haal hi mein</div><div class="bottom">${recent.map(m => `<div class="row"><img src="${A(PEARL[m.kind])}" alt=""><span class="t">${esc(m.person || m.doc || m.title)}</span><span class="r" style="color:${m.kind === 'give' ? 'var(--give)' : m.kind === 'take' ? '#1f8f8a' : 'rgba(10,10,11,.5)'}">${m.amount ? (m.kind === 'give' ? '−' : '+') + Number(m.amount).toLocaleString('en-IN') : fmt(m.dueDate || m.created)}</span></div>`).join('') || '<div class="empty">Abhi kuch nahi</div>'}</div>`);
  tiles.querySelectorAll('[data-focus]').forEach(b => b.onclick = () => { const m = mems.find(x => x.created === b.dataset.focus); if (m) showAnswer({ raw: m.title }, { type: m.kind === 'doc' ? 'doc' : 'when', focus: m, entries: [m], say: m.kind === 'doc' ? `${m.doc} ${m.place ? m.place.toLowerCase() + ' mein ' : ''}rakha hai.` : `${m.title}: ${m.sub}.` }) });
  tiles.querySelector('[data-ask]')?.addEventListener('click', () => { const p = money.find(m => m.kind === 'give'); if (p) handle(`${p.person} ko kitna diya?`) });
  pill('Chhuo aur bolo', MIC, listen);
}

function renderListen() {
  const s = Math.floor((Date.now() - started) / 1000);
  $('metaLeft').textContent = `● Sun rahi hoon · 0:${String(s).padStart(2, '0')}`; $('metaLeft').className = 'live';
  $('metaRight').textContent = 'Hindi · Hinglish';
  greet.className = 'greet quote';
  greet.innerHTML = heard ? `“${esc(heard)}”` : '<span style="color:var(--mute)">Boliye… jaise “Ramesh ko do hazaar diye, Diwali tak”</span>';
  $('capLeft').textContent = 'Titli sun rahi hai…'; $('capRight').textContent = '';
  const wave = $('wave'); if (!wave.children.length) wave.innerHTML = '<i></i>'.repeat(18);
  [...wave.children].forEach((i, k) => i.style.height = `${5 + Math.abs(Math.sin(Date.now() / 160 + k * 1.3)) * (heard ? 22 : 8)}px`);
  if (heard) { const p = understand(heard); tiles.innerHTML = p.question ? '' : memoryTiles(p.memory) } else tiles.innerHTML = '';
  pill('Bas, ho gaya', STOP, stopListening);
}

function memoryTiles(m) {
  if (m.kind === 'give' || m.kind === 'take') {
    const p = m.person || 'Kisi';
    return tile(GLOW[m.kind], '', `<div class="lb">${m.kind === 'give' ? 'Kisko' : 'Kisse'}</div><div class="bottom" style="display:flex;align-items:center;gap:10px"><div class="avatar"><img src="${A(PEARL[m.kind])}" alt=""><span>${esc(p[0])}</span></div><div class="mid">${esc(p)}</div></div>`) +
      tile('var(--c2)', '', `<div class="lb">Kitna</div><img class="obj" src="${A('ring')}" style="width:70px;right:4px;top:4px" alt=""><div class="bottom"><div class="big" style="font-size:30px">${inr(m.amount)}</div><div class="lb" style="font-weight:500;margin-top:3px">${m.kind === 'give' ? 'Aapne diye' : 'Aapko lautane hain'}</div></div>`) +
      (m.due ? tile('var(--c4)', 'wide', `<div class="lb">Kab tak</div><img class="obj" src="${A('diya')}" style="width:130px;right:8px;top:-6px" alt=""><div class="bottom"><div class="big" style="font-size:24px">${esc(m.due)}${m.dueDate ? ' · ' + fmt(m.dueDate) : ''}</div>${m.dueDate ? `<div class="chip">${fmt(new Date(new Date(m.dueDate) - 864e5))} ko yaad dilaungi</div>` : ''}</div>`) : '');
  }
  if (m.kind === 'doc') return tile('var(--c2)', 'wide', `<div class="lb">Kaagaz</div><img class="obj" src="${A('card')}" style="width:150px;right:6px;bottom:-14px" alt=""><div class="bottom"><div class="big" style="font-size:24px">${esc(m.doc)}</div><div class="chip">${esc(m.place || 'Jagah nahi batayi')}</div></div>`);
  if (m.kind === 'remind') return tile('var(--c2)', 'wide', `<div class="lb" style="color:var(--deep)">${esc(m.sub || 'Yaad dilana')}</div><img class="obj" src="${A('gas')}" style="width:84px;right:10px;top:8px" alt=""><div class="bottom mid" style="font-size:20px;max-width:70%">${esc(m.what || m.raw)}</div>`);
  return tile('var(--c3)', 'wide', `<div class="lb">Note</div><div class="bottom mid" style="font-size:17px">${esc(m.raw)}</div>`);
}

function handle(text) {
  const p = understand(text);
  if (p.question) return showAnswer(p, answer(p, mems));
  const m = p.memory; mems.unshift(m); save(); hero?.setMemories(mems);
  setMode('saved');
  $('metaLeft').textContent = 'Nayi yaad'; $('metaLeft').className = 'live';
  greet.className = 'greet quote'; greet.innerHTML = `“${esc(text)}”`;
  $('capLeft').textContent = 'Titli ne yaad rakh liya'; $('capRight').textContent = `${mems.length} yaadein`;
  tiles.innerHTML = memoryTiles(m);
  toast('Yaad rakh liya ✓'); speak('Theek hai, yaad rakh liya.');
  pill('Galat hai? Hata dein', '↺', () => { mems = mems.filter(x => x !== m); save(); hero?.setMemories(mems); toast('Hata diya'); home() });
}

function showAnswer(q, a) {
  setMode('answer', a.focus);
  $('metaLeft').textContent = 'Aapne poochha'; $('metaLeft').className = '';
  greet.className = 'greet quote'; greet.innerHTML = esc(q.raw.replace(/\?*$/, '?'));
  $('capLeft').textContent = a.type === 'none' ? 'Titli ko nahi mila' : 'Titli dhoondh laayi'; $('capRight').textContent = a.entries.length ? `${a.entries.length} yaad${a.entries.length > 1 ? 'ein' : ''} mili` : '';
  const say = tile('var(--c2)', 'wide', `<div style="display:flex;align-items:center;gap:12px;position:relative"><button class="play" id="sayBtn" aria-label="Suniye"><img src="${A('play')}" alt=""><svg width="14" height="16" viewBox="0 0 12 12"><path d="M2 1v10l9-5z" fill="#fff"/></svg></button><div style="flex:1"><div class="lb">Titli ka jawaab</div><div class="mid" style="font-size:14px;font-weight:700;margin-top:3px">${esc(a.say)}</div></div></div>`, 'div', 'style="min-height:0"');
  if (a.type === 'money') {
    const label = a.net >= 0 ? `${a.person} · baaki` : `${a.person} ko dene hain`;
    tiles.innerHTML = tile('var(--c1)', 'wide', `<div class="lb">${esc(label)}</div><img class="obj" src="${A('ring')}" style="width:100px;right:8px;top:2px" alt=""><div class="thin">${inr(a.net)}</div><div class="list" style="position:relative;margin-top:10px;border-top:1px solid var(--line)">${a.entries.slice(0, 3).map(m => `<div class="row"><img src="${A(PEARL[m.kind])}" alt=""><span class="t">${fmt(m.created)}${m.due ? ' · ' + esc(m.due) + ' tak' : m.why ? ' · ' + esc(m.why) : ''}</span><span class="r" style="font-weight:800">${m.kind === 'give' ? '' : '−'}${inr(m.amount)}</span></div>`).join('')}</div>`) + say;
    const msg = a.net >= 0 ? `Namaste ${a.person}, ek chhoti si yaad: ${inr(a.net)} baaki hain. Dhanyavaad!` : '';
    if (msg) pill('WhatsApp pe bhejein', WA, () => window.open('https://wa.me/?text=' + encodeURIComponent(msg), '_blank'));
    else pill('Chhuo aur bolo', MIC, listen);
  } else {
    tiles.innerHTML = (a.focus ? memoryTiles(a.focus) : tile('var(--c3)', 'wide', `<div class="lb">Koi yaad nahi mili</div><div class="empty">Pehle boliye, jaise “Aadhaar card almari mein rakha hai”. Phir poochhiye “Aadhaar kahan hai?”</div>`)) + say;
    pill('Chhuo aur bolo', MIC, listen);
  }
  $('sayBtn').onclick = () => speak(a.say);
  speak(a.say);
}

// ---------- typing ----------
function openTyper() { $('typer').classList.add('on'); $('typeInput').focus() }
$('typeBtn').onclick = () => $('typer').classList.contains('on') ? $('typer').classList.remove('on') : openTyper();
$('typer').onsubmit = e => { e.preventDefault(); const v = $('typeInput').value.trim(); if (!v) return; $('typeInput').value = ''; $('typer').classList.remove('on'); handle(v) };
$('back').onclick = home;

// ---------- colour themes ----------
function openThemes(open) {
  $('themeSheet').hidden = $('sheetBack').hidden = !open;
  if (!open) return;
  $('themeList').innerHTML = Object.entries(THEMES).map(([k, t]) =>
    `<button class="theme${k === theme ? ' on' : ''}" data-theme="${k}"><i style="background:conic-gradient(from 200deg, ${t.c1}, ${t.c2}, ${t.c3}, ${t.c4}, ${t.c1})"></i><span><b>${t.name}</b><span>${t.mood}</span></span></button>`).join('');
  $('themeList').querySelectorAll('[data-theme]').forEach(b => b.onclick = () => setTheme(b.dataset.theme));
}
function setTheme(k) {
  theme = k; saveTheme(k); applyTheme(k);
  hero?.setTheme(THEMES[k]);
  openThemes(false);
  if (app.dataset.mode === 'home') home();
  toast(`${THEMES[k].name} rang laga diya`);
}
$('themeBtn').onclick = () => openThemes(true);
$('sheetBack').onclick = () => openThemes(false);

// deep links for demos: ?say=... or ?ask=...
const qs = new URLSearchParams(location.search);
home();
if (qs.get('say')) handle(qs.get('say'));
if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js').catch(() => { });
