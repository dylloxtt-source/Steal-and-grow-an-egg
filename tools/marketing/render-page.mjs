// Страница рендера для tools/marketing/render.js (выполняется в Chromium).
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

let sceneData = null;
let fontLoaded = false;

const srgb = (c, k = 1) => new THREE.Color().setRGB((c[0] / 255) * k, (c[1] / 255) * k, (c[2] / 255) * k, THREE.SRGBColorSpace);
const hex = (h) => new THREE.Color(h);

function rng(seed) {
  return () => {
    seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ---------- Геометрия деталей Roblox ----------
const GEO = {};
function wedgeGeometry() {
  const a = [-.5, -.5, -.5], b = [.5, -.5, -.5], c = [.5, -.5, .5], d = [-.5, -.5, .5], e = [.5, .5, .5], f = [-.5, .5, .5];
  const tris = [a, c, b, a, d, c, d, e, c, d, f, e, a, b, e, a, e, f, a, f, d, b, c, e];
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(tris.flat(), 3));
  g.computeVertexNormals();
  return g;
}
function headGeometry() {
  const pts = [];
  const r = 0.5, h = 0.5, c = 0.2;
  pts.push(new THREE.Vector2(0, -h));
  for (let i = 0; i <= 8; i++) {
    const t = -Math.PI / 2 + (i / 8) * (Math.PI / 2);
    pts.push(new THREE.Vector2(r - c + Math.cos(t) * c, -h + c + Math.sin(t) * c));
  }
  for (let i = 0; i <= 8; i++) {
    const t = (i / 8) * (Math.PI / 2);
    pts.push(new THREE.Vector2(r - c + Math.cos(t) * c, h - c + Math.sin(t) * c));
  }
  pts.push(new THREE.Vector2(0, h));
  return new THREE.LatheGeometry(pts, 40);
}
function geometry(shape) {
  if (GEO[shape]) return GEO[shape];
  let g;
  if (shape === 'Wedge') g = wedgeGeometry();
  else if (shape === 'Cylinder') g = new THREE.CylinderGeometry(0.5, 0.5, 1, 28).rotateZ(-Math.PI / 2);
  else if (shape === 'Ball') g = new THREE.SphereGeometry(0.5, 28, 18);
  else if (shape === 'Head') g = headGeometry();
  else g = new THREE.BoxGeometry(1, 1, 1);
  GEO[shape] = g;
  return g;
}
function scaleFor(p) {
  const [sx, sy, sz] = p.size;
  if (p.s === 'Cylinder') { const d = Math.min(sy, sz); return [sx, d, d]; }
  if (p.s === 'Ball') { const d = Math.min(sx, sy, sz); return [d, d, d]; }
  if (p.s === 'Head') return [sz * 1.25, sy * 1.25, sz * 1.25];
  return [sx, sy, sz];
}

// ---------- Текстуры ----------
function canvasTexture(w, h, draw, srgbSpace = true) {
  const cv = document.createElement('canvas');
  cv.width = w; cv.height = h;
  draw(cv.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(cv);
  if (srgbSpace) t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
const TEX = {};
function faceTexture() {
  // Классическое лицо Roblox: два овальных глаза и улыбка
  return TEX.face ??= canvasTexture(512, 512, (g, w, h) => {
    g.fillStyle = '#111';
    for (const x of [0.36, 0.64]) {
      g.beginPath(); g.ellipse(w * x, h * 0.4, w * 0.045, h * 0.085, 0, 0, Math.PI * 2); g.fill();
    }
    g.strokeStyle = '#111'; g.lineWidth = w * 0.035; g.lineCap = 'round';
    g.beginPath(); g.arc(w * 0.5, h * 0.42, w * 0.21, Math.PI * 0.2, Math.PI * 0.8); g.stroke();
  });
}
function glowTexture() {
  return TEX.glow ??= canvasTexture(128, 128, (g, w) => {
    const gr = g.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.25, 'rgba(255,255,255,0.55)');
    gr.addColorStop(0.6, 'rgba(255,255,255,0.12)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, w, w);
  });
}
function starTexture() {
  return TEX.star ??= canvasTexture(256, 256, (g, w) => {
    g.translate(w / 2, w / 2);
    const gr = g.createRadialGradient(0, 0, 0, 0, 0, w / 2);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.2, 'rgba(255,255,255,0.6)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr;
    for (let i = 0; i < 6; i++) {
      g.rotate(Math.PI / 3 + (i % 2) * 0.2);
      g.beginPath(); g.moveTo(0, -w * 0.06); g.lineTo(w * (i % 2 ? 0.36 : 0.5), 0); g.lineTo(0, w * 0.06); g.fill();
    }
    g.beginPath(); g.arc(0, 0, w * 0.16, 0, Math.PI * 2); g.fill();
  });
}
function smokeTexture(seed) {
  return TEX['smoke' + seed] ??= canvasTexture(256, 256, (g, w) => {
    const r = rng(seed);
    for (let i = 0; i < 26; i++) {
      const x = w * (0.3 + r() * 0.4), y = w * (0.3 + r() * 0.4), rad = w * (0.12 + r() * 0.2);
      const gr = g.createRadialGradient(x, y, 0, x, y, rad);
      gr.addColorStop(0, 'rgba(255,255,255,0.22)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
      g.fillStyle = gr; g.fillRect(0, 0, w, w);
    }
  });
}
function flakeTexture() {
  return TEX.flake ??= canvasTexture(64, 64, (g, w) => {
    const gr = g.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.45, 'rgba(255,255,255,0.8)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, w, w);
  });
}

// ---------- Материалы ----------
const MATS = new Map();
function material(p) {
  const key = `${p.mat}|${p.c}|${p.t}|${p.refl}`;
  if (MATS.has(key)) return MATS.get(key);
  const color = srgb(p.c);
  const opacity = 1 - p.t;
  const transparent = p.t > 0.01;
  let m;
  if (p.mat === 'Neon') {
    m = new THREE.MeshBasicMaterial({ color: color.clone().multiplyScalar(1.7), transparent, opacity });
  } else if (p.mat === 'ForceField') {
    m = new THREE.MeshBasicMaterial({ color: color.clone().multiplyScalar(1.6), transparent: true, opacity: 0.35 * opacity,
      blending: THREE.AdditiveBlending, depthWrite: false });
  } else {
    const R = { Plastic: 0.5, SmoothPlastic: 0.3, Metal: 0.42, DiamondPlate: 0.45, Glass: 0.05, Ice: 0.08, Slate: 0.8,
      Concrete: 0.9, WoodPlanks: 0.7, Snow: 0.9, Grass: 0.9, Sandstone: 0.85 };
    const metal = p.mat === 'Metal' || p.mat === 'DiamondPlate' ? 0.85 : Math.min(0.9, p.refl || 0);
    const glassy = p.mat === 'Glass' || p.mat === 'Ice';
    m = new THREE.MeshStandardMaterial({ color, roughness: R[p.mat] ?? 0.5, metalness: metal,
      transparent: transparent || glassy, opacity: glassy ? Math.min(opacity, 0.75) : opacity, envMapIntensity: metal > 0.5 ? 0.45 : 0.8 });
  }
  MATS.set(key, m);
  return m;
}

// ---------- Небо ----------
function skyMesh(eye, look) {
  const mat = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: {
      uZenith: { value: look.zenith }, uHorizon: { value: look.horizon }, uGlow: { value: look.glow },
      uMoon: { value: look.moonDir }, uAurora: { value: look.aurora },
    },
    vertexShader: `varying vec3 vDir; void main(){ vDir = normalize(position); vec4 p = projectionMatrix * modelViewMatrix * vec4(position, 1.0); gl_Position = p.xyww; }`,
    fragmentShader: `
      varying vec3 vDir; uniform vec3 uZenith, uHorizon, uGlow, uMoon; uniform float uAurora;
      float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
      float noise(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
        return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y); }
      float fbm(vec2 p){ float v = 0.0, a = 0.5; for (int i = 0; i < 5; i++){ v += a*noise(p); p *= 2.03; a *= 0.5; } return v; }
      void main(){
        vec3 d = normalize(vDir);
        float h = max(d.y, 0.0);
        vec3 col = mix(uHorizon, uZenith, pow(h, 0.5));
        col += uGlow * exp(-h * 10.0);
        float elev = asin(clamp(d.y, -1.0, 1.0));
        float az = atan(d.z, d.x);
        // северное сияние: три полосы-«занавеса» с вертикальными лучами
        vec3 aur = vec3(0.0);
        for (int k = 0; k < 3; k++) {
          float fk = float(k);
          float base = 0.16 + 0.1 * fk + 0.07 * sin(az * 2.3 + fk * 1.9) + 0.09 * (fbm(vec2(az * 2.2 + fk * 7.0, fk)) - 0.5);
          float t = elev - base;
          float curtain = smoothstep(-0.015, 0.012, t) * exp(-max(t, 0.0) * (6.0 + fk * 2.0));
          float rays = 0.45 + 0.55 * noise(vec2(az * 90.0 + fk * 31.0, 0.5));
          rays *= 0.5 + 0.5 * fbm(vec2(az * 6.0 - fk * 3.0, fk * 2.0));
          vec3 c = mix(vec3(0.15, 1.0, 0.55), vec3(0.35, 0.45, 1.0), clamp(t * 5.0, 0.0, 1.0));
          aur += c * curtain * rays * (1.0 - fk * 0.25);
        }
        col += aur * uAurora * smoothstep(0.0, 0.08, h);
        // звёзды
        vec2 sp = d.xz / (d.y + 0.35) * 260.0;
        float s = hash(floor(sp));
        float tw = smoothstep(0.35, 0.0, length(fract(sp) - 0.5));
        col += vec3(0.8, 0.9, 1.0) * step(0.993, s) * tw * smoothstep(0.08, 0.4, h) * 0.9;
        // луна
        float md = dot(d, normalize(uMoon));
        col += vec3(1.0, 0.98, 0.92) * 2.2 * smoothstep(0.99925, 0.9994, md);
        col += vec3(0.55, 0.7, 1.0) * (pow(max(md, 0.0), 300.0) * 0.6 + pow(max(md, 0.0), 30.0) * 0.12);
        gl_FragColor = vec4(col, 1.0);
      }`,
  });
  const sky = new THREE.Mesh(new THREE.SphereGeometry(1000, 64, 32), mat);
  sky.position.set(...eye);
  sky.renderOrder = -10;
  return sky;
}

// ---------- Сцена ----------
function buildWorld(data, job, look) {
  const scene = new THREE.Scene();
  const eye = new THREE.Vector3(...job.eye);
  const target = new THREE.Vector3(...job.target);
  const forward = target.clone().sub(eye).normalize();
  const r = rng(7);

  scene.add(skyMesh(job.eye, look));
  scene.fog = new THREE.FogExp2(look.fog, look.fogDensity);

  // Земля за пределами карты и дальние ели (карта ограничена полем 168×124)
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(3000, 3000).rotateX(-Math.PI / 2),
    new THREE.MeshStandardMaterial({ color: srgb([236, 238, 242]), roughness: 0.9 }));
  ground.position.y = -0.4;
  ground.receiveShadow = true;
  scene.add(ground);

  const pineMat = new THREE.MeshStandardMaterial({ color: srgb([40, 92, 70]), roughness: 0.8 });
  const capMat = new THREE.MeshStandardMaterial({ color: srgb([240, 244, 250]), roughness: 0.8 });
  const trunkMat = new THREE.MeshStandardMaterial({ color: srgb([90, 60, 40]), roughness: 0.8 });
  const tiers = [[4.6, 2.2, 1.5], [3.4, 2.0, 3.4], [2.2, 1.8, 5.1], [1.1, 1.4, 6.6]];
  const nPines = 260;
  const pineLayers = tiers.map(() => new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), pineMat, nPines));
  const capLayers = tiers.map(() => new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), capMat, nPines));
  const trunks = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1), trunkMat, nPines);
  const tmp = new THREE.Object3D();
  let placed = 0;
  while (placed < nPines) {
    const x = -260 + r() * 520, z = -240 + r() * 480;
    const inside = Math.abs(x) < 92 && Math.abs(z) < 70;
    if (inside) continue;
    const s = 1.3 + r() * 1.6, rot = r() * Math.PI;
    tmp.rotation.set(0, rot, 0);
    tmp.position.set(x, 1.2 * s - 0.4, z); tmp.scale.set(0.9 * s, 2.4 * s, 0.9 * s); tmp.updateMatrix();
    trunks.setMatrixAt(placed, tmp.matrix);
    tiers.forEach(([w, h, y], i) => {
      tmp.position.set(x, (y + 1.2) * s, z); tmp.scale.set(w * s, h * s, w * s); tmp.updateMatrix();
      pineLayers[i].setMatrixAt(placed, tmp.matrix);
      tmp.position.set(x, (y + 1.2 + h * 0.5 + 0.12) * s, z); tmp.scale.set(w * s * 0.8, 0.25 * s, w * s * 0.8); tmp.updateMatrix();
      capLayers[i].setMatrixAt(placed, tmp.matrix);
    });
    placed++;
  }
  for (const m of [...pineLayers, ...capLayers, trunks]) { m.castShadow = true; m.receiveShadow = true; scene.add(m); }

  // Дальние горы: без тумана, цвет заранее смешан с горизонтом
  const mountainMat = new THREE.MeshBasicMaterial({ vertexColors: true, fog: false });
  const shade = (geo, height) => {
    const pos = geo.attributes.position, cols = [];
    for (let i = 0; i < pos.count; i++) {
      const k = Math.min(1, Math.max(0, pos.getY(i) / height + 0.5));
      const c = look.fog.clone().lerp(look.mountain, Math.pow(k, 0.7));
      cols.push(c.r, c.g, c.b);
    }
    geo.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
    return geo;
  };
  const snowCapMat = new THREE.MeshBasicMaterial({ color: look.mountainCap, fog: false });
  for (let i = 0; i < 26; i++) {
    const ang = (i / 26) * Math.PI * 2 + r() * 0.2;
    const dist = 650 + r() * 200, height = 90 + r() * 160, rad = 120 + r() * 110;
    const segs = 5 + Math.floor(r() * 3);
    const cone = new THREE.Mesh(shade(new THREE.ConeGeometry(rad, height, segs).toNonIndexed(), height), mountainMat);
    cone.position.set(Math.cos(ang) * dist, height / 2 - 20, Math.sin(ang) * dist);
    cone.rotation.y = r() * 3;
    scene.add(cone);
    const cap = new THREE.Mesh(new THREE.ConeGeometry(rad * 0.28, height * 0.28, segs), snowCapMat);
    cap.position.copy(cone.position).y += height * 0.36 + 0.5;
    cap.rotation.y = cone.rotation.y;
    scene.add(cap);
  }

  // Детали из игры
  const studs = [];
  for (const p of data.parts) {
    const geo = geometry(p.s);
    const mesh = new THREE.Mesh(geo, material(p));
    const [x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22] = p.m;
    const basis = new THREE.Matrix4().set(r00, r01, r02, x, r10, r11, r12, y, r20, r21, r22, z, 0, 0, 0, 1);
    const sc = scaleFor(p);
    mesh.matrixAutoUpdate = false;
    mesh.matrix.copy(basis).multiply(new THREE.Matrix4().makeScale(...sc));
    const flat = y + p.size[1] / 2 < 0.6 && p.tag === 'map';
    mesh.castShadow = !flat && p.mat !== 'Neon' && p.t < 0.5;
    mesh.receiveShadow = true;
    scene.add(mesh);
    if (p.face) {
      const decal = new THREE.Mesh(
        new THREE.CylinderGeometry(0.505, 0.505, 0.62, 24, 1, true, Math.PI - 0.95, 1.9),
        new THREE.MeshStandardMaterial({ map: faceTexture(), transparent: true, roughness: 0.5, depthWrite: false,
          polygonOffset: true, polygonOffsetFactor: -2 }));
      decal.matrixAutoUpdate = false;
      decal.matrix.copy(mesh.matrix);
      decal.receiveShadow = true;
      scene.add(decal);
    }
    // Студы — настоящей геометрией на верхних гранях рядом с камерой
    if (p.studs && r11 > 0.98 && p.mat === 'Plastic') {
      const nx = Math.round(p.size[0]), nz = Math.round(p.size[2]);
      for (let i = 0; i < nx; i++) {
        for (let k = 0; k < nz; k++) {
          const lx = i + 0.5 - nx / 2, lz = k + 0.5 - nz / 2;
          const wx = x + r00 * lx + r02 * lz, wz = z + r20 * lx + r22 * lz, wy = y + p.size[1] / 2;
          const dx = wx - eye.x, dy = wy - eye.y, dz = wz - eye.z;
          const dist = Math.hypot(dx, dy, dz);
          if (dist > job.studRange) continue;
          if ((dx * forward.x + dy * forward.y + dz * forward.z) < -3) continue;
          studs.push([wx, wy, wz, p.c]);
        }
      }
    }
  }
  if (studs.length) {
    const sg = new THREE.CylinderGeometry(0.3, 0.3, 0.2, 14, 1, false);
    sg.translate(0, 0.1, 0);
    const inst = new THREE.InstancedMesh(sg, new THREE.MeshStandardMaterial({ roughness: 0.45 }), studs.length);
    studs.forEach(([sx, sy, sz, c], i) => {
      tmp.position.set(sx, sy, sz); tmp.rotation.set(0, 0, 0); tmp.scale.set(1, 1, 1); tmp.updateMatrix();
      inst.setMatrixAt(i, tmp.matrix);
      inst.setColorAt(i, srgb(c, 1.02));
    });
    inst.castShadow = false; inst.receiveShadow = true;
    scene.add(inst);
  }
  console.log('studs', studs.length);

  // Свет
  scene.add(new THREE.HemisphereLight(look.hemiSky, look.hemiGround, look.hemi));
  const key = new THREE.DirectionalLight(look.key, look.keyIntensity);
  const center = new THREE.Vector3(24, 0, -48);
  key.position.copy(center).addScaledVector(look.keyDir.clone().normalize(), 140);
  key.target.position.copy(center);
  key.castShadow = look.shadows !== false;
  key.shadow.mapSize.set(4096, 4096);
  Object.assign(key.shadow.camera, { left: -80, right: 80, top: 80, bottom: -80, near: 1, far: 320 });
  key.shadow.bias = -0.0003; key.shadow.normalBias = 0.03;
  scene.add(key, key.target);
  const fill = new THREE.DirectionalLight(look.fill, look.fillIntensity);
  fill.position.copy(center).add(look.fillDir.clone().multiplyScalar(100));
  fill.target.position.copy(center);
  scene.add(fill, fill.target);
  for (const l of data.lights) {
    const pl = new THREE.PointLight(srgb(l.c), l.b * l.range * 0.8, l.range * 1.5, 2);
    pl.position.set(...l.p);
    scene.add(pl);
  }
  return { scene, eye, target, forward, rng: r };
}

