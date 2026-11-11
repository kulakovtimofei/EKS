import * as THREE from 'three';
import './style.css';
import { sfx, initAudio } from './audio';
import { CITIES } from './data';
import { Input } from './input';
import {
  RADIUS,
  applyControls,
  clamp,
  createPlayerState,
  judgeLanding,
  maxSpeed,
  rampHeight,
  resolveCollisions,
  stepVertical,
  type Upgrades,
} from './physics';
import { PostFX } from './render/post';
import { rnd, snap } from './render/psx';
import { has, loadSave, persist, wearing } from './save';
import { renderShop, type ShopTab } from './ui/shop';
import { Speedo } from './ui/speedo';
import { buildCity, randomStreetPoint, type World } from './world/city';
import { HALF } from './world/layout';
import { Crowd } from './world/pedestrians';
import { buildRider } from './world/player';

const $ = (id: string) => document.getElementById(id) as HTMLElement;
const storage = (() => {
  try {
    return window.localStorage;
  } catch {
    return null;
  }
})();
const save = loadSave(storage);
const store = () => persist(storage, save);

/* ---------------- renderer ---------------- */
const INTERNAL_H = 360;
const canvas = $('c') as HTMLCanvasElement;
const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(1);
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(62, 1, 0.1, 400);
const post = new PostFX();
function resize() {
  const aspect = innerWidth / innerHeight;
  const h = INTERNAL_H, w = Math.round(h * aspect);
  renderer.setSize(w, h, false);
  post.setSize(w, h);
  camera.aspect = aspect;
  camera.updateProjectionMatrix();
  snap.value.set(w / 2, h / 2);
}
addEventListener('resize', resize);
resize();

// Overcast, soft light — flat ambient with a weak sun, like old console lighting.
scene.add(new THREE.HemisphereLight(0xfff4e0, 0x5a5048, 0.8 * Math.PI));
const sun = new THREE.DirectionalLight(0xffffff, 0.6 * Math.PI);
sun.position.set(40, 80, 25);
scene.add(sun);

/* ---------------- world ---------------- */
let world: World = buildCity(scene, CITIES.find((c) => c.id === save.city) ?? CITIES[0], null);
let crowd = new Crowd(world.group);

const rider = buildRider();
scene.add(rider.root);
const P = createPlayerState();
const upgrades = (): Upgrades => ({ turbo: has(save, 'turbo'), spring: has(save, 'spring') });
function applyLook() {
  rider.setLook({
    glasses: wearing(save, 'glasses'),
    cap: wearing(save, 'cap'),
    beanie: wearing(save, 'beanie'),
    phones: wearing(save, 'phones'),
    stripes: wearing(save, 'stripes'),
    neon: wearing(save, 'neon'),
    golddeck: wearing(save, 'golddeck'),
  });
}

/* ---------------- state + HUD ---------------- */
type Mode = 'title' | 'play' | 'shop';
let mode: Mode = 'title';
let tab: ShopTab = 'look';
let nearShop = false;
let trickTimer = 0;
let coinDirty = false;
const input = new Input(() => mode === 'play');
const speedo = new Speedo($('speed'));
if (input.isTouch) $('touch').classList.add('on');

function showTrick(main: string, sub = '') {
  const el = $('trick');
  el.textContent = main;
  if (sub) {
    const s = document.createElement('small');
    s.textContent = sub;
    el.appendChild(s);
  }
  el.style.opacity = '1';
  trickTimer = 1.4;
}
function updateCoinsHud() {
  $('coinCount').textContent = String(save.coins);
  $('shopCoins').textContent = String(save.coins);
}
function showBanner(text: string) {
  const b = $('banner');
  b.textContent = text;
  b.style.opacity = '1';
  setTimeout(() => (b.style.opacity = '0'), 1800);
}
function setCityName() {
  ($('cityName').firstChild as Text).textContent = world.city.name;
}

