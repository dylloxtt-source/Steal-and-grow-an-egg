// Простой 3D-рендер моделей (полигоны + алгоритм художника) для проверки поз R6 и хвата оружия.
// Вход — *.models.json из tools/preview/models.luau. Запуск: node tools/preview/models.js <папка>
// Это схема, а не рендер Roblox: материалы, меши (кроме головы), свет и тени упрощены.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const dir = process.argv[2];

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
    const n = 10, ring = x => Array.from({length: n}, (_, i) => [x, .5*Math.cos(i/n*2*Math.PI), .5*Math.sin(i/n*2*Math.PI)]);
    const r0 = ring(-.5), r1 = ring(.5);
    for (let i = 0; i < n; i++) { const j = (i+1)%n; quad(r0[i], r0[j], r1[j], r1[i]); }
    P.push(r0.slice().reverse()); P.push(r1);
  } else { // Ball
    const la = 6, lo = 8, pt = (i, j) => { const t = i/la*Math.PI, p = j/lo*2*Math.PI; return [.5*Math.sin(t)*Math.cos(p), .5*Math.cos(t), .5*Math.sin(t)*Math.sin(p)]; };
    for (let i = 0; i < la; i++) for (let j = 0; j < lo; j++) quad(pt(i,j), pt(i,j+1), pt(i+1,j+1), pt(i+1,j));
  }
  return P;
}
function world(part, v) {
  const m = part.m, sx = part.size[0]*v[0], sy = part.size[1]*v[1], sz = part.size[2]*v[2];
  return [m[0] + m[3]*sx + m[4]*sy + m[5]*sz, m[1] + m[6]*sx + m[7]*sy + m[8]*sz, m[2] + m[9]*sx + m[10]*sy + m[11]*sz];
}
const sub = (a, b) => [a[0]-b[0], a[1]-b[1], a[2]-b[2]];
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const dot = (a, b) => a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
const norm = a => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0]/l, a[1]/l, a[2]/l]; };
// План сверху: ортогональная проекция, детали рисуются снизу вверх по высоте
function drawPlan(ctx, model, x0, y0, w, h) {
  const polys = [];
  const light = norm([-0.4, 1, -0.6]);
  for (const part of model.parts) {
    for (const poly of shapePolys(part.s)) {
      const wp = poly.map(v => world(part, v));
      const n = norm(cross(sub(wp[1], wp[0]), sub(wp[2], wp[0])));
      if (n[1] < 0.05) continue; // только грани, видимые сверху
      const top = wp.reduce((s, p) => s + p[1], 0) / wp.length;
      polys.push({ wp, top, color: part.c, shade: part.neon ? 1.15 : 0.6 + 0.4 * Math.max(0, dot(n, light)), alpha: 1 - (part.t || 0) });
    }
  }
  let minX = 1e9, minZ = 1e9, maxX = -1e9, maxZ = -1e9;
  for (const p of polys) for (const v of p.wp) { minX = Math.min(minX, v[0]); maxX = Math.max(maxX, v[0]); minZ = Math.min(minZ, v[2]); maxZ = Math.max(maxZ, v[2]); }
  const scale = Math.min((w - 20) / (maxX - minX), (h - 40) / (maxZ - minZ));
  const ox = x0 + w / 2 - (minX + maxX) / 2 * scale, oy = y0 + 8 + (h - 36) / 2 - (minZ + maxZ) / 2 * scale;
  polys.sort((a, b) => a.top - b.top);
  for (const p of polys) {
    ctx.beginPath();
    p.wp.forEach((v, i) => { const X = ox + v[0] * scale, Y = oy + v[2] * scale; i ? ctx.lineTo(X, Y) : ctx.moveTo(X, Y); });
    ctx.closePath();
    const c = p.color.map(v => Math.min(255, Math.round(v * p.shade)));
    ctx.fillStyle = 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + p.alpha + ')';
    ctx.fill();
  }
  if (model.path) {
    ctx.strokeStyle = 'rgba(255,40,40,0.9)'; ctx.lineWidth = 1.5; ctx.setLineDash([4, 3]);
    ctx.beginPath();
    model.path.forEach((v, i) => { const X = ox + v[0] * scale, Y = oy + v[1] * scale; i ? ctx.lineTo(X, Y) : ctx.moveTo(X, Y); });
    ctx.stroke(); ctx.setLineDash([]);
  }
}
function drawModel(ctx, model, x0, y0, w, h, eye, plan) {
  if (plan) return drawPlan(ctx, model, x0, y0, w, h);
  eye = model.eye || eye;
  const target = model.target || [0, 3, 0];
  const f = norm(sub(target, eye)), r = norm(cross(f, [0,1,0])), u = cross(r, f);
  const light = norm([-0.4, 1, -0.6]);
  const polys = [];
  for (const part of model.parts) {
    for (const poly of shapePolys(part.s)) {
      const wp = poly.map(v => world(part, v));
      const n = norm(cross(sub(wp[1], wp[0]), sub(wp[2], wp[0])));
      const cam = wp.map(p => { const d = sub(p, eye); return [dot(d, r), dot(d, u), dot(d, f)]; });
      const depth = cam.reduce((s, c) => s + c[2], 0) / cam.length;
      const shade = part.neon ? 1.15 : 0.55 + 0.45 * Math.max(0, dot(n, light));
      polys.push({ cam, depth, color: part.c, shade, alpha: 1 - (part.t || 0) });
    }
  }
  const proj = c => [c[0] / c[2], -c[1] / c[2]];
  let minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
  for (const p of polys) for (const c of p.cam) { const q = proj(c); minX = Math.min(minX, q[0]); maxX = Math.max(maxX, q[0]); minY = Math.min(minY, q[1]); maxY = Math.max(maxY, q[1]); }
  const scale = Math.min((w - 24) / (maxX - minX), (h - 44) / (maxY - minY));
  const ox = x0 + w / 2 - (minX + maxX) / 2 * scale, oy = y0 + 8 + (h - 36) / 2 - (minY + maxY) / 2 * scale;
  polys.sort((a, b) => b.depth - a.depth);
  for (const p of polys) {
    ctx.beginPath();
    p.cam.forEach((c, i) => { const q = proj(c); const X = ox + q[0] * scale, Y = oy + q[1] * scale; i ? ctx.lineTo(X, Y) : ctx.moveTo(X, Y); });
    ctx.closePath();
    const c = p.color.map(v => Math.min(255, Math.round(v * p.shade)));
    ctx.fillStyle = 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + p.alpha + ')';
    ctx.strokeStyle = 'rgba(0,0,0,0.25)'; ctx.lineWidth = 0.6;
    ctx.fill(); ctx.stroke();
  }
}
function render(models, cols, tileW, tileH, views) {
  const rows = Math.ceil(models.length * views.length / cols);
  const canvas = document.createElement('canvas');
  canvas.width = cols * tileW; canvas.height = rows * tileH;
  document.body.appendChild(canvas);
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#20232c'; ctx.fillRect(0, 0, canvas.width, canvas.height);
  let i = 0;
  for (const model of models) for (const view of views) {
    const x = (i % cols) * tileW, y = Math.floor(i / cols) * tileH; i++;
    ctx.fillStyle = (i % 2) ? '#2a2e3a' : '#262a35'; ctx.fillRect(x, y, tileW, tileH);
    drawModel(ctx, model, x, y, tileW, tileH, view.eye, view.plan);
    ctx.fillStyle = '#e8ecf4'; ctx.font = '600 13px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText(model.label + (view.name ? ' • ' + view.name : ''), x + tileW / 2, y + tileH - 10);
  }
  return [canvas.width, canvas.height];
}
`;

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' }).catch(() => chromium.launch());
  const jobs = [
    { file: 'towers.models.json', cols: 6, w: 230, h: 250, views: [{ eye: [7, 6, -12] }] },
    { file: 'towers.models.json', cols: 6, w: 230, h: 250, views: [{ eye: [-12, 5, -2], name: 'сбоку' }], out: 'towers_side' },
    { file: 'enemies.models.json', cols: 6, w: 230, h: 250, views: [{ eye: [7, 6, -12] }] },
    { file: 'maps.models.json', cols: 2, w: 700, h: 470, views: [{}] },
    { file: 'maps.models.json', cols: 2, w: 700, h: 540, views: [{ plan: true, name: 'план' }], out: 'maps_plan' },
    { file: 'lobby.models.json', cols: 1, w: 1000, h: 560, views: [{}] },
  ];
  for (const job of jobs) {
    const models = fs.readFileSync(path.join(dir, job.file), 'utf8');
    const p = await browser.newPage({ viewport: { width: 1400, height: 1200 } });
    await p.setContent('<html><body style="margin:0;background:#20232c"><script>' + page + '</script></body></html>');
    const size = await p.evaluate(([m, j]) => render(JSON.parse(m), j.cols, j.w, j.h, j.views), [models, job]);
    await p.setViewportSize({ width: size[0], height: size[1] });
    const out = path.join(dir, (job.out || job.file.replace('.models.json', '')) + '.png');
    await p.screenshot({ path: out, clip: { x: 0, y: 0, width: size[0], height: size[1] } });
    console.log('rendered', out);
    await p.close();
  }
  await browser.close();
})();
