// Обложка (1920×1080) и иконка (512×512) из сцены tools/marketing/scene.luau.
// Настоящий 3D-рендер в Chromium (three.js, WebGL): свет, тени, туман, свечение неона,
// студы геометрией, снег и эффекты выстрелов; логотип рисуется поверх на 2D-холсте.
// Запуск:
//   npm i three@0.170.0   (в любой папке; путь к ней — третий аргумент)
//   node tools/marketing/render.js <папка со scene.json> <Fredoka One .ttf> <папка node_modules/three>
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const dir = process.argv[2];
const fontPath = process.argv[3];
const threeDir = process.argv[4];
const only = process.argv[5];
const pageModule = path.join(__dirname, 'render-page.mjs');

const JOBS = [
  { file: 'thumbnail.png', width: 1920, height: 1080, ss: 1.5, mode: 'thumbnail',
    eye: [53, 3.5, -48.3], target: [14, 8.4, -48.4], fov: 40 },
  { file: 'icon.png', width: 512, height: 512, ss: 2, mode: 'icon',
    eye: [56.4, 3.5, -30.6], target: [66, 2.6, -27.3], fov: 40 },
];

const MIME = { '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.ttf': 'font/ttf' };

(async () => {
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage();
  page.on('console', (m) => console.log('[page]', m.text()));
  page.on('pageerror', (e) => console.log('[page error]', e.message));
  await page.route('http://local/**', (route) => {
    const url = new URL(route.request().url());
    let file = null;
    if (url.pathname === '/') {
      return route.fulfill({ contentType: 'text/html', body: `<!doctype html><html><head>
        <script type="importmap">{"imports":{"three":"/three/build/three.module.js","three/addons/":"/three/examples/jsm/"}}</script>
        </head><body style="margin:0;background:#000"></body></html>` });
    } else if (url.pathname.startsWith('/three/')) {
      file = path.join(threeDir, url.pathname.slice(7));
    } else if (url.pathname === '/page.mjs') {
      file = pageModule;
    } else if (url.pathname === '/scene.json') {
      file = path.join(dir, 'scene.json');
    } else if (url.pathname === '/font.ttf') {
      file = fontPath;
    }
    if (!file || !fs.existsSync(file)) return route.fulfill({ status: 404, body: 'not found' });
    route.fulfill({ contentType: MIME[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) });
  });
  await page.goto('http://local/');
  for (const job of JOBS) {
    if (only && job.mode !== only) continue;
    const started = Date.now();
    const dataUrl = await page.evaluate(async (j) => {
      const mod = await import('/page.mjs');
      return mod.render(j);
    }, job);
    fs.writeFileSync(path.join(dir, job.file), Buffer.from(dataUrl.split(',')[1], 'base64'));
    console.log('wrote', job.file, ((Date.now() - started) / 1000).toFixed(1) + 's');
  }
  await browser.close();
})();