// ---------- Эффекты ----------
function addSprite(scene, tex, pos, size, color, opacity = 1, additive = true, rotation = 0) {
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: tex, color, transparent: true, opacity, rotation,
    blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending, depthWrite: false }));
  s.position.copy(pos);
  s.scale.set(size, size, 1);
  scene.add(s);
  return s;
}
function beam(scene, from, to, radius, color, opacity = 1) {
  const dir = to.clone().sub(from);
  const len = dir.length();
  const geo = new THREE.CylinderGeometry(radius, radius, len, 8, 1, true);
  const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color, transparent: true, opacity, blending: THREE.AdditiveBlending, depthWrite: false }));
  m.position.copy(from).addScaledVector(dir, 0.5);
  m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.normalize());
  scene.add(m);
  return m;
}
// Дуга удара: лента с затуханием к хвосту (цвет вершин при сложении = яркость)
function slash(scene, center, normal, startDir, radius, width, arc, color) {
  const n = 48, pos = [], col = [], idx = [];
  const nrm = normal.clone().normalize();
  const u = startDir.clone().projectOnPlane(nrm).normalize();
  const v = new THREE.Vector3().crossVectors(nrm, u);
  for (let i = 0; i <= n; i++) {
    const t = i / n, a = t * arc;
    const dir = u.clone().multiplyScalar(Math.cos(a)).addScaledVector(v, Math.sin(a));
    const w = width * Math.sin(Math.PI * Math.min(1, t * 1.15)) + 0.02;
    const inner = center.clone().addScaledVector(dir, radius - w), outer = center.clone().addScaledVector(dir, radius);
    pos.push(...inner.toArray(), ...outer.toArray());
    const k = Math.pow(t, 1.6);
    col.push(color.r * k * 0.5, color.g * k * 0.5, color.b * k * 0.5, color.r * k, color.g * k, color.b * k);
    if (i < n) idx.push(i * 2, i * 2 + 1, i * 2 + 2, i * 2 + 1, i * 2 + 3, i * 2 + 2);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  g.setAttribute('color', new THREE.Float32BufferAttribute(col, 3));
  g.setIndex(idx);
  const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.DoubleSide, transparent: true,
    blending: THREE.AdditiveBlending, depthWrite: false }));
  scene.add(m);
  return m;
}

