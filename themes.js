// Colour themes. Each one keeps the same four roles: c1 leads (money given, the main glow),
// c2 is the deep partner (documents, reminders), c3 is the cool highlight, c4 the warm spark.
export const THEMES = {
  neel:   { name: 'Neel',   mood: 'Shaant',      c1: '#2F6BFF', c2: '#3341C7', c3: '#14C8B4', c4: '#FFB547', deep: '#3341C7', give: '#2F6BFF', bg: '#EFF2F6', card: '#EAF0F7', shadow: '30, 60, 120',  wing: ['#14215E', '#2F6BFF', '#9EF0E0'], body: '#0E1633', rim: '#CFE3FF', hemi: '#D4E0F5', note: '#5C8BFF' },
  kesar:  { name: 'Kesar',  mood: 'Garam',    c1: '#F2762E', c2: '#0F7C78', c3: '#2BB3A3', c4: '#F5C04A', deep: '#0F7C78', give: '#D9601C', bg: '#F5F1EC', card: '#F6F0E8', shadow: '110, 70, 30',  wing: ['#0B3B3A', '#13968F', '#FFD98A'], body: '#1F1A14', rim: '#FFE1C4', hemi: '#F3E4D2', note: '#3FB8A8' },
  mor:    { name: 'Mor',    mood: 'Taaza',   c1: '#0E9F8E', c2: '#155E9C', c3: '#38BDF8', c4: '#F4B740', deep: '#155E9C', give: '#0B8577', bg: '#EEF3F3', card: '#EBF3F3', shadow: '20, 70, 90',   wing: ['#0B2E4F', '#1F7BC4', '#B8F5E6'], body: '#0B1E2E', rim: '#C9F2EA', hemi: '#D2E6EE', note: '#3AA9D6' },
  gulaal: { name: 'Gulaal', mood: 'Holi ke rang',       c1: '#FF4FA3', c2: '#7B61FF', c3: '#00C2FF', c4: '#FFB547', deep: '#6A55D8', give: '#E0336F', bg: '#F2F1F5', card: '#F1ECF7', shadow: '90, 60, 160',  wing: ['#3B1FA8', '#5B6BFF', '#FFD27A'], body: '#1B1233', rim: '#FFC6EF', hemi: '#D9CCFF', note: '#9D8BFF' },
};
export const DEFAULT_THEME = 'neel';
const KEY = 'titli.theme';
export function savedTheme() {
  try { const t = localStorage.getItem(KEY); if (THEMES[t]) return t } catch { }
  return DEFAULT_THEME;
}
export function saveTheme(t) { try { localStorage.setItem(KEY, t) } catch { } }

// Push a theme into the page's CSS variables.
export function applyTheme(key) {
  const t = THEMES[key], r = document.documentElement.style;
  for (const k of ['c1', 'c2', 'c3', 'c4', 'deep', 'give', 'bg', 'card']) r.setProperty(`--${k}`, t[k]);
  r.setProperty('--shadow', t.shadow);
  r.setProperty('--glow1', hexA(t.c1)); r.setProperty('--glow2', hexA(t.c2));
  document.querySelector('meta[name=theme-color]')?.setAttribute('content', t.bg);
}
const hexA = h => [1, 3, 5].map(i => parseInt(h.slice(i, i + 2), 16)).join(', ');
