// Обложка игры (1920×1080) и иконка (512×512) из сцены tools/marketing/scene.luau.
// Полигональный рендер с перспективой: плоские детали (земля, дорога) со студами,
// затем объёмные детали по глубине; сверху — выстрелы, полоски HP и заголовок.
// Запуск: node tools/marketing/thumbnail.js <папка со scene.json> [путь к fredoka.ttf]
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const dir = process.argv[2];
const fontPath = process.argv[3] || path.join(dir, 'fredoka.ttf');
const font = fs.existsSync(fontPath) ? fs.readFileSync(fontPath).toString('base64') : '';

const page = `
function shapePolys(s) {
  const P = [];
  const quad = (a, b, c, d) => P.push([a, b, c, d]);
  if (s === 'Block' || s === 'Head') {
    const v = [[-.5,-.5,-.5],[.5,-.5,-.5],[.5,.5,-.5],[-.5,.5,-.5],[-.5,-.5,.5],[.5,-.5,.5],[.5,.5,.5],[-.5,.5,.5]];
    quad(v[0],v[1],v[2],v[3]); quad(v[5],v[4],v[7],v[6]); quad(v[4],v[0],v[3],v[7]);
    quad(v[1],v[5],v[6],v[2]); quad(v[3],v[2],v[6],v[7]); quad(v[4],v[5],v[1],v[0]);
  } else if (s === 'Wedge') {
    const a=[-.5,-.5,-.5], b=[.5,-.5,-.5], c=[.5,-.5,.5], d=[-.5,-.5,.5], e=[.5,.5,.5], f=[-.5,.5,.5];
    quad(a,b,c,d); quad(d,c,e,f); quad(a,f,e,b); P.push([a,d,f]); P.push([b,e,c]);
  } else if (s === 'Cylinder') {
    const n = 14, ring = x => Array.from({length: n}, (_, i) => [x, .5*Math.cos(i/n*2*Math.PI), .5*Math.sin(i/n*2*Math.PI)]);
    const r0 = ring(-.5), r1 = ring(.5);
    for (let i = 0; i < n; i++) { const j = (i+1)%n; quad(r0[i], r0[j], r1[j], r1[i]); }
    P.push(r0.slice().reverse()); P.push(r1);
  } else {
    const la = 8, lo = 12, pt = (i, j) => { const t = i/la*Math.PI, p = j/lo*2*Math.PI; return [.5*Math.sin(t)*Math.cos(p), .5*Math.cos(t), .5*Math.sin(t)*Math.sin(p)]; };
    for (let i = 0; i < la; i++) for (let j = 0; j < lo; j++) quad(pt(i,j), pt(i,j+1), pt(i+1,j+1), pt(i+1,j));
  }
  return P;
}
const sub = (a, b) => [a[0]-b[0], a[1]-b[1], a[2]-b[2]];
const add = (a, b) => [a[0]+b[0], a[1]+b[1], a[2]+b[2]];
const mulv = (a, k) => [a[0]*k, a[1]*k, a[2]*k];
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const dot = (a, b) => a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
const norm = a => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0]/l, a[1]/l, a[2]/l]; };
function world(part, v) {
  const m = part.m, sx = part.size[0]*v[0], sy = part.size[1]*v[1], sz = part.size[2]*v[2];
  return [m[0] + m[3]*sx + m[4]*sy + m[5]*sz, m[1] + m[6]*sx + m[7]*sy + m[8]*sz, m[2] + m[9]*sx + m[10]*sy + m[11]*sz];
}
function makeCamera(eye, target, fov, W, H) {
  const f = norm(sub(target, eye)), r = norm(cross(f, [0,1,0])), u = cross(r, f);
  const k = (H / 2) / Math.tan(fov * Math.PI / 360);
  return {
    eye, depth: p => dot(sub(p, eye), f),
    project: p => { const d = sub(p, eye); const z = dot(d, f); return [W / 2 + dot(d, r) / z * k, H / 2 - dot(d, u) / z * k, z]; },
  };
}
const LIGHT = norm([-0.45, 1, -0.35]);
function shadeColor(c, s) { return 'rgb(' + c.map(v => Math.max(0, Math.min(255, Math.round(v * s)))).join(',') + ')'; }
function polysOf(parts, cam) {
  const out = [];
  for (const part of parts) {
    const center = [part.m[0], part.m[1], part.m[2]];
    for (const poly of shapePolys(part.s)) {
      const wp = poly.map(v => world(part, v));
      const fc = mulv(wp.reduce((a, b) => add(a, b), [0, 0, 0]), 1 / wp.length);
      let n = norm(sub(fc, center));
      if (Math.hypot(...sub(fc, center)) < 1e-6) n = [0, 1, 0];
      if (dot(n, sub(cam.eye, fc)) <= 0) continue;
      const pr = wp.map(cam.project);
      if (pr.some(p => p[2] < 0.5)) continue;
      const shade = part.neon ? 1.2 : 0.62 + 0.42 * Math.max(0, dot(n, LIGHT));
      out.push({ pr, depth: cam.depth(fc), top: Math.max(...wp.map(p => p[1])), part, n, wp, fc });
    }
  }
  return out;
}
function drawPoly(ctx, p, fill, stroke) {
  ctx.beginPath();
  p.pr.forEach((q, i) => i ? ctx.lineTo(q[0], q[1]) : ctx.moveTo(q[0], q[1]));
  ctx.closePath();
  ctx.fillStyle = fill; ctx.fill();
  if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = 0.8; ctx.stroke(); }
}
function studs(ctx, p, cam) {
  // Студы на верхней грани плоской детали: кружок на каждом стаде 1×1
  const part = p.part, sx = part.size[0], sz = part.size[2];
  if (sx * sz > 400 || p.n[1] < 0.9) return;
  const top = part.m[1] + part.size[1] / 2;
  for (let i = 0; i < Math.floor(sx); i++) for (let j = 0; j < Math.floor(sz); j++) {
    const lx = -sx / 2 + i + 0.5, lz = -sz / 2 + j + 0.5;
    const c = [part.m[0] + part.m[3] * lx + part.m[5] * lz, top + 0.02, part.m[2] + part.m[9] * lx + part.m[11] * lz];
    const a = cam.project(c), b = cam.project(add(c, [0.32, 0, 0])), d = cam.project(add(c, [0, 0, 0.32]));
    const rx = Math.hypot(b[0] - a[0], b[1] - a[1]), ry = Math.abs(d[1] - a[1]) + 0.2;
    if (rx < 0.9) continue;
    ctx.beginPath(); ctx.ellipse(a[0], a[1] + ry * 0.35, rx, Math.max(ry, rx * 0.25), 0, 0, Math.PI * 2);
    ctx.fillStyle = 'rgba(0,0,0,0.22)'; ctx.fill();
    ctx.beginPath(); ctx.ellipse(a[0], a[1], rx, Math.max(ry, rx * 0.25), 0, 0, Math.PI * 2);
    ctx.fillStyle = shadeColor(part.c, 1.12); ctx.fill();
  }
}
function renderScene(ctx, scene, cam, W, H) {
  const sky = ctx.createLinearGradient(0, 0, 0, H);
  sky.addColorStop(0, '#5fb6ff'); sky.addColorStop(0.55, '#bfe5ff'); sky.addColorStop(1, '#d9f1ff');
  ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);
  // Бесконечная зелёная плита до горизонта
  const far = [[-900, -0.05, -900], [900, -0.05, -900], [900, -0.05, 900], [-900, -0.05, 900]].map(cam.project);
  if (far.every(p => p[2] > 0)) { ctx.beginPath(); far.forEach((q, i) => i ? ctx.lineTo(q[0], q[1]) : ctx.moveTo(q[0], q[1])); ctx.fillStyle = '#3f8a3f'; ctx.fill(); }
  const polys = polysOf(scene.parts, cam);
  const flat = polys.filter(p => p.part.flat).sort((a, b) => (a.top - b.top) || (b.depth - a.depth));
  for (const p of flat) {
    const s = p.part.neon ? 1.2 : 0.62 + 0.42 * Math.max(0, dot(p.n, LIGHT));
    drawPoly(ctx, p, shadeColor(p.part.c, s), null);
    if (p.part.studs) studs(ctx, p, cam);
  }
  // Пятна теней под объёмными моделями
  const solid = polys.filter(p => !p.part.flat).sort((a, b) => b.depth - a.depth);
  for (const p of solid) {
    const s = p.part.neon ? 1.2 : 0.62 + 0.42 * Math.max(0, dot(p.n, LIGHT));
    drawPoly(ctx, p, shadeColor(p.part.c, s), 'rgba(0,0,0,0.35)');
  }
}
function strokeText(ctx, text, x, y, size, fill, stroke, align, lw) {
  ctx.font = size + 'px "Fredoka One"'; ctx.textAlign = align || 'center'; ctx.textBaseline = 'alphabetic';
  ctx.lineJoin = 'round'; ctx.miterLimit = 2;
  ctx.lineWidth = lw || size * 0.16; ctx.strokeStyle = stroke || '#000'; ctx.strokeText(text, x, y);
  ctx.fillStyle = fill; ctx.fillText(text, x, y);
}
function effects(ctx, scene, cam, scale) {
  const COLORS = { pistol: '#ffe27a', minigunner: '#ffb347', sniper: '#c9a7ff', archer: '#8b5a2b', toxic: '#7dff5a' };
  for (const s of scene.shots) {
    const color = COLORS[s.tower];
    if (!color) continue;
    const a = cam.project(s.from), b = cam.project(s.to);
    if (s.tower === 'toxic') {
      ctx.beginPath(); ctx.arc(b[0], b[1], 34 * scale, 0, Math.PI * 2); ctx.fillStyle = 'rgba(110,255,80,0.45)'; ctx.fill();
      ctx.beginPath(); ctx.arc(a[0] + (b[0] - a[0]) * 0.55, a[1] + (b[1] - a[1]) * 0.55 - 20 * scale, 9 * scale, 0, Math.PI * 2); ctx.fillStyle = '#7dff5a'; ctx.fill();
      ctx.lineWidth = 3; ctx.strokeStyle = '#000'; ctx.stroke();
      continue;
    }
    ctx.lineCap = 'round';
    ctx.strokeStyle = 'rgba(0,0,0,0.45)'; ctx.lineWidth = (s.tower === 'sniper' ? 9 : 6) * scale;
    ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke();
    ctx.strokeStyle = color; ctx.lineWidth = (s.tower === 'sniper' ? 5 : 3) * scale;
    ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke();
    ctx.beginPath(); ctx.arc(a[0], a[1], 10 * scale, 0, Math.PI * 2); ctx.fillStyle = 'rgba(255,240,170,0.9)'; ctx.fill();
  }
}
function hpBars(ctx, scene, cam, scale) {
  for (const e of scene.enemies) {
    const p = cam.project(e.at);
    const w = (e.boss ? 230 : e.elite ? 120 : 84) * scale, h = (e.boss ? 26 : 17) * scale;
    const x = p[0] - w / 2, y = p[1] - h;
    if (e.boss || e.elite) strokeText(ctx, e.name, p[0], y - 8 * scale, (e.boss ? 30 : 20) * scale, e.boss ? '#ff4b4b' : '#ffa53a', '#000', 'center', 6 * scale);
    ctx.fillStyle = '#000'; roundRect(ctx, x - 3 * scale, y - 3 * scale, w + 6 * scale, h + 6 * scale, 7 * scale); ctx.fill();
    ctx.fillStyle = '#2a2a2a'; roundRect(ctx, x, y, w, h, 5 * scale); ctx.fill();
    const g = ctx.createLinearGradient(0, y, 0, y + h); g.addColorStop(0, e.boss ? '#ff7373' : '#7bff7b'); g.addColorStop(1, e.boss ? '#c41c1c' : '#2fa83b');
    ctx.fillStyle = g; roundRect(ctx, x, y, w * e.hp, h, 5 * scale); ctx.fill();
    const max = e.boss ? 1100 : e.elite ? 300 : 60;
    strokeText(ctx, String(Math.round(max * e.hp)), p[0], y + h - 3 * scale, h * 0.95, '#fff', '#000', 'center', 5 * scale);
  }
}
function roundRect(ctx, x, y, w, h, r) { ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r); ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath(); }
function sticker(ctx, text, x, y, size, bg, rot) {
  ctx.save(); ctx.translate(x, y); ctx.rotate(rot);
  ctx.font = size + 'px "Fredoka One"';
  const w = ctx.measureText(text).width + size * 1.1, h = size * 1.45;
  ctx.fillStyle = '#000'; roundRect(ctx, -w / 2 - 6, -h / 2 - 6, w + 12, h + 12, h * 0.35); ctx.fill();
  const g = ctx.createLinearGradient(0, -h / 2, 0, h / 2); g.addColorStop(0, bg[0]); g.addColorStop(1, bg[1]);
  ctx.fillStyle = g; roundRect(ctx, -w / 2, -h / 2, w, h, h * 0.3); ctx.fill();
  ctx.textBaseline = 'middle'; strokeText(ctx, text, 0, size * 0.36, size, '#fff', '#000', 'center', size * 0.18);
  ctx.restore();
}
function title(ctx, W, H, scale, small) {
  const g = ctx.createLinearGradient(0, 40 * scale, 0, 260 * scale);
  g.addColorStop(0, '#fff36b'); g.addColorStop(0.5, '#ffc21a'); g.addColorStop(1, '#ff8a00');
  if (small) {
    strokeText(ctx, 'R6', W * 0.5, 175 * scale, 170 * scale, '#ffffff', '#000', 'center', 30 * scale);
    strokeText(ctx, 'TOWER', W * 0.5, H - 120 * scale, 100 * scale, g, '#000', 'center', 22 * scale);
    strokeText(ctx, 'DEFENSE', W * 0.5, H - 30 * scale, 86 * scale, g, '#000', 'center', 20 * scale);
    return;
  }
  ctx.save(); ctx.translate(W * 0.5, 0); ctx.rotate(-0.025);
  strokeText(ctx, 'R6 TOWER', 0, 175 * scale, 170 * scale, g, '#000', 'center', 34 * scale);
  strokeText(ctx, 'DEFENSE', 0, 330 * scale, 160 * scale, g, '#000', 'center', 34 * scale);
  ctx.restore();
}
async function draw(scene, W, H, eye, target, fov, mode) {
  const canvas = document.createElement('canvas'); canvas.width = W; canvas.height = H;
  document.body.appendChild(canvas);
  const ctx = canvas.getContext('2d');
  const cam = makeCamera(eye, target, fov, W, H);
  renderScene(ctx, scene, cam, W, H);
  const scale = W / 1920 * (mode === 'icon' ? 2.2 : 1);
  effects(ctx, scene, cam, scale);
  hpBars(ctx, scene, cam, scale);
  // Виньетка по краям
  const v = ctx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.35, W / 2, H / 2, Math.max(W, H) * 0.75);
  v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(0,0,30,0.35)');
  ctx.fillStyle = v; ctx.fillRect(0, 0, W, H);
  if (mode === 'icon') {
    title(ctx, W, H, W / 512, true);
  } else {
    title(ctx, W, H, scale, false);
    sticker(ctx, '4 PLAYER CO-OP', W - 300 * scale, H - 120 * scale, 58 * scale, ['#4cd3ff', '#1677e6'], -0.06);
    sticker(ctx, 'BOSSES!', 250 * scale, H - 130 * scale, 64 * scale, ['#ff6b6b', '#c4161c'], 0.07);
  }
  return canvas.toDataURL('image/png');
}
`;