function addEffects(world, data, job, look) {
  const { scene, rng: r } = world;
  const V = (a) => new THREE.Vector3(...a);
  const tower = (id) => data.towers.find((t) => t.id === id && !t.stage);
  const enemy = (id) => data.enemies.find((e) => e.id === id);
  const glow = glowTexture(), star = starTexture();
  const warm = new THREE.Color(1.0, 0.72, 0.32);

  // Пулемёт: вспышка, свет и очередь трассеров
  const mg = tower('minigunner');
  if (mg && mg.muzzles[0]) {
    const muzzle = V(mg.muzzles[0]);
    const aim = V(mg.aim).setY(4.2);
    const dir = aim.clone().sub(muzzle).normalize();
    addSprite(scene, star, muzzle.clone().addScaledVector(dir, 0.35), 2.6, warm.clone().multiplyScalar(4), 1, true, 0.3);
    addSprite(scene, glow, muzzle, 4.5, new THREE.Color(1, 0.55, 0.2).multiplyScalar(1.4), 0.9);
    const pl = new THREE.PointLight(0xffa04a, 25, 8, 2); pl.position.copy(muzzle).addScaledVector(dir, 0.6); scene.add(pl);
    for (let i = 0; i < 9; i++) {
      const spread = new THREE.Vector3((r() - 0.5) * 0.05, (r() - 0.5) * 0.04, (r() - 0.5) * 0.05);
      const d = dir.clone().add(spread).normalize();
      const start = 1.5 + i * 3.1 + r() * 1.2;
      const a = muzzle.clone().addScaledVector(d, start), b = muzzle.clone().addScaledVector(d, start + 1.6 + r());
      beam(scene, a, b, 0.045, warm.clone().multiplyScalar(5), 1);
    }
    // гильзы
    for (let i = 0; i < 7; i++) {
      const p = muzzle.clone().add(new THREE.Vector3(1.2 + r() * 1.5, 0.2 + r() * 1.4, 0.6 + r() * 1.4));
      const c = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.22, 8), new THREE.MeshStandardMaterial({ color: 0xd8a640, metalness: 0.9, roughness: 0.3 }));
      c.position.copy(p); c.rotation.set(r() * 3, r() * 3, r() * 3); scene.add(c);
    }
  }
  // Снайпер: луч через всё поле в босса
  const sn = tower('sniper'), boss = enemy('boss_warlord');
  if (sn && sn.muzzles[0] && boss) {
    const muzzle = V(sn.muzzles[0]);
    const hit = V(boss.at).add(new THREE.Vector3(1.0, -2.6, -0.4));
    beam(scene, muzzle, hit, 0.025, new THREE.Color(1, 0.95, 0.8).multiplyScalar(2.2), 0.7);
    addSprite(scene, star, muzzle, 1.8, new THREE.Color(1, 0.9, 0.7).multiplyScalar(3), 1, true, 0.8);
    addSprite(scene, star, hit, 5, new THREE.Color(1, 0.85, 0.6).multiplyScalar(3), 1);
    addSprite(scene, glow, hit, 9, new THREE.Color(1, 0.5, 0.2), 0.8);
  }
  // Пистолеты
  const ps = tower('pistol');
  if (ps) {
    for (const m of ps.muzzles) {
      addSprite(scene, star, V(m), 1.4, warm.clone().multiplyScalar(3.5), 1, true, r() * 3);
    }
  }
  // Токсик: облако яда в сторону цели
  const tx = tower('toxic');
  if (tx && tx.muzzles[0]) {
    const muzzle = V(tx.muzzles[0]), aim = V(tx.aim).setY(3.2);
    const dir = aim.clone().sub(muzzle);
    for (let i = 0; i < 26; i++) {
      const t = i / 25;
      const p = muzzle.clone().addScaledVector(dir, t * 0.95).add(new THREE.Vector3((r() - 0.5) * 2.4 * t, (r() - 0.5) * 1.6 * t, (r() - 0.5) * 2.4 * t));
      addSprite(scene, smokeTexture(3 + (i % 4)), p, 0.8 + t * 2.4, new THREE.Color(0.32, 0.95, 0.22), 0.9 - t * 0.35, false, r() * 6);
    }
    const pl = new THREE.PointLight(0x66ff44, 25, 10, 1.5); pl.position.copy(muzzle).addScaledVector(dir, 0.6); scene.add(pl);
  }
  // Мечник и Росомаха: дуги ударов
  const sw = tower('swordsman');
  if (sw) {
    const c = V(sw.at).add(new THREE.Vector3(0, 0.6, 0));
    const d = V(sw.aim).sub(V(sw.at)).setY(0).normalize();
    slash(scene, c, new THREE.Vector3(0.25, 1, 0.3), d.clone().applyAxisAngle(new THREE.Vector3(0, 1, 0), 1.4), 3.6, 0.55, 2.2, new THREE.Color(0.55, 0.85, 1).multiplyScalar(1.1));
  }
  const wv = tower('wolverine');
  if (wv) {
    const c = V(wv.at).add(new THREE.Vector3(0, 0.4, 0));
    const d = V(wv.aim).sub(V(wv.at)).setY(0).normalize();
    for (let i = 0; i < 3; i++) {
      slash(scene, c.clone().add(new THREE.Vector3(0, i * 0.45 - 0.3, 0)), new THREE.Vector3(-0.5, 1, 0.2),
        d.clone().applyAxisAngle(new THREE.Vector3(0, 1, 0), 1.1), 3.2 + i * 0.25, 0.22, 2.0, new THREE.Color(1, 0.6, 0.25).multiplyScalar(3));
    }
  }
  const iconHero = data.towers.find((t) => t.stage === 'icon');
  if (iconHero) {
    const d = V(iconHero.aim).sub(V(iconHero.at)).setY(0).normalize();
    const c = V(iconHero.at).addScaledVector(d, -1.2).add(new THREE.Vector3(0, 1.4, 0));
    const back = V(iconHero.at).addScaledVector(d, -5);
    const rimA = new THREE.PointLight(0x55ccff, 260, 20, 1.6); rimA.position.copy(back).add(new THREE.Vector3(2.5, 5, 3)); scene.add(rimA);
    const rimB = new THREE.PointLight(0xff8a3c, 200, 20, 1.6); rimB.position.copy(back).add(new THREE.Vector3(-2.5, 4, -3.5)); scene.add(rimB);
    for (let i = 0; i < 3; i++) {
      slash(scene, c.clone().add(new THREE.Vector3(0, i * 0.4 - 0.4, 0)), new THREE.Vector3(-d.x * 0.6, 1, -d.z * 0.6),
        d.clone().applyAxisAngle(new THREE.Vector3(0, 1, 0), 1.9), 3.0 + i * 0.22, 0.2, 2.1, new THREE.Color(1, 0.62, 0.25).multiplyScalar(2.4));
    }
  }
  // Босс: кольцо топота и красное свечение
  if (boss) {
    const ring = new THREE.Mesh(new THREE.RingGeometry(5.5, 7.2, 64).rotateX(-Math.PI / 2),
      new THREE.MeshBasicMaterial({ color: new THREE.Color(1, 0.15, 0.1).multiplyScalar(2.5), transparent: true, opacity: 0.85,
        blending: THREE.AdditiveBlending, depthWrite: false }));
    ring.position.set(boss.at[0], 0.35, boss.at[2]);
    scene.add(ring);
    addSprite(scene, glow, V(boss.at).add(new THREE.Vector3(-2, -6, 0)), 26, new THREE.Color(1, 0.12, 0.08), 0.3);
    // «Геройский» свет на босса спереди-сверху и красный контровой сзади
    const spot = new THREE.SpotLight(0xdde8ff, 160, 60, 0.42, 0.7, 1.2);
    spot.position.set(boss.at[0] + 9, 27, boss.at[2] + 3);
    spot.target.position.set(boss.at[0], 7, boss.at[2]);
    scene.add(spot, spot.target);
    const rim = new THREE.PointLight(0xff3020, 220, 30, 1.4);
    rim.position.set(boss.at[0] - 6, 12, boss.at[2] + 2);
    scene.add(rim);
  }
  // Портал
  const portal = new THREE.Vector3(-82, 5, -48);
  addSprite(scene, glow, portal, 30, new THREE.Color(0.75, 0.3, 1.0), 0.6);

  // Туман у земли
  for (let i = 0; i < 60; i++) {
    const x = -90 + r() * 140, z = -48 + (r() - 0.5) * 60;
    const p = new THREE.Vector3(x, 0.6 + r() * 1.6, z);
    if (p.distanceTo(world.eye) < 30) continue;
    addSprite(scene, smokeTexture(11 + (i % 5)), p, 14 + r() * 22, look.mist, look.mistOpacity, false, r() * 6);
  }
  // Снег
  const n = 2600, pos = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) {
    const dist = 3 + Math.pow(r(), 0.7) * 90;
    const side = (r() - 0.5) * dist * 1.4, up = -1 + r() * dist * 0.7;
    const right = new THREE.Vector3().crossVectors(world.forward, new THREE.Vector3(0, 1, 0)).normalize();
    const p = world.eye.clone().addScaledVector(world.forward, dist).addScaledVector(right, side).add(new THREE.Vector3(0, up, 0));
    pos.set([p.x, p.y, p.z], i * 3);
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  scene.add(new THREE.Points(g, new THREE.PointsMaterial({ map: flakeTexture(), size: 0.22, transparent: true, opacity: 0.9,
    depthWrite: false, color: 0xeef6ff, sizeAttenuation: true })));
  // Крупные «размытые» снежинки у камеры
  for (let i = 0; i < 8; i++) {
    const right = new THREE.Vector3().crossVectors(world.forward, new THREE.Vector3(0, 1, 0)).normalize();
    const d = 1.2 + r() * 3;
    const p = world.eye.clone().addScaledVector(world.forward, d).addScaledVector(right, (r() - 0.5) * d * 1.3).add(new THREE.Vector3(0, (r() - 0.45) * d * 0.7, 0));
    addSprite(scene, glow, p, 0.04 + r() * 0.08, new THREE.Color(0.8, 0.88, 1), 0.2 + r() * 0.2, false);
  }
}

