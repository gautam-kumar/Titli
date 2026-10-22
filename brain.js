// Understanding Hindi / Hinglish: turn what someone said into a memory, or answer a question from memories.
// Devanagari is transliterated to a loose Latin form first, so "दो हज़ार" and "do hazaar" match the same rules.

const CONS = { 'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'n', 'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'n', 'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n', 'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n', 'प': 'p', 'फ': 'ph', 'ब': 'b', 'भ': 'bh', 'म': 'm', 'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v', 'श': 'sh', 'ष': 'sh', 'स': 's', 'ह': 'h' };
const NUKTA = { 'ज': 'z', 'फ': 'f', 'ड': 'r', 'ढ': 'rh', 'क': 'q', 'ख': 'kh', 'ग': 'g' };
const VOW = { 'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au', 'ऋ': 'ri' };
const MATRA = { 'ा': 'aa', 'ि': 'i', 'ी': 'ee', 'ु': 'u', 'ू': 'oo', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au', 'ृ': 'ri', 'ॉ': 'o' };

export function translit(s) {
  s = s.normalize('NFD').replace(/[०-९]/g, d => String('०१२३४५६७८९'.indexOf(d)));
  const chars = [...s];
  let out = '', word = [];
  // a word is a list of units {c, v, n}: v === null means the inherent schwa, '' means none (virama)
  const flush = () => {
    word.forEach((u, i) => {
      if (u.v !== null) return;
      const prev = word[i - 1], next = word[i + 1];
      if (!next) u.v = '';
      else if (i > 0 && prev.v !== '' && next.v !== null && next.v !== '' && !u.n) u.v = '';
      else u.v = 'a';
    });
    out += word.map(u => u.c + u.v + (u.n || '')).join(''); word = [];
  };
  for (let i = 0; i < chars.length; i++) {
    const c = chars[i];
    if (CONS[c]) {
      let base = CONS[c];
      if (chars[i + 1] === '\u093C') { base = NUKTA[c] || base; i++ }
      const nx = chars[i + 1];
      if (MATRA[nx]) { word.push({ c: base, v: MATRA[nx] }); i++ }
      else if (nx === '्') { word.push({ c: base, v: '' }); i++ }
      else word.push({ c: base, v: null });
    } else if (VOW[c]) word.push({ c: '', v: VOW[c] });
    else if ((c === 'ं' || c === 'ँ') && word.length) word[word.length - 1].n = 'n';
    else if (c === 'ः' && word.length) word[word.length - 1].n = 'h';
    else { flush(); out += c === '।' ? '.' : c }
  }
  flush();
  return out;
}
// loose form for matching: lower case, doubled vowels collapsed, common spelling variants folded
export function loose(s) {
  return translit(s).toLowerCase().replace(/aa/g, 'a').replace(/ee/g, 'i').replace(/oo/g, 'u').replace(/[’'`]/g, '')
    .replace(/w/g, 'v').replace(/\bkard\b/g, 'card').replace(/z/g, 'j').replace(/ph/g, 'f').replace(/[^a-z0-9₹.,?\s-]/g, ' ').replace(/\s+/g, ' ').trim();
}
const title = s => s.replace(/\b[a-z]/g, c => c.toUpperCase());

const NUM = { ek: 1, do: 2, tin: 3, char: 4, panch: 5, pach: 5, chhah: 6, chhe: 6, chhai: 6, che: 6, sat: 7, ath: 8, nau: 9, das: 10, gyarah: 11, barah: 12, pandrah: 15, bis: 20, pachis: 25, tis: 30, chalis: 40, pachas: 50, sath: 60, sattar: 70, assi: 80, nabbe: 90, dedh: 1.5, derh: 1.5, dhai: 2.5, sadhe: 0.5,
  one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, seven: 7, eight: 8, nine: 9, ten: 10, twenty: 20, fifty: 50 };
const MULT = { sau: 100, hundred: 100, hajar: 1000, thousand: 1000, k: 1000, lakh: 100000, lac: 100000, karod: 10000000, crore: 10000000 };

export function parseAmount(l) {
  // digits, optionally followed by a multiplier word: "2000", "2,000", "2 hajar", "1.5 lakh"
  let m = l.match(/(?:₹|rs\.?|rupaye?\s)?\s*(\d[\d,]*(?:\.\d+)?)\s*(sau|hajar|thousand|k\b|lakh|lac|karod|crore)?/);
  if (m) { let v = parseFloat(m[1].replace(/,/g, '')); if (m[2]) v *= MULT[m[2].replace(/\b/g, '')] || 1; if (v >= 1) return Math.round(v) }
  // words: "do hajar", "dhai hajar", "panch sau", "sadhe tin hajar"
  const w = l.split(' '); let best = 0;
  for (let i = 0; i < w.length; i++) {
    if (MULT[w[i]] && i > 0) {
      let n = NUM[w[i - 1]];
      if (n === undefined) continue;
      if (w[i - 2] === 'sadhe') n += .5;
      let v = n * MULT[w[i]];
      // "do hajar panch sau"
      if (w[i + 2] === 'sau' && NUM[w[i + 1]] !== undefined && MULT[w[i]] > 100) v += NUM[w[i + 1]] * 100;
      best = Math.max(best, v);
    }
  }
  return best ? Math.round(best) : 0;
}

const FEST = { divali: ['Diwali', '2026-11-08'], holi: ['Holi', '2027-03-22'], rakhi: ['Rakhi', '2027-08-17'], id: ['Eid', '2027-03-10'], navratri: ['Navratri', '2026-10-11'], chhath: ['Chhath', '2026-11-15'] };
const DAYS = { somvar: 1, mangalvar: 2, budhvar: 3, guruvar: 4, brihaspativar: 4, shukravar: 5, shanivar: 6, ravivar: 0, itvar: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6, sunday: 0 };
const fmt = d => d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });

export function parseWhen(l, now = new Date()) {
  const r = { label: '', date: null };
  for (const k in FEST) if (l.includes(k)) { r.label = FEST[k][0]; r.date = FEST[k][1]; break }
  const d = new Date(now); d.setHours(10, 0, 0, 0);
  if (!r.label) {
    if (/\bparson\b/.test(l)) { d.setDate(d.getDate() + 2); r.label = 'Parson'; r.date = d.toISOString() }
    else if (/\bkal\b/.test(l) && !/(kal\s+(maine|diye|diya|liye|liya|die|lie))/.test(l)) { d.setDate(d.getDate() + 1); r.label = 'Kal'; r.date = d.toISOString() }
    else if (/\baj\b/.test(l)) { r.label = 'Aaj'; r.date = d.toISOString() }
    else if (/agle\s+hafte|next week/.test(l)) { d.setDate(d.getDate() + 7); r.label = 'Agle hafte'; r.date = d.toISOString() }
    else if (/agle\s+mahine|next month/.test(l)) { d.setMonth(d.getMonth() + 1); r.label = 'Agle mahine'; r.date = d.toISOString() }
    else {
      for (const k in DAYS) if (l.includes(k)) { const add = (DAYS[k] - d.getDay() + 7) % 7 || 7; d.setDate(d.getDate() + add); r.label = title(k); r.date = d.toISOString(); break }
      const t = l.match(/(\d{1,2})\s*(tarikh|tarik|date)/);
      if (!r.label && t) { const day = +t[1]; if (day < d.getDate()) d.setMonth(d.getMonth() + 1); d.setDate(day); r.label = fmt(d); r.date = d.toISOString() }
    }
  }
  const tm = l.match(/(\d{1,2})(?::(\d{2}))?\s*baje/) || l.match(/(\d{1,2})(?::(\d{2}))?\s*(am|pm)/);
  if (tm) {
    let h = +tm[1]; if (/shaam|sham|raat|rat|pm/.test(l) && h < 12) h += 12; if (/dopahar/.test(l) && h < 12 && h !== 12) h += 12;
    r.time = `${String(h).padStart(2, '0')}:${tm[2] || '00'}`;
    if (!r.date) { d.setHours(h, +(tm[2] || 0)); if (d < now) d.setDate(d.getDate() + 1); r.label = r.label || 'Aaj'; r.date = d.toISOString() }
  }
  return r;
}

const STOP = new Set(['maine', 'mene', 'mainne', 'main', 'mai', 'ne', 'aj', 'abhi', 'kal', 'to', 'ki', 'ka', 'ke', 'hai', 'hain', 'tha', 'the', 'ek', 'apne', 'apni', 'mera', 'meri', 'mere', 'humne', 'hamne', 'i', 'gave', 'ji', 'mujhe', 'muje', 'hamein', 'humein']);
const DOCS = [['adhar', 'Aadhaar card'], ['adhaar', 'Aadhaar card'], ['aadhar', 'Aadhaar card'], ['pan card', 'PAN card'], ['pan', 'PAN card'], ['passport', 'Passport'], ['rashan', 'Ration card'], ['ration', 'Ration card'], ['licens', 'Driving licence'], ['voter', 'Voter ID'], ['marksheet', 'Marksheet'], ['certificate', 'Certificate'], ['policy', 'Insurance policy'], ['bima', 'Insurance policy'], ['registry', 'Registry'], ['ragistri', 'Registry'], ['fd', 'FD papers'], ['chekbuk', 'Cheque book'], ['cheque', 'Cheque book'], ['passbuk', 'Passbook'], ['passbook', 'Passbook'], ['kagaj', 'Kaagaz'], ['dastavej', 'Kaagaz'], ['vasiyat', 'Will']];

function personBefore(words, idx) {
  const out = [];
  for (let i = idx - 1; i >= 0 && out.length < 2; i--) {
    const w = words[i]; if (STOP.has(w) || /^\d/.test(w) || MULT[w] || NUM[w] !== undefined || /^(rupaye?|rs|₹)$/.test(w)) { if (out.length) break; else continue }
    out.unshift(w);
  }
  return out.length ? title(out.join(' ')).replace(/\bBhaiy?a\b/, 'bhaiya').replace(/\bDidi\b/, 'didi').replace(/\bJi\b/, 'ji') : '';
}
const shortDate = iso => iso ? fmt(new Date(iso)) : '';

export function understand(raw) {
  const l = loose(raw), words = l.replace(/[?.,]/g, ' ').split(/\s+/).filter(Boolean);
  const isQ = /\?$/.test(raw.trim()) || /\b(kitna|kitne|kitni|kahan|kaha|kidhar|kab|kaun|kya|batao|bata|bataiye|dikhao|how much|where|when)\b/.test(l) && !/\b(yad dilana|yad dila|remind)\b/.test(l);
  if (isQ) return { question: true, raw, l, words };
  const amount = parseAmount(l), when = parseWhen(l);
  const m = { raw, created: new Date().toISOString(), kind: 'note' };
  const ko = words.indexOf('ko'), se = words.indexOf('se');
  const give = /\b(diye|diya|die|dia|de diye|de diya|udhar diya|lene hain|lene hai|lena hai|gave|lent)\b/.test(l);
  const take = /\b(liye|liya|lie|lia|le liye|udhar liya|dene hain|dene hai|dena hai|borrowed|owe)\b/.test(l.replace(/\bke li(y)?e\b/g, ''));
  const doc = DOCS.find(([k]) => new RegExp(`\\b${k}`).test(l));
  const remind = /\b(yad dilana|yad dila|yad dilaiye|remind|book karna|bharna|bharni|jama karna|lena hai|karna hai|jana hai)\b/.test(l) || (when.time && !amount);
  if (amount && (give || take)) {
    m.kind = take && !/lene ha|lena ha/.test(l) ? 'take' : 'give';
    m.amount = amount;
    m.person = m.kind === 'give' ? (ko > 0 ? personBefore(words, ko) : se > 0 ? personBefore(words, se) : '') : (se > 0 ? personBefore(words, se) : ko > 0 ? personBefore(words, ko) : '');
    const tak = words.indexOf('tak');
    if (tak > 0) { m.due = when.label || title(words.slice(Math.max(0, tak - 2), tak).join(' ')); m.dueDate = when.date }
    const why = raw.match(/([^\s,।]+\s+(?:ki|ke|ka|की|के|का)\s+[^\s,।]+|[^\s,।]+)\s+(?:ke\s+liye|के\s+लिए)/i);
    if (why) m.why = why[1];
  } else if (doc) {
    m.kind = 'doc'; m.doc = doc[1];
    const soft = /[\u0900-\u097F]/.test(raw) ? translit(raw).toLowerCase().replace(/aa/g, 'a').replace(/ee/g, 'i').replace(/oo/g, 'u').replace(/\bkard\b/g, 'card') : raw.toLowerCase();
    const pm = soft.match(/(?:(?:aa?dhaa?r|pan|ration|voter)\s+card|card|aa?dhaa?r|passport|pan|ration|licen[cs]e|policy|registry|marksheet|certificate|passbook|cheque\s*book|papers?|kaagaz|kagaz)\s+(?:ko\s+|maine\s+|mene\s+)?(.{3,40}?)\s+(?:mein|me|men|par|pe|andar)\b/);
    if (pm) { const p = pm[1].trim(); m.place = p.charAt(0).toUpperCase() + p.slice(1) }
  } else if (remind) {
    m.kind = 'remind';
    m.what = raw.replace(/(yaad\s*dila(na|iye|\s*dena)?|remind\s*me|kal|parson|subah|shaam|\d{1,2}\s*baje)/gi, '').replace(/\s+/g, ' ').trim();
    m.when = when.label; m.time = when.time; m.dueDate = when.date;
  }
  if (amount && m.kind === 'note') m.amount = amount;
  return { question: false, memory: describe(m) };
}

export function describe(m) {
  const inr = n => '₹' + Number(n).toLocaleString('en-IN');
  const c = shortDate(m.created);
  if (m.kind === 'give') { m.title = `${m.person || 'Kisi'} ko ${inr(m.amount)}`; m.sub = [c, m.due && `${m.due} tak`].filter(Boolean).join(' · ') }
  else if (m.kind === 'take') { m.title = `${m.person || 'Kisi'} ke ${inr(m.amount)} dene`; m.sub = [c, m.due && `${m.due} tak`].filter(Boolean).join(' · ') }
  else if (m.kind === 'doc') { m.title = m.doc; m.sub = m.place || c }
  else if (m.kind === 'remind') { m.title = (m.what || m.raw).slice(0, 34); m.sub = [m.when, m.time].filter(Boolean).join(' · ') || c }
  else { m.title = m.raw.length > 30 ? m.raw.slice(0, 30) + '…' : m.raw; m.sub = c }
  return m;
}

// ---------- answering ----------
function matchPerson(mems, words) {
  const people = [...new Set(mems.filter(m => m.person).map(m => m.person))];
  let best = null, score = 0;
  for (const p of people) {
    const pw = loose(p).split(' ');
    const s = pw.reduce((a, w) => a + (words.some(x => x.length > 2 && (x.startsWith(w.slice(0, 4)) || w.startsWith(x.slice(0, 4)))) ? 1 : 0), 0);
    if (s > score) { score = s; best = p }
  }
  return best;
}
export function answer(q, mems) {
  const l = q.l || loose(q.raw), words = q.words || l.replace(/[?.,]/g, ' ').split(/\s+/).filter(Boolean);
  const person = matchPerson(mems, words);
  if (person) {
    const es = mems.filter(m => m.person === person && (m.kind === 'give' || m.kind === 'take'));
    if (es.length) {
      const net = es.reduce((a, m) => a + (m.kind === 'give' ? m.amount : -m.amount), 0);
      const lead = es[0];
      return { type: 'money', person, net, entries: es, focus: lead,
        say: net >= 0 ? `${person} se ${net.toLocaleString('en-IN')} rupaye lene baaki hain.` : `Aapko ${person} ko ${(-net).toLocaleString('en-IN')} rupaye dene hain.` };
    }
  }
  if (/\b(kahan|kaha|kidhar|where|rakha|rakhi|rakhe)\b/.test(l)) {
    const doc = DOCS.find(([k]) => new RegExp(`\\b${k}`).test(l));
    const hit = mems.find(m => m.kind === 'doc' && (!doc || m.doc === doc[1])) ;
    if (hit) return { type: 'doc', focus: hit, entries: [hit], say: `${hit.doc} ${hit.place ? hit.place.toLowerCase() + ' mein ' : ''}rakha hai.` };
  }
  if (/\b(kab|when)\b/.test(l) || /\b(yad|reminder)\b/.test(l)) {
    const rs = mems.filter(m => m.kind === 'remind' || m.due).sort((a, b) => (a.dueDate || 'z').localeCompare(b.dueDate || 'z'));
    const scored = rs.map(m => [m, words.filter(w => w.length > 2 && loose(m.raw).includes(w)).length]).sort((a, b) => b[1] - a[1]);
    const hit = scored[0] && scored[0][0];
    if (hit) return { type: 'when', focus: hit, entries: [hit], say: `${hit.title}: ${hit.sub}.` };
  }
  // fall back to the memory sharing the most words with the question
  const scored = mems.map(m => [m, words.filter(w => w.length > 2 && !STOP.has(w) && loose(m.raw).includes(w)).length]).sort((a, b) => b[1] - a[1]);
  if (scored[0] && scored[0][1] > 0) { const hit = scored[0][0]; return { type: 'note', focus: hit, entries: [hit], say: hit.raw } }
  return { type: 'none', entries: [], say: 'Iske baare mein mujhe abhi kuch yaad nahi hai.' };
}