(async () => {
  const scene = fs.readFileSync(path.join(dir, 'scene.json'), 'utf8');
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' }).catch(() => chromium.launch());
  const p = await browser.newPage({ viewport: { width: 400, height: 300 } });
  await p.setContent(`<html><head><style>@font-face{font-family:"Fredoka One";src:url(data:font/ttf;base64,${font});}</style></head>
    <body style="margin:0"><script>${page}</script><div style="font-family:'Fredoka One'">.</div></body></html>`);
  await p.evaluate(() => document.fonts.load('80px "Fredoka One"'));
  const jobs = [
    { out: 'thumbnail.png', W: 1920, H: 1080, eye: [-18, 26, 68], target: [-8, 4, 10], fov: 50, mode: 'thumb' },
    { out: 'icon.png', W: 512, H: 512, eye: [-14, 13, 46], target: [-16, 4, 24], fov: 42, mode: 'icon' },
  ];
  for (const job of jobs) {
    const data = await p.evaluate(([s, j]) => draw(JSON.parse(s), j.W, j.H, j.eye, j.target, j.fov, j.mode), [scene, job]);
    fs.writeFileSync(path.join(dir, job.out), Buffer.from(data.split(',')[1], 'base64'));
    console.log('rendered', path.join(dir, job.out));
  }
  await browser.close();
})();