// ---------- Логотип ----------
function logoText(g, text, x, y, size, opts) {
  g.save();
  g.font = `${size}px Fredoka`;
  g.textAlign = 'center';
  g.textBaseline = 'alphabetic';
  g.lineJoin = 'round';
  const depth = Math.round(size * opts.depth);
  // объём (экструзия вниз)
  for (let i = depth; i >= 1; i--) {
    g.lineWidth = size * opts.stroke;
    g.strokeStyle = opts.side; g.fillStyle = opts.side;
    g.strokeText(text, x, y + i); g.fillText(text, x, y + i);
  }
  // тень под объёмом
  g.shadowColor = 'rgba(0,0,0,0.55)'; g.shadowBlur = size * 0.25; g.shadowOffsetY = size * 0.1;
  g.lineWidth = size * opts.stroke; g.strokeStyle = opts.outline;
  g.strokeText(text, x, y + depth);
  g.shadowColor = 'transparent';
  g.strokeText(text, x, y);
  // лицевая сторона с градиентом
  const m = g.measureText(text);
  const top = y - m.actualBoundingBoxAscent, bottom = y + m.actualBoundingBoxDescent;
  const gr = g.createLinearGradient(0, top, 0, bottom);
  opts.fill.forEach(([s, c]) => gr.addColorStop(s, c));
  g.fillStyle = gr;
  g.fillText(text, x, y);
  // блик сверху
  g.save();
  g.beginPath(); g.rect(x - m.width, top - 4, m.width * 2, (bottom - top) * 0.42); g.clip();
  g.fillStyle = 'rgba(255,255,255,0.28)';
  g.fillText(text, x, y);
  g.restore();
  // тонкая внутренняя обводка
  g.lineWidth = Math.max(2, size * 0.022); g.strokeStyle = opts.inner;
  g.strokeText(text, x, y);
  g.restore();
  return m.width;
}

