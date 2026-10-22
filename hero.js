// The live hero: a 3D titli whose aurora flight trail carries your latest memories as pearls.
import * as THREE from './vendor/three.module.min.js';
import { RoomEnvironment } from './vendor/RoomEnvironment.js';

const STOPS = ['#00C2FF', '#7B61FF', '#FF4FA3', '#FFB547'].map(c => new THREE.Color(c));
export const KIND_COLOR = { give: 0xff4fa3, take: 0x00c2ff, doc: 0x7b61ff, remind: 0xffb547, note: 0x9d8bff };

function canvasTex(w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h; draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
function shadowBlob(r, op, col) {
  const t = canvasTex(256, 256, x => { const g = x.createRadialGradient(128, 128, 0, 128, 128, 128); g.addColorStop(0, `rgba(${col},${op})`); g.addColorStop(.5, `rgba(${col},${op * .45})`); g.addColorStop(1, `rgba(${col},0)`); x.fillStyle = g; x.fillRect(0, 0, 256, 256) });
  const m = new THREE.Mesh(new THREE.PlaneGeometry(r * 2, r * 2), new THREE.MeshBasicMaterial({ map: t, transparent: true, depthWrite: false })); m.rotation.x = -Math.PI / 2; return m;
}

function buildButterfly() {
  const fore = new THREE.Shape(); fore.moveTo(.04, .06); fore.bezierCurveTo(.25, .55, .7, 1.02, 1.12, .98); fore.bezierCurveTo(1.32, .95, 1.36, .7, 1.22, .5); fore.bezierCurveTo(1.0, .2, .55, .02, .06, -.04); fore.lineTo(.04, .06);
  const hind = new THREE.Shape(); hind.moveTo(.05, -.02); hind.bezierCurveTo(.5, .02, .92, -.12, .95, -.42); hind.bezierCurveTo(.98, -.72, .75, -.98, .48, -.95); hind.bezierCurveTo(.3, -.93, .22, -.8, .17, -.62); hind.bezierCurveTo(.12, -.42, .06, -.22, .04, -.08);
  const X0 = -.05, X1 = 1.4, Y0 = -1.05, Y1 = 1.1;
  const tex = canvasTex(1024, 1536, (x, w, h) => {
    const P = (a, b) => [(a - X0) / (X1 - X0) * w, (Y1 - b) / (Y1 - Y0) * h];
    const outline = sh => { x.beginPath(); sh.getPoints(80).forEach((pt, i) => { const [a, b] = P(pt.x, pt.y); i ? x.lineTo(a, b) : x.moveTo(a, b) }); x.closePath() };
    const draw = (sh, stops) => {
      x.save(); outline(sh); x.clip();
      const [bx, by] = P(0, 0); const g = x.createRadialGradient(bx, by, 10, bx, by, w); stops.forEach(([o, c]) => g.addColorStop(o, c)); x.fillStyle = g; x.fillRect(0, 0, w, h);
      const g2 = x.createLinearGradient(0, 0, w, h); g2.addColorStop(0, 'rgba(0,194,255,0)'); g2.addColorStop(.45, 'rgba(0,194,255,.28)'); g2.addColorStop(.6, 'rgba(255,255,255,.18)'); g2.addColorStop(1, 'rgba(255,181,71,0)'); x.fillStyle = g2; x.fillRect(0, 0, w, h);
      x.strokeStyle = 'rgba(40,20,90,.35)'; x.lineWidth = 3;
      for (let k = 0; k < 7; k++) { const a = -1.1 + k * .36; x.beginPath(); x.moveTo(bx, by); x.quadraticCurveTo(bx + Math.cos(a) * w * .35, by - Math.sin(a) * h * .25, bx + Math.cos(a) * w * 1.2, by - Math.sin(a) * h * .9); x.stroke() }
      x.restore(); outline(sh); x.lineWidth = 26; x.strokeStyle = 'rgba(30,16,60,.9)'; x.stroke(); x.lineWidth = 6; x.strokeStyle = 'rgba(255,255,255,.5)'; x.stroke();
    };
    draw(fore, [[0, '#3b1fa8'], [.25, '#7B61FF'], [.55, '#FF4FA3'], [.85, '#FFB547'], [1, '#ffd27a']]);
    draw(hind, [[0, '#3b1fa8'], [.25, '#5b6bff'], [.5, '#00C2FF'], [.8, '#FF4FA3'], [1, '#FFB547']]);
    x.fillStyle = 'rgba(255,255,255,.9)';
    for (const [a, b, r] of [[1.12, .82, .035], [1.02, .9, .025], [1.2, .66, .028], [.8, -.78, .03]]) { const [px, py] = P(a, b); x.beginPath(); x.arc(px, py, r * w / (X1 - X0), 0, 7); x.fill() }
  });
  const mat = new THREE.MeshPhysicalMaterial({ map: tex, side: THREE.DoubleSide, transparent: true, roughness: .35, clearcoat: .7, clearcoatRoughness: .2, iridescence: .35, iridescenceIOR: 1.4, envMapIntensity: .55 });
  const wingGeo = sh => {
    const g = new THREE.ShapeGeometry(sh, 48), P = g.attributes.position, uv = g.attributes.uv;
    for (let i = 0; i < P.count; i++) { const a = P.getX(i), b = P.getY(i); uv.setXY(i, (a - X0) / (X1 - X0), (b - Y0) / (Y1 - Y0)); P.setZ(i, .12 * a * a - .04 * b * b) }
    g.computeVertexNormals(); return g;
  };
  const half = () => { const g = new THREE.Group(); const f = new THREE.Mesh(wingGeo(fore), mat), h = new THREE.Mesh(wingGeo(hind), mat); h.position.z = -.01; g.add(f, h); return g };
  const R = half(), L = half(); L.scale.x = -1;
  const b = new THREE.Group(); b.add(R, L);
  const dark = new THREE.MeshPhysicalMaterial({ color: 0x1b1233, roughness: .3, clearcoat: 1, iridescence: .6 });
  b.add(new THREE.Mesh(new THREE.LatheGeometry([[0, -.62], [.025, -.58], [.045, -.4], [.05, -.15], [.04, 0], [.058, .1], [.06, .18], [.04, .24], [0, .26]].map(([a, c]) => new THREE.Vector2(a, c)), 32), dark));
  const head = new THREE.Mesh(new THREE.SphereGeometry(.08, 32, 24), dark); head.position.y = .3; head.scale.setScalar(.75); b.add(head);
  for (const sx of [1, -1]) {
    const c = new THREE.CatmullRomCurve3([new THREE.Vector3(sx * .02, .3, 0), new THREE.Vector3(sx * .12, .6, .05), new THREE.Vector3(sx * .28, .85, .08)]);
    b.add(new THREE.Mesh(new THREE.TubeGeometry(c, 24, .009, 8), dark));
    const tip = new THREE.Mesh(new THREE.SphereGeometry(.03, 16, 12), dark); tip.position.copy(c.getPoint(1)); b.add(tip);
  }
  return { group: b, R, L };
}

function ribbon(path, off, width, twist, op) {
  const N = 300, M = 18, pos = [], col = [], uv = [], idx = [], up = new THREE.Vector3(0, 1, 0), c = new THREE.Color();
  for (let i = 0; i <= N; i++) {
    const t = i / N, p = path.getPointAt(t), tg = path.getTangentAt(t);
    const side = new THREE.Vector3().crossVectors(tg, up).normalize(), nrm = new THREE.Vector3().crossVectors(side, tg).normalize();
    const a = twist * Math.sin(t * 5 + off) + off * .5, dir = nrm.clone().multiplyScalar(Math.cos(a)).add(side.clone().multiplyScalar(Math.sin(a)));
    const w = width * Math.sin(Math.PI * Math.min(t, .999) * .5) * (1 - .85 * t * t);
    const u = t * 2.999, k = Math.floor(u); c.copy(STOPS[k]).lerp(STOPS[Math.min(3, k + 1)], u - k);
    for (let j = 0; j <= M; j++) { const q = p.clone().addScaledVector(dir, (j / M - .5) * w).addScaledVector(side, off * .04); pos.push(q.x, q.y, q.z); col.push(c.r, c.g, c.b); uv.push(t, j / M) }
  }
  for (let i = 0; i < N; i++) for (let j = 0; j < M; j++) { const a = i * (M + 1) + j, b = a + M + 1; idx.push(a, b, a + 1, b, b + 1, a + 1) }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3)); g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g.setIndex(idx);
  const m = new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, depthTest: false, side: THREE.DoubleSide, vertexColors: true, uniforms: { op: { value: op }, time: { value: 0 }, upto: { value: 1 } },
    vertexShader: `varying vec3 vC;varying vec2 vU;void main(){vC=color;vU=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.);}`,
    fragmentShader: `varying vec3 vC;varying vec2 vU;uniform float op;uniform float time;uniform float upto;void main(){if(vU.x>upto)discard;float e=sin(vU.y*3.14159);float strand=.5+.5*pow(abs(sin(vU.y*40.+time*.6)),.6);float fade=smoothstep(0.,.25,vU.x);float shimmer=.85+.15*sin(vU.x*30.-time*3.);gl_FragColor=vec4(vC,op*pow(e,.9)*strand*fade*shimmer);}`
  });
  const mesh = new THREE.Mesh(g, m); mesh.renderOrder = 5; return mesh;
}

