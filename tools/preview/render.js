// Предпросмотр UI: рисует JSON-дерево GUI (из tools/preview/dump.luau) в Chromium и делает скриншоты.
// Запуск: node tools/preview/render.js <папка-с-json>
// Размер экрана берётся из имени файла: <сцена>@<ширина>x<высота>.json (по умолчанию 1280x720).
// Шрифт: положите montserrat.css (с data:-URL) в ту же папку — иначе будет системный.
// Это приближение: раскладка UDim2/UIListLayout/UIPadding/UIScale повторена вручную,
// окончательно интерфейс проверяется в Roblox Studio.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const dir = process.argv[2];
const fontCss = (fs.existsSync(path.join(dir, 'montserrat.css')) ? fs.readFileSync(path.join(dir, 'montserrat.css'), 'utf8') : '')
  + (fs.existsSync(path.join(dir, 'fredoka.ttf')) ? '@font-face{font-family:"Fredoka One";src:url(data:font/ttf;base64,' + fs.readFileSync(path.join(dir, 'fredoka.ttf')).toString('base64') + ');}' : '');

const renderer = `
const arr = x => Array.isArray(x) ? x : (x ? Object.values(x) : []);
const rgb = (c, a = 1) => c ? 'rgba(' + c[0] + ',' + c[1] + ',' + c[2] + ',' + a + ')' : 'transparent';
const mul = (c, g) => [Math.round(c[0] * g[0] / 255), Math.round(c[1] * g[1] / 255), Math.round(c[2] * g[2] / 255)];
const FONT = '"Montserrat", "Noto Color Emoji", sans-serif';
const DISPLAY = '"Fredoka One", "Noto Color Emoji", sans-serif';
const plain = t => (t || '').replace(/<[^>]+>/g, '');
const canvas = document.createElement('canvas').getContext('2d');
function measure(text, size, weight, display) { canvas.font = (display ? 400 : (weight || 600)) + ' ' + size + 'px ' + (display ? DISPLAY : FONT); return canvas.measureText(plain(text)).width; }
function modsOf(node) { return Array.isArray(node.mods) ? {} : (node.mods || {}); }
function draw(node, parentEl, rect) {
  if (node.vis === false) return;
  const m = modsOf(node);
  const el = document.createElement('div');
  el.style.position = 'absolute';
  el.style.left = rect.x + 'px'; el.style.top = rect.y + 'px';
  el.style.width = rect.w + 'px'; el.style.height = rect.h + 'px';
  el.style.boxSizing = 'border-box';
  const transforms = [];
  if (m.scale && m.scale !== 1) {
    transforms.push('scale(' + m.scale + ')');
    el.style.transformOrigin = (node.anchor[0] * 100) + '% ' + (node.anchor[1] * 100) + '%';
  }
  if (node.rot) transforms.push('rotate(' + node.rot + 'deg)');
  if (transforms.length) el.style.transform = transforms.join(' ');
  if (node.bg && node.bgt !== undefined && node.bgt < 1) {
    if (m.gradient) {
      const a = mul(node.bg, m.gradient.a), b = mul(node.bg, m.gradient.b);
      el.style.background = 'linear-gradient(' + ((m.gradient.rot || 0) + 90) + 'deg,' + rgb(a, 1 - node.bgt) + ',' + rgb(b, 1 - node.bgt) + ')';
    } else el.style.background = rgb(node.bg, 1 - node.bgt);
  }
  if (m.corner) el.style.borderRadius = (m.corner[0] * Math.min(rect.w, rect.h) + m.corner[1]) + 'px';
  const shadows = [];
  for (const s of arr(m.strokes)) if (s.border) shadows.push('0 0 0 ' + s.t + 'px ' + rgb(s.c, 1 - (s.tr || 0)));
  if (shadows.length) el.style.boxShadow = shadows.join(',');
  if (node.clip) el.style.overflow = 'hidden';
  if (node.text && (node.c === 'TextLabel' || node.c === 'TextButton')) {
    const t = document.createElement('div');
    const size = node.tsize || 14;
    const display = node.ff === 'display';
    const shown = node.rich ? plain(node.text) : node.text;
    t.textContent = shown;
    const ya = node.ya === 'Top' ? 'flex-start' : node.ya === 'Bottom' ? 'flex-end' : 'center';
    t.style.cssText = 'position:absolute;inset:0;display:flex;align-items:' + ya + ';font-family:' + (display ? DISPLAY : FONT) + ';line-height:1.15;' +
      'white-space:' + (node.wrap ? 'normal' : 'nowrap') + ';overflow:' + (node.trunc ? 'hidden' : 'visible') + ';';
    if (node.trunc && !node.wrap) t.style.textOverflow = 'ellipsis';
    t.style.fontSize = size + 'px';
    t.style.fontWeight = display ? 400 : (node.fw || 600);
    const xa = node.xa || 'Center';
    t.style.justifyContent = xa === 'Left' ? 'flex-start' : xa === 'Right' ? 'flex-end' : 'center';
    t.style.textAlign = xa === 'Left' ? 'left' : xa === 'Right' ? 'right' : 'center';
    t.style.color = rgb(node.tc, 1 - (node.tt || 0));
    const stroke = arr(m.strokes).find(s => !s.border);
    if (stroke) t.style.textShadow = ['1px 1px', '-1px 1px', '1px -1px', '-1px -1px', '0 2px'].map(o => o + ' 0 ' + rgb(stroke.c, 1 - (stroke.tr || 0))).join(',');
    if (node.trunc && !node.wrap) { const span = document.createElement('span'); span.textContent = shown; span.style.overflow = 'hidden'; span.style.textOverflow = 'ellipsis'; t.textContent = ''; t.appendChild(span); }
    el.appendChild(t);
  }
  if (node.image) {
    el.style.background = 'radial-gradient(circle at 50% 38%, #f5cd30 0 24%, transparent 25%), radial-gradient(ellipse at 50% 100%, #0d69ac 0 45%, transparent 46%), #3a4160';
  }
  if (node.viewport) {
    // Схематичный R6-силуэт в цветах модели (настоящий 3D рендер — только в Studio)
    const c = node.viewport;
    const s = Math.min(rect.w, rect.h) / 6.2;
    const fig = document.createElement('div');
    fig.style.cssText = 'position:absolute;left:50%;top:52%;width:' + 4 * s + 'px;height:' + 5 * s + 'px;transform:translate(-50%,-50%);';
    const block = (x, y, w, h, col) => '<div style="position:absolute;left:' + x * s + 'px;top:' + y * s + 'px;width:' + w * s + 'px;height:' + h * s + 'px;background:' + rgb(col) + ';box-shadow:inset -2px -3px 0 rgba(0,0,0,.18);border-radius:2px"></div>';
    fig.innerHTML = block(1.25, 0, 1.5, 1.2, c.head) + block(1, 1.2, 2, 2, c.torso) + block(0, 1.2, 1, 2, c.arm) + block(3, 1.2, 1, 2, c.arm) +
      block(1, 3.2, 1, 1.8, c.leg) + block(2, 3.2, 1, 1.8, c.leg) + (c.accent ? block(3.6, 0.6, 0.35, 2.6, c.accent) : '');
    el.appendChild(fig);
  }
  parentEl.appendChild(el);
  layoutChildren(node, el, rect.w, rect.h);
}
function sizeOf(k, cw, ch) {
  let w = k.size[0] * cw + k.size[1], h = k.size[2] * ch + k.size[3];
  if ((k.autosize === 'Y' || k.autosize === 'XY') && k.text) {
    const lines = Math.max(1, Math.ceil(measure(k.text, k.tsize || 14, k.fw, k.ff === 'display') / Math.max(1, w)));
    h = Math.max(h, lines * (k.tsize || 14) * 1.2 + 4);
  }
  if ((k.autosize === 'Y' || k.autosize === 'XY') && !k.text) {
    let maxBottom = h;
    for (const c of arr(k.children)) if (c.size && c.vis !== false) {
      const cs = sizeOf(c, w, h);
      maxBottom = Math.max(maxBottom, (c.pos ? c.pos[2] * h + c.pos[3] : 0) + cs.h);
    }
    h = maxBottom;
  }
  return { w, h };
}
function layoutChildren(node, el, W, H) {
  const m = modsOf(node);
  const pad = m.pad || [0, 0, 0, 0];
  const px = pad[0], py = pad[2];
  const cw = W - pad[0] - pad[1], ch = H - pad[2] - pad[3];
  let kids = arr(node.children).filter(k => k.size && k.vis !== false);
  kids = kids.map((k, i) => ({ k, i })).sort((a, b) => ((a.k.z || 1) - (b.k.z || 1)) || (a.i - b.i)).map(o => o.k);
  if (m.list || m.grid) {
    const ordered = kids.map((k, i) => ({ k, i })).sort((a, b) => ((a.k.lo || 0) - (b.k.lo || 0)) || (a.i - b.i)).map(o => o.k);
    if (m.grid) {
      const cell = m.grid.cell, gp = m.grid.pad;
      const cwid = cell[0] * cw + cell[1], chei = cell[2] * ch + cell[3];
      const gx = gp[0] * cw + gp[1], gy = gp[2] * ch + gp[3];
      const perRow = Math.max(1, Math.floor((cw + gx) / (cwid + gx)));
      ordered.forEach((k, i) => draw(k, el, { x: px + (i % perRow) * (cwid + gx), y: py + Math.floor(i / perRow) * (chei + gy), w: cwid, h: chei }));
      return;
    }
    const horizontal = m.list.dir === 'Horizontal';
    const gap = m.list.pad[0] * (horizontal ? cw : ch) + m.list.pad[1];
    const sizes = ordered.map(k => sizeOf(k, cw, ch));
    if (horizontal) {
      const total = sizes.reduce((s, z) => s + z.w, 0) + gap * Math.max(0, sizes.length - 1);
      let x = m.list.ha === 'Center' ? (cw - total) / 2 : m.list.ha === 'Right' ? cw - total : 0;
      ordered.forEach((k, i) => { const y = (ch - sizes[i].h) / 2; draw(k, el, { x: px + x, y: py + y, w: sizes[i].w, h: sizes[i].h }); x += sizes[i].w + gap; });
    } else {
      let y = 0;
      ordered.forEach((k, i) => { const s = sizes[i]; const x = m.list.ha === 'Center' ? (cw - s.w) / 2 : m.list.ha === 'Right' ? cw - s.w : 0; draw(k, el, { x: px + x, y: py + y, w: s.w, h: s.h }); y += s.h + gap; });
    }
    return;
  }
  for (const k of kids) {
    const s = sizeOf(k, cw, ch);
    draw(k, el, { x: px + k.pos[0] * cw + k.pos[1] - k.anchor[0] * s.w, y: py + k.pos[2] * ch + k.pos[3] - k.anchor[1] * s.h, w: s.w, h: s.h });
  }
}
function render(tree, W, H) {
  const root = document.getElementById('root');
  root.style.width = W + 'px'; root.style.height = H + 'px';
  for (const screen of arr(tree.children)) layoutChildren(screen, root, W, H);
}
`;