function drawLogo(g, W, H, mode) {
  const ice = { fill: [[0, '#ffffff'], [0.45, '#d4f6ff'], [0.75, '#6cc8ff'], [1, '#2f7fe6']], side: '#0d2c66', outline: '#06143a', inner: 'rgba(255,255,255,0.5)', stroke: 0.16, depth: 0.1 };
  const gold = { fill: [[0, '#fff6c2'], [0.45, '#ffd23f'], [0.8, '#ff9a1a'], [1, '#e8650c']], side: '#7a2d05', outline: '#2a0d02', inner: 'rgba(255,255,255,0.45)', stroke: 0.16, depth: 0.1 };
  if (mode === 'icon') {
    const cx = W / 2;
    badge(g, W * 0.15, H * 0.15, W * 0.1, -0.12);
    logoText(g, 'TOWER', cx, H * 0.79, W * 0.2, ice);
    logoText(g, 'DEFENSE', cx, H * 0.95, W * 0.155, gold);
    return;
  }
  const cx = W * 0.225;
  logoText(g, 'TOWER', cx + W * 0.01, H * 0.2, W * 0.072, ice);
  logoText(g, 'DEFENSE', cx, H * 0.29, W * 0.06, gold);
  badge(g, cx + W * 0.01, H * 0.07, W * 0.034, -0.08);
}