/* ---------------- shop ---------------- */
const shopHooks = {
  save,
  currentCity: () => world.city.id,
  onChange: () => {
    store();
    applyLook();
    updateCoinsHud();
  },
  onBuy: () => sfx.buy(),
  onTravel: (id: string) => travel(id),
};
function openShop() {
  mode = 'shop';
  input.releaseAll();
  P.speed = 0;
  renderShop($('items'), tab, shopHooks);
  updateCoinsHud();
  $('shop').classList.remove('hidden');
  sfx.open();
  setTimeout(() => (document.querySelector('#shop .tab.on') as HTMLElement | null)?.focus(), 0);
}
function closeShop() {
  mode = 'play';
  $('shop').classList.add('hidden');
}
$('closeShop').addEventListener('click', closeShop);
document.querySelectorAll<HTMLElement>('.tab').forEach((t) =>
  t.addEventListener('click', () => {
    tab = t.dataset.tab as ShopTab;
    document.querySelectorAll('.tab').forEach((x) => x.classList.toggle('on', x === t));
    renderShop($('items'), tab, shopHooks);
  }),
);
addEventListener('keydown', (e) => {
  if (e.code === 'Escape' && mode === 'shop') closeShop();
  else if (e.code === 'KeyE' && mode === 'play' && nearShop) openShop();
});
$('tShop').addEventListener('pointerdown', (e) => {
  e.preventDefault();
  if (nearShop) openShop();
});

function travel(id: string) {
  const c = CITIES.find((x) => x.id === id);
  if (!c) return;
  save.city = id;
  store();
  world = buildCity(scene, c, world);
  crowd = new Crowd(world.group);
  respawn();
  closeShop();
  setCityName();
  showBanner(c.name.toUpperCase());
}

const camPos = new THREE.Vector3(0, 4, 8);
function respawn() {
  Object.assign(P, createPlayerState(), { x: world.shopPos.x, z: world.shopPos.z + 5, h: Math.PI / 2 });
  camPos.set(P.x, 4, P.z + 8);
}

/* ---------------- simulation ---------------- */
function land() {
  const r = judgeLanding(P.spin, P.air, P.whip);
  if (r.kind === 'fall') {
    P.speed *= 0.1;
    P.bump = 0.35;
    showTrick('Падение!', 'приземляйся ровно');
    sfx.fall();
  } else if (r.kind === 'trick' || r.kind === 'air') {
    save.coins += r.bonus;
    store();
    updateCoinsHud();
    showTrick(r.kind === 'trick' ? r.name : 'Полёт!', '+' + r.bonus);
    if (r.kind === 'trick') sfx.trick();
    else sfx.air();
  }
  P.spin = 0;
  P.whip = 0;
  P.air = 0;
}

function step(dt: number) {
  const up = upgrades();
  applyControls(P, input.keys, up, dt);

  const px = P.x, pz = P.z;
  P.x -= Math.sin(P.h) * P.speed * dt;
  P.z -= Math.cos(P.h) * P.speed * dt;
  let hit = resolveCollisions(P, world.colliders, HALF, RADIUS);
  if (crowd.collide(P, RADIUS)) {
    hit = true;
    P.speed *= 0.4;
  }
  if (hit && Math.abs(P.speed) > 6) {
    sfx.bump();
    P.bump = 0.25;
  }
  if (hit) P.speed *= 0.55;

  let g = rampHeight(world.ramps, P.x, P.z);
  // Riding into the tall side of a ramp is a wall.
  if (g - P.y > 0.45) {
    P.x = px;
    P.z = pz;
    P.speed *= 0.3;
    g = rampHeight(world.ramps, P.x, P.z);
  }
  const ev = stepVertical(P, g, input.takeJump(), up, dt);
  if (ev === 'jump') sfx.jump();
  if (ev === 'land') land();

  // coins
  const magnet = has(save, 'magnet');
  for (const c of world.coins) {
    if (!c.active) {
      c.respawn -= dt;
      if (c.respawn <= 0) {
        if (!c.fixed) {
          const p = randomStreetPoint();
          c.mesh.position.set(p.x, c.baseY, p.z);
        }
        c.mesh.position.y = c.baseY;
        c.active = true;
        c.mesh.visible = true;
      }
      continue;
    }
    c.mesh.rotation.z += dt * 3;
    const dx = P.x - c.mesh.position.x, dy = P.y + 0.9 - c.mesh.position.y, dz = P.z - c.mesh.position.z;
    const d = Math.hypot(dx, dy, dz);
    if (magnet && d < 7) {
      const pull = Math.min(1, dt * 9);
      c.mesh.position.x += dx * pull;
      c.mesh.position.y += dy * pull;
      c.mesh.position.z += dz * pull;
    }
    if (d < 1.5) {
      c.active = false;
      c.mesh.visible = false;
      c.respawn = rnd(18, 30);
      save.coins += c.value;
      updateCoinsHud();
      coinDirty = true;
      sfx.coin(c.value > 1);
    }
  }

  // shop proximity
  const ds = Math.hypot(P.x - world.shopPos.x, P.z - (world.shopPos.z + 2));
  nearShop = ds < 4.5 && P.ground;
  $('prompt').style.display = nearShop && !input.isTouch ? 'block' : 'none';
  $('tShop').style.display = nearShop ? 'flex' : 'none';
  $('shopDist').textContent = ds > 12 ? 'до ларька ' + Math.round(ds) + ' м' : world.city.sub;
}
setInterval(() => {
  if (coinDirty) {
    store();
    coinDirty = false;
  }
}, 2000);