(async () => {
  const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' }).catch(() => chromium.launch());
  for (const file of fs.readdirSync(dir).filter(f => f.endsWith('.json'))) {
    const match = file.match(/@(\d+)x(\d+)\.json$/);
    const width = match ? Number(match[1]) : 1280, height = match ? Number(match[2]) : 720;
    const page = await browser.newPage({ viewport: { width, height } });
    page.on('pageerror', e => console.log('pageerror:', e.message));
    const tree = fs.readFileSync(path.join(dir, file), 'utf8');
    const backdrop = file.startsWith('lobby') ? 'linear-gradient(180deg,#8ec9f0 0 35%,#7dbb5a 35% 100%)' : 'linear-gradient(180deg,#6aa84f 0%,#5b9645 100%)';
    await page.setContent(`<html><head><style>${fontCss}body{margin:0;width:${width}px;height:${height}px;overflow:hidden;background:${backdrop};}
      #road{position:absolute;left:8%;right:8%;top:46%;height:9%;background:#c4a470;box-shadow:0 0 0 4px #96784f;}
      #root{position:absolute;left:0;top:0}</style></head><body>${file.startsWith('lobby') ? '' : '<div id="road"></div>'}<div id="root"></div>
      <script>${renderer}; document.fonts.load('600 16px Montserrat').then(()=>document.fonts.ready).then(()=>{render(${tree}, ${width}, ${height}); window.done = true;});</script></body></html>`);
    await page.waitForFunction('window.done === true', null, { timeout: 30000 });
    const out = path.join(dir, file.replace('.json', '.png'));
    await page.screenshot({ path: out });
    console.log('rendered', out);
    await page.close();
  }
  await browser.close();
})();