// Значок «R6»: щит с красным градиентом
function badge(g, x, y, r, tilt) {
  g.save();
  g.translate(x, y); g.rotate(tilt);
  const shield = () => {
    g.beginPath();
    g.moveTo(-r, -r * 0.85);
    g.quadraticCurveTo(0, -r * 1.15, r, -r * 0.85);
    g.lineTo(r * 0.92, r * 0.1);
    g.quadraticCurveTo(r * 0.7, r * 0.85, 0, r * 1.2);
    g.quadraticCurveTo(-r * 0.7, r * 0.85, -r * 0.92, r * 0.1);
    g.closePath();
  };
  g.shadowColor = 'rgba(0,0,0,0.5)'; g.shadowBlur = r * 0.4; g.shadowOffsetY = r * 0.12;
  g.fillStyle = '#3a0505'; g.translate(0, r * 0.12); shield(); g.fill(); g.translate(0, -r * 0.12);
  g.shadowColor = 'transparent';
  g.lineWidth = r * 0.22; g.strokeStyle = '#1a0202'; shield(); g.stroke();
  const gr = g.createLinearGradient(0, -r, 0, r * 1.2);
  gr.addColorStop(0, '#ff6b5a'); gr.addColorStop(0.5, '#e01e1e'); gr.addColorStop(1, '#8a0b0b');
  g.fillStyle = gr; shield(); g.fill();
  g.lineWidth = r * 0.07; g.strokeStyle = '#ffd23f'; shield(); g.stroke();
  g.font = `${r * 1.05}px Fredoka`; g.textAlign = 'center'; g.textBaseline = 'middle';
  g.lineJoin = 'round'; g.lineWidth = r * 0.18; g.strokeStyle = '#3a0505';
  g.strokeText('R6', 0, r * 0.08); g.fillStyle = '#fff'; g.fillText('R6', 0, r * 0.08);
  g.restore();
}