export function createHero(canvas, labelLayer) {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(2, devicePixelRatio || 1)); renderer.toneMapping = THREE.ACESFilmicToneMapping;
  const scene = new THREE.Scene();
  scene.environment = new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(renderer), .04).texture;
  scene.add(new THREE.HemisphereLight(0xffffff, 0xd9ccff, .8));
  const key = new THREE.DirectionalLight(0xffffff, 1.5); key.position.set(-3, 5, 4); scene.add(key);
  const rim = new THREE.DirectionalLight(0xffc6ef, 1.0); rim.position.set(3, 1, -3); scene.add(rim);
  const camera = new THREE.PerspectiveCamera(30, 1, .1, 100);

  const bf = buildButterfly(); const bfly = bf.group;
  bfly.rotation.set(.55, .3, -.42); bfly.scale.setScalar(.7); bfly.position.set(.12, .18, 0); scene.add(bfly);
  const trailPts = [[-2.5, -.9, .4], [-1.8, .1, .7], [-1.0, -.7, 1.0], [-.2, -.8, .8], [.2, -.35, .3], [.2, .08, 0]].map(p => new THREE.Vector3(...p));
  const path = new THREE.CatmullRomCurve3(trailPts, false, 'catmullrom', .5);
  const ribbons = [[0, .9, .9, .6], [1.5, .6, 1.1, .5], [2.9, .4, .7, .6], [4.1, 1.3, .5, .16]].map(a => { const m = ribbon(path, ...a); scene.add(m); return m });
  const shadow = shadowBlob(1.1, .22, '70,40,140'); shadow.position.y = -1.25; scene.add(shadow);

  // pearls for memories along the trail
  const pearlGroup = new THREE.Group(); scene.add(pearlGroup);
  let pearls = [], labels = [], mode = 'home', big = null;
  const pearlMat = c => new THREE.MeshPhysicalMaterial({ color: c, roughness: .1, clearcoat: 1, iridescence: .5, depthTest: false });
  function setMemories(mems) {
    pearlGroup.clear(); pearls = []; labelLayer.innerHTML = ''; labels = [];
    const ts = [.62, .22, .42, .08, .32];
    mems.slice(0, 5).forEach((m, i) => {
      const c = KIND_COLOR[m.kind] || KIND_COLOR.note, s = i === 0 ? .1 : .08;
      const mesh = new THREE.Mesh(new THREE.SphereGeometry(s, 40, 28), pearlMat(c)); mesh.renderOrder = 6; mesh.userData.t = ts[i];
      const halo = new THREE.Mesh(new THREE.RingGeometry(s * 1.6, s * 1.72, 48), new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: .6, side: THREE.DoubleSide, depthTest: false })); halo.renderOrder = 6; mesh.add(halo);
      pearlGroup.add(mesh); pearls.push(mesh);
      if (i < 2) { const e = document.createElement('div'); e.className = 'tag'; e.innerHTML = `<b>${m.title}</b><span>${m.sub}</span>`; labelLayer.appendChild(e); labels.push({ e, mesh, dy: i === 0 ? 34 : -30 }) }
    });
  }
  function setMode(m, focusMem) {
    mode = m;
    if (big) { scene.remove(big); big = null }
    if (m === 'answer' && focusMem) {
      const c = KIND_COLOR[focusMem.kind] || KIND_COLOR.note;
      big = new THREE.Mesh(new THREE.SphereGeometry(.42, 64, 48), new THREE.MeshPhysicalMaterial({ color: c, roughness: .08, clearcoat: 1, iridescence: .6, iridescenceIOR: 1.4 }));
      big.position.set(1.1, -.1, .6);
      const ring = new THREE.Mesh(new THREE.TorusGeometry(.62, .006, 8, 128), new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: .6 })); ring.rotation.set(1.2, .2, 0); big.add(ring);
      scene.add(big);
    }
  }

  function resize() {
    const w = canvas.clientWidth, h = canvas.clientHeight; if (!w || !h) return;
    renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix();
  }
  new ResizeObserver(resize).observe(canvas); resize();

  const v = new THREE.Vector3(), clock = new THREE.Clock();
  let drawT = 1;
  function frame() {
    const t = clock.getElapsedTime();
    // camera framing per mode
    const ans = mode === 'answer', tgt = new THREE.Vector3(ans ? -.5 : -.7, -.2, 0);
    const k = 2 * Math.tan(THREE.MathUtils.degToRad(camera.fov / 2));
    const dist = Math.max((ans ? 3.1 : 2.9) / k, (ans ? 5.6 : 4.5) / (k * camera.aspect));
    camera.position.set(tgt.x, tgt.y + .35, tgt.z + dist); camera.lookAt(tgt);
    // flap + float
    const flap = Math.sin(t * (mode === 'listen' ? 9 : 4.2)) * (mode === 'listen' ? .5 : .32);
    bf.R.rotation.y = -.42 - flap; bf.L.rotation.y = .42 + flap;
    const ax = mode === 'answer' ? -.6 : .12, ay = mode === 'answer' ? .25 : .18, sc = mode === 'answer' ? .6 : .7;
    bfly.position.set(ax, ay + Math.sin(t * 1.3) * .06, 0); bfly.scale.setScalar(sc);
    ribbons.forEach(r => { r.material.uniforms.time.value = t; r.material.uniforms.upto.value = mode === 'listen' ? drawT : 1 });
    if (mode === 'listen') drawT = .55 + .45 * ((t * .25) % 1); else drawT = 1;
    pearls.forEach((p, i) => { const tt = p.userData.t; p.position.copy(path.getPointAt(tt)); p.position.y += Math.sin(t * 1.6 + i) * .03; p.children[0].lookAt(camera.position); p.visible = mode !== 'listen' || i !== 0 });
    if (big) { big.position.y = -.1 + Math.sin(t * 1.2) * .05; big.rotation.y = t * .3 }
    renderer.render(scene, camera);
    const W = canvas.clientWidth, H = canvas.clientHeight;
    labels.forEach(l => {
      const show = mode === 'home'; l.e.style.opacity = show ? 1 : 0;
      v.copy(l.mesh.position).project(camera); const x = (v.x * .5 + .5) * W, y = (-v.y * .5 + .5) * H;
      const w = l.e.offsetWidth, h = l.e.offsetHeight; const X = Math.max(8, Math.min(W - w - 8, x + 18)), Y = Math.max(30, Math.min(H - h - 8, y - h / 2 + l.dy));
      l.e.style.transform = `translate(${X}px,${Y}px)`;
    });
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
  return { setMemories, setMode };
}
