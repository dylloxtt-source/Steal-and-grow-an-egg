// Предпросмотр UI: рисует JSON-дерево GUI (из dump.luau) в Chromium и делает скриншоты.
// Запуск: node tools/preview/render.js <папка-с-json> [ширина] [высота]
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const dir = process.argv[2];
const width = Number(process.argv[3] || 1280);
const height = Number(process.argv[4] || 720);
const loadFont = name => { const p = path.join(dir, name); return fs.existsSync(p) ? fs.readFileSync(p).toString('base64') : null; };
const fontData = loadFont('fredoka.ttf');
const nunitoData = loadFont('nunito.ttf');

const renderer = `
const arr = x => Array.isArray(x) ? x : (x ? Object.values(x) : []);
const rgb = (c, a = 1) => c ? 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')' : 'transparent';
const mul = (c, g) => [Math.round(c[0] * g[0] / 255), Math.round(c[1] * g[1] / 255), Math.round(c[2] * g[2] / 255)];
const canvas = document.createElement('canvas').getContext('2d');
const familyOf = text => /[\u0400-\u04FF]/.test(text || '') ? '"Nunito"' : '"Fredoka One"';
function measure(text, size) { canvas.font = '900 ' + size + 'px ' + familyOf(text) + ', "Noto Color Emoji"'; return canvas.measureText(text).width; }
const outline = (t, c) => ['drop-shadow(' + t + 'px 0 0 ' + c + ')', 'drop-shadow(-' + t + 'px 0 0 ' + c + ')', 'drop-shadow(0 ' + t + 'px 0 ' + c + ')', 'drop-shadow(0 -' + t + 'px 0 ' + c + ')'].join(' ');
function fitText(text, w, h, max, wrap) {
  if (!text) return 0;
  let lo = 4, hi = Math.min(max || 100, h);
  for (let i = 0; i < 18; i++) {
    const mid = (lo + hi) / 2;
    let ok;
    if (wrap) {
      const words = text.split(/\\s+/); let lines = 1, line = 0;
      for (const word of words) { const ww = measure(word + ' ', mid); if (line + ww > w && line > 0) { lines++; line = ww; } else line += ww; }
      ok = lines * mid * 1.15 <= h;
    } else ok = measure(text, mid) <= w && mid <= h;
    if (ok) lo = mid; else hi = mid;
  }
  return lo;
}
function draw(node, parentEl, rect) {
  if (node.vis === false) return;
  const el = document.createElement('div');
  el.style.position = 'absolute';
  el.style.left = (rect.x) + 'px'; el.style.top = (rect.y) + 'px';
  el.style.width = rect.w + 'px'; el.style.height = rect.h + 'px';
  el.style.boxSizing = 'border-box';
  const m = Array.isArray(node.mods) ? {} : (node.mods || {});
  if (node.bg && node.bgt !== undefined && node.bgt < 1 && node.c !== 'ScrollingFrame') {
    if (m.gradient && !(node.c === 'TextLabel' || node.c === 'TextButton') ) {
      const a = mul(node.bg, m.gradient.a), b = mul(node.bg, m.gradient.b);
      el.style.background = 'linear-gradient(' + ((m.gradient.rot || 0) + 90) + 'deg,' + rgb(a, 1 - node.bgt) + ',' + rgb(b, 1 - node.bgt) + ')';
    } else el.style.background = rgb(node.bg, 1 - node.bgt);
  }
  if (m.corner) el.style.borderRadius = (m.corner[0] * Math.min(rect.w, rect.h) + m.corner[1]) + 'px';
  const shadows = [];
  for (const s of arr(m.strokes)) {
    if (s.border) shadows.push('0 0 0 ' + s.t + 'px ' + rgb(s.c, 1 - (s.tr || 0)));
  }
  if (shadows.length) el.style.boxShadow = shadows.join(',');
  if (node.rot) el.style.transform = 'rotate(' + node.rot + 'deg)';
  if (node.clip || node.c === 'ScrollingFrame') el.style.overflow = 'hidden';
  if (node.text && (node.c === 'TextLabel' || node.c === 'TextButton')) {
    const t = document.createElement('div');
    const fs = node.tscaled ? fitText(node.text, rect.w, rect.h, m.maxText || 100, node.wrap) : (node.tsize || 14);
    t.textContent = node.text;
    t.style.cssText = 'position:absolute;inset:0;display:flex;align-items:center;font-weight:900;font-family:' + familyOf(node.text) + ',"Noto Color Emoji";line-height:1.1;white-space:' + (node.wrap ? 'normal' : 'nowrap') + ';';
    t.style.fontSize = fs + 'px';
    t.style.justifyContent = node.xa === 'Left' ? 'flex-start' : node.xa === 'Right' ? 'flex-end' : 'center';
    t.style.textAlign = node.xa === 'Left' ? 'left' : 'center';
    const stroke = arr(m.strokes).find(s => !s.border);
    if (stroke) t.style.filter = outline(stroke.t, rgb(stroke.c));
    if (m.gradient && node.tc) {
      const a = mul(node.tc, m.gradient.a), b = mul(node.tc, m.gradient.b);
      const inner = document.createElement('span');
      inner.textContent = node.text; t.textContent = '';
      inner.style.background = 'linear-gradient(180deg,' + rgb(a) + ',' + rgb(b) + ')';
      inner.style.webkitBackgroundClip = 'text'; inner.style.backgroundClip = 'text'; inner.style.color = 'transparent';
      t.appendChild(inner);
    } else t.style.color = rgb(node.tc, 1 - (node.tt || 0));
    el.appendChild(t);
  }
  if (node.viewport) {
    const v = node.viewport; const c = arr(v.colors);
    const icon = document.createElement('div');
    const s = Math.min(rect.w, rect.h) * 0.7;
    icon.style.cssText = 'position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);';
    if (v.egg) {
      icon.style.width = s * 0.72 + 'px'; icon.style.height = s + 'px';
      icon.style.borderRadius = '50% 50% 46% 46% / 60% 60% 40% 40%';
      icon.style.background = 'radial-gradient(circle at 30% 60%,' + rgb(c[1] || c[0]) + ' 0 12%, transparent 13%),radial-gradient(circle at 70% 40%,' + rgb(c[1] || c[0]) + ' 0 10%, transparent 11%),' + rgb(c[0]);
      icon.style.boxShadow = 'inset -6px -8px 0 rgba(0,0,0,.18), 0 0 0 3px #111';
    } else {
      icon.style.width = s + 'px'; icon.style.height = s * 0.8 + 'px'; icon.style.borderRadius = '18%';
      icon.style.background = rgb(c[0]); icon.style.boxShadow = 'inset -6px -8px 0 rgba(0,0,0,.2), 0 0 0 3px #111';
      icon.innerHTML = '<div style="position:absolute;left:24%;top:30%;width:14%;height:20%;background:#111;border-radius:3px"></div><div style="position:absolute;right:24%;top:30%;width:14%;height:20%;background:#111;border-radius:3px"></div><div style="position:absolute;left:30%;bottom:-12%;width:40%;height:22%;background:' + rgb(c[1] || c[0]) + ';border-radius:3px;box-shadow:0 0 0 2px #111"></div>';
    }
    el.appendChild(icon);
  }
  parentEl.appendChild(el);
  layoutChildren(node, el, rect.w, rect.h);
}
function layoutChildren(node, el, W, H) {
  const m = Array.isArray(node.mods) ? {} : (node.mods || {});
  const pad = m.pad || [0, 0, 0, 0, 0, 0];
  const px = pad[0] + (pad[4] || 0) * W, py = pad[2] + (pad[5] || 0) * H;
  const cw = W - pad[0] - pad[1] - (pad[4] || 0) * W * 2, ch = H - pad[2] - pad[3] - (pad[5] || 0) * H * 2;
  let kids = arr(node.children).filter(k => k.size && k.vis !== false);
  kids = kids.map((k, i) => ({ k, i })).sort((a, b) => ((a.k.z || 1) - (b.k.z || 1)) || 0).map(o => o.k);
  const sizeOf = k => {
    let w = k.size[0] * cw + k.size[1], h = k.size[2] * ch + k.size[3];
    if (k.autosize === 'X' || k.autosize === 'XY') {
      const label = arr(k.children).find(c => c.text);
      if (label) w = Math.max(w, measure(label.text, label.tsize || 24) + 30);
    }
    return { w, h };
  };
  if (m.list || m.grid) {
    const ordered = kids.map((k, i) => ({ k, i })).sort((a, b) => ((a.k.lo || 0) - (b.k.lo || 0)) || (a.i - b.i)).map(o => o.k);
    if (m.grid) {
      const cell = m.grid.cell, gp = m.grid.pad;
      const cwid = cell[0] * cw + cell[1], chei = cell[2] * ch + cell[3];
      const gx = gp[0] * cw + gp[1], gy = gp[2] * ch + gp[3];
      const perRow = Math.max(1, Math.floor((cw + gx) / (cwid + gx)));
      const rowW = perRow * cwid + (perRow - 1) * gx;
      const offX = m.grid.ha === 'Center' ? (cw - rowW) / 2 : 0;
      ordered.forEach((k, i) => {
        const r = Math.floor(i / perRow), c = i % perRow;
        draw(k, el, { x: px + offX + c * (cwid + gx), y: py + r * (chei + gy), w: cwid, h: chei });
      });
    } else {
      const gap = m.list.pad[0] * (m.list.dir === 'Horizontal' ? cw : ch) + m.list.pad[1];
      if (m.list.dir === 'Horizontal') {
        const sizes = ordered.map(sizeOf); const total = sizes.reduce((s, z) => s + z.w, 0) + gap * Math.max(0, sizes.length - 1);
        let x = m.list.ha === 'Center' ? (cw - total) / 2 : 0;
        ordered.forEach((k, i) => { draw(k, el, { x: px + x, y: py, w: sizes[i].w, h: sizes[i].h }); x += sizes[i].w + gap; });
      } else {
        let y = 0;
        ordered.forEach(k => { const s = sizeOf(k); const x = m.list.ha === 'Center' ? (cw - s.w) / 2 : 0; draw(k, el, { x: px + x, y: py + y, w: s.w, h: s.h }); y += s.h + gap; });
      }
    }
    return;
  }
  for (const k of kids) {
    const s = sizeOf(k);
    const x = px + k.pos[0] * cw + k.pos[1] - k.anchor[0] * s.w;
    const y = py + k.pos[2] * ch + k.pos[3] - k.anchor[1] * s.h;
    draw(k, el, { x, y, w: s.w, h: s.h });
  }
}
function render(tree, W, H, scale) {
  const root = document.getElementById('root');
  root.style.transform = 'scale(' + scale + ')'; root.style.transformOrigin = '0 0';
  root.style.width = (W / scale) + 'px'; root.style.height = (H / scale) + 'px';
  layoutChildren(tree, root, W / scale, H / scale);
}
`;

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' }).catch(() => chromium.launch());
  const scale = Math.min(Math.max(Math.min(width / 1280, height / 760), 0.5), 1.3);
  for (const file of fs.readdirSync(dir).filter(f => f.endsWith('.json'))) {
    const page = await browser.newPage({ viewport: { width, height } });
    page.on('pageerror', e => console.log('pageerror:', e.message));
    const tree = fs.readFileSync(path.join(dir, file), 'utf8');
    const font = (fontData ? `@font-face{font-family:"Fredoka One";src:url(data:font/ttf;base64,${fontData});}` : '')
      + (nunitoData ? `@font-face{font-family:"Nunito";font-weight:900;src:url(data:font/ttf;base64,${nunitoData});}` : '');
    await page.setContent(`<html><head><style>${font}body{margin:0;width:${width}px;height:${height}px;overflow:hidden;
      background:linear-gradient(180deg,#7cc4f2 0 38%,#58c43c 38% 100%);}
      #sky{position:absolute;inset:0;background:repeating-linear-gradient(90deg,rgba(0,0,0,.05) 0 40px,transparent 40px 80px);}
      #root{position:absolute;left:0;top:0}</style></head><body><div id="sky"></div><div id="root"></div>
      <script>${renderer}; document.fonts.ready.then(()=>{render(${tree}, ${width}, ${height}, ${scale}); window.done = true;});</script></body></html>`);
    await page.waitForFunction('window.done === true', null, { timeout: 30000 });
    const out = path.join(dir, file.replace('.json', `_${width}x${height}.png`));
    await page.screenshot({ path: out });
    console.log('rendered', out);
    await page.close();
  }
  await browser.close();
})();