// ---------- Точка входа ----------
export async function render(job) {
  sceneData ??= await (await fetch('/scene.json')).json();
  if (!fontLoaded) {
    const f = new FontFace('Fredoka', 'url(/font.ttf)');
    await f.load(); document.fonts.add(f); fontLoaded = true;
  }
  const look = {
    zenith: hex(0x050a1f), horizon: hex(0x1c3a6e), glow: new THREE.Color(0.12, 0.25, 0.45),
    moonDir: new THREE.Vector3(-1, 0.33, -0.42).normalize(), aurora: 0.9,
    fog: hex(0x1b3563), fogDensity: 0.0062,
    mountain: hex(0x3a5f9a), mountainCap: hex(0x9fb8e0),
    hemiSky: hex(0x7d9fff), hemiGround: hex(0x1d2440), hemi: 0.35,
    key: hex(0xcfe0ff), keyIntensity: 4.5, keyDir: new THREE.Vector3(-1, 0.7, -0.5),
    fill: hex(0xffa565), fillIntensity: 1.5, fillDir: new THREE.Vector3(1, 0.6, 0.45).normalize(),
    mist: new THREE.Color(0.42, 0.56, 0.85), mistOpacity: 0.16, env: 0.6,
  };
  Object.assign(look, job.look || {});
  const ss = job.ss || 1;
  const w = Math.round(job.width * ss), h = Math.round(job.height * ss);
  const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(1);
  renderer.setSize(w, h, false);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.0;

  const world = buildWorld(sceneData, { ...job, studRange: job.studRange ?? 75 }, look);
  addEffects(world, sceneData, job, look);
  const pm = new THREE.PMREMGenerator(renderer);
  const envScene = new THREE.Scene();
  envScene.add(skyMesh([0, 0, 0], { ...look, aurora: 1.4 }));
  world.scene.environment = pm.fromScene(envScene, 0.04).texture;
  world.scene.environmentIntensity = look.env;

  const camera = new THREE.PerspectiveCamera(job.fov, job.width / job.height, 0.1, 3000);
  camera.position.copy(world.eye);
  camera.lookAt(world.target);

  const composer = new EffectComposer(renderer, new THREE.WebGLRenderTarget(w, h, { type: THREE.HalfFloatType, samples: 4 }));
  composer.setSize(w, h);
  composer.addPass(new RenderPass(world.scene, camera));
  composer.addPass(new UnrealBloomPass(new THREE.Vector2(w, h), 0.4, 0.4, 0.95));
  composer.addPass(new OutputPass());
  composer.render();

  // Итог: уменьшение (сглаживание), цветокоррекция, виньетка и логотип
  const out = document.createElement('canvas');
  out.width = job.width; out.height = job.height;
  const g = out.getContext('2d');
  g.imageSmoothingQuality = 'high';
  g.filter = 'contrast(1.1) saturate(1.22)';
  g.drawImage(renderer.domElement, 0, 0, job.width, job.height);
  g.filter = 'none';
  const W = job.width, H = job.height;
  const top = g.createLinearGradient(0, 0, 0, H * 0.45);
  top.addColorStop(0, 'rgba(4,8,30,0.35)'); top.addColorStop(1, 'rgba(4,8,30,0)');
  g.fillStyle = top; g.fillRect(0, 0, W, H);
  const vig = g.createRadialGradient(W / 2, H * 0.55, Math.min(W, H) * 0.35, W / 2, H * 0.55, Math.max(W, H) * 0.75);
  vig.addColorStop(0, 'rgba(0,0,0,0)'); vig.addColorStop(1, 'rgba(2,4,18,0.6)');
  g.fillStyle = vig; g.fillRect(0, 0, W, H);
  const bottom = g.createLinearGradient(0, H * 0.7, 0, H);
  bottom.addColorStop(0, 'rgba(8,16,48,0)'); bottom.addColorStop(1, 'rgba(8,16,48,0.45)');
  g.fillStyle = bottom; g.fillRect(0, 0, W, H);
  if (job.logo !== false) drawLogo(g, W, H, job.mode);

  renderer.dispose();
  return out.toDataURL('image/png');
}