/* ---------------- camera + animation + render ---------------- */
const look = new THREE.Vector3();
const target = new THREE.Vector3();
let last = performance.now(), t = 0;
function frame(now: number) {
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, (now - last) / 1000);
  last = now;
  t += dt;
  if (mode === 'play') step(dt);
  crowd.update(dt);

  const keys = input.keys;
  const steer = (keys.left ? 1 : 0) - (keys.right ? 1 : 0);
  rider.root.position.set(P.x, P.y, P.z);
  rider.root.rotation.y = P.h;
  rider.body.rotation.y = P.spin;
  rider.scooter.rotation.y = P.whip;
  const leanTarget = P.ground ? steer * 0.22 * clamp(Math.abs(P.speed) / 8, 0, 1) : 0;
  rider.body.rotation.z += (leanTarget - rider.body.rotation.z) * Math.min(1, dt * 8);
  rider.body.position.y = P.ground ? Math.abs(Math.sin(t * 14)) * 0.015 * clamp(Math.abs(P.speed) / 10, 0, 1) : 0;
  // Push-off animation: the back leg kicks while accelerating, tucks up in the air.
  const kicking = mode === 'play' && P.ground && keys.up && P.speed < maxSpeed(upgrades()) - 0.1;
  const legTarget = !P.ground ? -0.5 : kicking ? Math.sin(t * 9) * 0.55 + 0.25 : 0;
  rider.kickLeg.rotation.x += (legTarget - rider.kickLeg.rotation.x) * Math.min(1, dt * 12);

  const behind = 6.4 + Math.abs(P.speed) * 0.08;
  target.set(P.x + Math.sin(P.h) * behind, P.y + 3.1, P.z + Math.cos(P.h) * behind);
  if (mode === 'title') {
    const a = t * 0.15;
    target.set(world.shopPos.x + Math.sin(a) * 14, 6, world.shopPos.z + 6 + Math.cos(a) * 14);
  }
  camPos.lerp(target, 1 - Math.exp(-dt * 5));
  camera.position.copy(camPos);
  if (P.bump > 0) {
    camera.position.x += rnd(-1, 1) * P.bump * 0.3;
    camera.position.y += rnd(-1, 1) * P.bump * 0.3;
    P.bump -= dt;
  }
  look.set(P.x - Math.sin(P.h) * 2, P.y + 1.2, P.z - Math.cos(P.h) * 2);
  camera.lookAt(look);

  if (trickTimer > 0) {
    trickTimer -= dt;
    if (trickTimer <= 0) $('trick').style.opacity = '0';
  }
  speedo.set(Math.abs(P.speed) * 3.6);
  post.render(renderer, scene, camera, t);
}

/* ---------------- start ---------------- */
setCityName();
respawn();
applyLook();
updateCoinsHud();
$('startBtn').addEventListener('click', () => {
  initAudio();
  $('title').classList.add('hidden');
  mode = 'play';
  respawn();
  showBanner(world.city.name.toUpperCase());
});
$('startBtn').focus();
requestAnimationFrame(frame);
