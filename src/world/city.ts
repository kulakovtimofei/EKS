import * as THREE from 'three';
import type { CityDef } from '../data';
import type { Collider, Ramp } from '../physics';
import { boxUV, canvasTex, dirtTex, disposeGroup, grain, lam, pick, psx, rnd } from '../render/psx';
import { BS, HALF, N, PLAZA, blockRect, streetLine, type Rect } from './layout';

export interface Coin {
  mesh: THREE.Mesh;
  value: number;
  active: boolean;
  respawn: number;
  baseY: number;
  /** Coins over ramps stay put; street coins move when they respawn. */
  fixed: boolean;
}

export interface World {
  city: CityDef;
  group: THREE.Group;
  colliders: Collider[];
  ramps: Ramp[];
  coins: Coin[];
  shopPos: THREE.Vector3;
}

function facadeTex(city: CityDef, color: string) {
  return canvasTex(32, 32, (g) => {
    g.fillStyle = color;
    g.fillRect(0, 0, 32, 32);
    if (city.brick) {
      g.fillStyle = 'rgba(0,0,0,0.22)';
      for (let y = 0; y < 32; y += 3) {
        g.fillRect(0, y, 32, 1);
        for (let x = ((y / 3) % 2) * 4; x < 32; x += 8) g.fillRect(x, y, 1, 3);
      }
    }
    if (city.stone) {
      g.strokeStyle = 'rgba(60,50,40,0.35)';
      for (let y = 0; y < 32; y += 5) {
        let x = -Math.random() * 6;
        while (x < 32) {
          const w = rnd(5, 10);
          g.strokeRect(x + 0.5, y + 0.5, w, 5);
          x += w;
        }
      }
    }
    if (city.tiles) {
      for (let y = 0; y < 32; y += 4)
        for (let x = 0; x < 32; x += 4) {
          g.fillStyle = ((x + y) / 4) % 2 ? 'rgba(40,80,160,0.30)' : 'rgba(255,255,255,0.18)';
          g.fillRect(x, y, 4, 4);
          g.fillStyle = 'rgba(30,60,140,0.35)';
          g.fillRect(x + 1, y + 1, 2, 2);
        }
    }
    // water stains running down from the window sill
    g.fillStyle = 'rgba(40,30,20,0.12)';
    for (let i = 0; i < 4; i++) g.fillRect(Math.floor(rnd(6, 26)), 25, 1, Math.floor(rnd(3, 7)));
    grain(g, 32, 32, 28);
    const wx = 10, wy = 6, ww = 12, wh = 17;
    g.fillStyle = city.trim;
    g.fillRect(wx - 2, wy - 2, ww + 4, wh + 4);
    g.fillStyle = '#28313b';
    g.fillRect(wx, wy, ww, wh);
    g.fillStyle = 'rgba(180,205,225,0.35)';
    g.fillRect(wx + 1, wy + 1, 3, wh - 2);
    g.fillStyle = city.trim;
    g.fillRect(wx + 5, wy, 2, wh);
    g.fillRect(wx, wy + 7, ww, 2);
    if (city.shutter) {
      g.fillStyle = city.shutter;
      g.fillRect(wx - 6, wy, 4, wh);
      g.fillRect(wx + ww + 2, wy, 4, wh);
    }
    g.fillStyle = 'rgba(0,0,0,0.35)';
    g.fillRect(wx - 2, wy + wh + 2, ww + 4, 2);
  });
}

function roofTex(color: string) {
  return canvasTex(32, 32, (g) => {
    g.fillStyle = color;
    g.fillRect(0, 0, 32, 32);
    g.fillStyle = 'rgba(0,0,0,0.25)';
    for (let y = 0; y < 32; y += 4) {
      g.fillRect(0, y + 3, 32, 1);
      for (let x = ((y / 4) % 2) * 3; x < 32; x += 6) g.fillRect(x, y, 1, 4);
    }
    grain(g, 32, 32, 30);
  });
}

function cobbleTex(color: string) {
  return canvasTex(64, 64, (g) => {
    g.fillStyle = '#3a3734';
    g.fillRect(0, 0, 64, 64);
    const base = new THREE.Color(color);
    for (let y = 0; y < 64; y += 6)
      for (let x = ((y / 6) % 2) * 3; x < 64; x += 6) {
        const c = base.clone().multiplyScalar(rnd(0.8, 1.15));
        g.fillStyle = '#' + c.getHexString();
        g.fillRect(x + 0.5, y + 0.5, 5, 5);
      }
    grain(g, 64, 64, 22);
  });
}

function sidewalkTex() {
  return canvasTex(32, 32, (g) => {
    g.fillStyle = '#a9a39a';
    g.fillRect(0, 0, 32, 32);
    g.fillStyle = 'rgba(0,0,0,0.25)';
    for (let i = 0; i < 32; i += 8) {
      g.fillRect(i, 0, 1, 32);
      g.fillRect(0, i, 32, 1);
    }
    grain(g, 32, 32, 20);
  });
}

export function signTex(text: string, bg: string, fg: string) {
  return canvasTex(128, 32, (g) => {
    g.fillStyle = bg;
    g.fillRect(0, 0, 128, 32);
    g.strokeStyle = fg;
    g.lineWidth = 2;
    g.strokeRect(3, 3, 122, 26);
    g.fillStyle = fg;
    g.font = 'bold 15px Georgia, serif';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.fillText(text, 64, 17);
    grain(g, 128, 32, 16);
  });
}

export function buildCity(scene: THREE.Scene, city: CityDef, previous: World | null): World {
  if (previous) {
    scene.remove(previous.group);
    disposeGroup(previous.group);
  }
  const group = new THREE.Group();
  scene.add(group);
  const world: World = { city, group, colliders: [], ramps: [], coins: [], shopPos: new THREE.Vector3() };
  scene.background = new THREE.Color(city.sky);
  scene.fog = new THREE.Fog(city.sky, 28, 125);

  // ground
  const road = cobbleTex(city.road);
  const size = HALF * 2 + 200;
  road.repeat.set(size / 4, size / 4);
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(size, size), lam({ map: road }));
  ground.rotation.x = -Math.PI / 2;
  group.add(ground);

  const facades = city.plaster.map((c) => lam({ map: facadeTex(city, c) }));
  const flatTop = lam({ color: new THREE.Color(city.road).multiplyScalar(0.7) });
  const roofMat = lam({ map: roofTex(city.roof) });
  const swTex = sidewalkTex();
  swTex.repeat.set((BS + 4) / 2, (BS + 4) / 2);
  const swMat = lam({ map: swTex });
  const signMats = city.signs.map((t, i) =>
    psx(new THREE.MeshLambertMaterial({ map: signTex(t, pick(['#1f3b2e', '#5a1f1f', '#1d2b4a', '#3a2a18', '#efe6d2']), i % 2 ? '#f2d9a0' : '#ffffff') })),
  );
  const awnMats = ['#8a2a2a', '#2a5a3e', '#284a7a', '#c9a24a'].map((c) => lam({ color: c, map: dirtTex }));
  const poleMat = lam({ color: '#2a2b2d', map: dirtTex });
  const lampMat = new THREE.MeshBasicMaterial({ color: '#fff2c8' });

  for (let i = -1; i <= N; i++)
    for (let j = -1; j <= N; j++) {
      const r = blockRect(i, j);
      const outer = i < 0 || j < 0 || i >= N || j >= N;
      if (i === PLAZA.i && j === PLAZA.j) {
        buildPlaza(world, r, city, swMat);
        continue;
      }
      const sw = new THREE.Mesh(new THREE.BoxGeometry(BS + 4, 0.05, BS + 4), swMat);
      sw.position.set((r.x0 + r.x1) / 2, 0.025, (r.z0 + r.z1) / 2);
      group.add(sw);
      // split the block into lots
      const xs = [r.x0], zs = [r.z0];
      let x = r.x0;
      while (x < r.x1 - 9) {
        x += rnd(7, 11);
        if (x < r.x1 - 5) xs.push(x);
      }
      xs.push(r.x1);
      let z = r.z0;
      while (z < r.z1 - 9) {
        z += rnd(7, 11);
        if (z < r.z1 - 5) zs.push(z);
      }
      zs.push(r.z1);
      for (let a = 0; a < xs.length - 1; a++)
        for (let b = 0; b < zs.length - 1; b++) {
          const w = xs[a + 1] - xs[a], d = zs[b + 1] - zs[b];
          const floors = Math.floor(rnd(city.floors[0], city.floors[1] + 1)) + (outer ? 1 : 0);
          const h = floors * 3;
          const fm = pick(facades);
          const m = new THREE.Mesh(boxUV(new THREE.BoxGeometry(w, h, d), w, h, d), [fm, fm, flatTop, flatTop, fm, fm]);
          m.position.set(xs[a] + w / 2, h / 2, zs[b] + d / 2);
          group.add(m);
          if (Math.random() < city.pitched) {
            const rh = rnd(2, 4);
            const roof = new THREE.Mesh(new THREE.ConeGeometry(Math.SQRT1_2, 1, 4, 1), roofMat);
            roof.rotation.y = Math.PI / 4;
            roof.scale.set(w * 1.02, rh, d * 1.02);
            roof.position.set(xs[a] + w / 2, h + rh / 2, zs[b] + d / 2);
            group.add(roof);
          }
        }
      world.colliders.push({ type: 'rect', ...r });
      if (outer) continue;
      // shop signs + awnings on the street faces
      const sides = [
        { nx: 0, nz: -1, along: 'x', fixed: r.z0 },
        { nx: 0, nz: 1, along: 'x', fixed: r.z1 },
        { nx: -1, nz: 0, along: 'z', fixed: r.x0 },
        { nx: 1, nz: 0, along: 'z', fixed: r.x1 },
      ];
      for (const s of sides) {
        const count = Math.random() < 0.35 ? 2 : Math.random() < 0.75 ? 1 : 0;
        for (let n = 0; n < count; n++) {
          const t = s.along === 'x' ? rnd(r.x0 + 3, r.x1 - 3) : rnd(r.z0 + 3, r.z1 - 3);
          const px = s.along === 'x' ? t : s.fixed + s.nx * 0.06;
          const pz = s.along === 'x' ? s.fixed + s.nz * 0.06 : t;
          const sign = new THREE.Mesh(new THREE.PlaneGeometry(3.4, 0.85), pick(signMats));
          sign.position.set(px, 3.4, pz);
          sign.rotation.y = Math.atan2(s.nx, s.nz);
          group.add(sign);
          if (Math.random() < 0.6) {
            const aw = new THREE.Mesh(new THREE.BoxGeometry(3.4, 0.12, 1.4), pick(awnMats));
            aw.position.set(px + s.nx * 0.7, 2.7, pz + s.nz * 0.7);
            aw.rotation.y = Math.atan2(s.nx, s.nz);
            aw.rotateX(0.28);
            group.add(aw);
          }
        }
      }
      // street lamps at the corners
      for (const [lx, lz] of [
        [r.x0 - 1.4, r.z0 - 1.4],
        [r.x1 + 1.4, r.z0 - 1.4],
        [r.x0 - 1.4, r.z1 + 1.4],
        [r.x1 + 1.4, r.z1 + 1.4],
      ]) {
        if (Math.random() < 0.5) continue;
        addLamp(world, lx, lz, poleMat, lampMat);
      }
    }
  buildRamps(world);
  spawnCoins(world);
  buildShop(world);
  return world;
}

function addLamp(world: World, x: number, z: number, poleMat: THREE.Material, lampMat: THREE.Material) {
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.12, 4.4, 6), poleMat);
  pole.position.set(x, 2.2, z);
  world.group.add(pole);
  const head = new THREE.Mesh(new THREE.BoxGeometry(0.45, 0.5, 0.45), lampMat);
  head.position.set(x, 4.5, z);
  world.group.add(head);
  world.colliders.push({ type: 'circle', x, z, r: 0.25 });
}

function buildPlaza(world: World, r: Rect, city: CityDef, swMat: THREE.Material) {
  const { group } = world;
  const cx = (r.x0 + r.x1) / 2, cz = (r.z0 + r.z1) / 2;
  const slab = new THREE.Mesh(new THREE.BoxGeometry(BS + 4, 0.05, BS + 4), swMat);
  slab.position.set(cx, 0.025, cz);
  group.add(slab);
  // fountain
  const stoneMat = lam({ color: '#bdb6a8', map: dirtTex });
  const waterMat = lam({ color: '#5f8fa8', map: dirtTex });
  const add = (geo: THREE.BufferGeometry, mat: THREE.Material, x: number, y: number, z: number) => {
    const m = new THREE.Mesh(geo, mat);
    m.position.set(x, y, z);
    group.add(m);
    return m;
  };
  add(new THREE.CylinderGeometry(3.2, 3.4, 0.8, 10), stoneMat, cx, 0.4, cz);
  add(new THREE.CylinderGeometry(2.9, 2.9, 0.1, 10), waterMat, cx, 0.75, cz);
  add(new THREE.CylinderGeometry(0.35, 0.5, 2.6, 8), stoneMat, cx, 1.6, cz);
  add(new THREE.SphereGeometry(0.55, 6, 4), stoneMat, cx, 3.1, cz);
  world.colliders.push({ type: 'circle', x: cx, z: cz, r: 3.5 });
  // trees + benches
  const trunk = lam({ color: '#5a4232', map: dirtTex });
  const leaf = lam({ color: city.id === 'lisbon' ? '#6f9a4a' : '#4f7a3e', map: dirtTex, flatShading: true });
  const bench = lam({ color: '#6b4a2e', map: dirtTex });
  for (const [dx, dz] of [[-8, -8], [8, -8], [-8, 8], [8, 8]]) {
    add(new THREE.CylinderGeometry(0.2, 0.3, 2.4, 6), trunk, cx + dx, 1.2, cz + dz);
    add(new THREE.IcosahedronGeometry(1.9, 0), leaf, cx + dx, 3.4, cz + dz);
    world.colliders.push({ type: 'circle', x: cx + dx, z: cz + dz, r: 0.45 });
    add(new THREE.BoxGeometry(2.2, 0.5, 0.6), bench, cx + dx * 0.62, 0.45, cz + dz);
  }
  world.shopPos.set(cx, 0, cz - 9.5);
}

function buildShop(world: World) {
  const { group, shopPos } = world;
  const x = shopPos.x, z = shopPos.z;
  const body = new THREE.Mesh(new THREE.BoxGeometry(5, 3, 3), lam({ color: '#e9e4d8', map: dirtTex }));
  body.position.set(x, 1.5, z);
  group.add(body);
  const awn = new THREE.Mesh(new THREE.BoxGeometry(5.4, 0.15, 1.8), lam({ color: '#1e9e78', map: dirtTex }));
  awn.position.set(x, 2.9, z + 2.1);
  awn.rotateX(0.3);
  group.add(awn);
  const board = new THREE.Mesh(new THREE.BoxGeometry(5, 0.9, 0.1), lam({ color: '#1e9e78' }));
  board.position.set(x, 3.7, z + 1.5);
  group.add(board);
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(4.4, 1), psx(new THREE.MeshBasicMaterial({ map: signTex('МАГАЗИН', '#1e9e78', '#ffffff') })));
  sign.position.set(x, 3.7, z + 1.56);
  group.add(sign);
  // goodies on the counter
  ['#f2c14e', '#3fd0a0', '#d0403f', '#4a7ad0', '#e0e0e0'].forEach((c, k) => {
    const g = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.5, 0.3), lam({ color: c }));
    g.position.set(x - 1.6 + k * 0.8, 1.6, z + 1.55);
    group.add(g);
  });
  world.colliders.push({ type: 'rect', x0: x - 2.5, x1: x + 2.5, z0: z - 1.5, z1: z + 1.5 });
}

function buildRamps(world: World) {
  const rampMat = lam({ color: '#8a6a3a', map: dirtTex });
  const stripe = lam({ color: '#f2c14e' });
  const { ramps, shopPos } = world;
  let tries = 0;
  while (ramps.length < 12 && tries < 200) {
    tries++;
    const vertical = Math.random() < 0.5;
    const k = Math.floor(rnd(0, N + 1));
    const seg = Math.floor(rnd(0, N));
    const line = streetLine(k);
    const segMid = blockRect(seg, 0).x0 + BS / 2;
    const sgn = Math.random() < 0.5 ? 1 : -1;
    const dir = vertical ? { x: 0, z: sgn } : { x: sgn, z: 0 };
    const L = 6, H = 1.9, W = 4.2;
    const ox = vertical ? line + rnd(-2, 2) : segMid - (dir.x * L) / 2;
    const oz = vertical ? segMid - (dir.z * L) / 2 : line + rnd(-2, 2);
    if (Math.hypot(ox - shopPos.x, oz - shopPos.z) < 22) continue;
    if (ramps.some((r) => Math.hypot(r.x - ox, r.z - oz) < 20)) continue;
    const shape = new THREE.Shape();
    shape.moveTo(0, 0);
    shape.lineTo(L, 0);
    shape.lineTo(L, H);
    shape.lineTo(0, 0);
    const geo = new THREE.ExtrudeGeometry(shape, { depth: W, bevelEnabled: false });
    geo.translate(0, 0, -W / 2);
    const m = new THREE.Mesh(geo, rampMat);
    m.rotation.y = dir.x === 1 ? 0 : dir.x === -1 ? Math.PI : dir.z === 1 ? -Math.PI / 2 : Math.PI / 2;
    m.position.set(ox, 0, oz);
    world.group.add(m);
    const lip = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.08, W), stripe);
    lip.position.set(L - 0.12, H + 0.02, 0);
    m.add(lip);
    ramps.push({ x: ox, z: oz, dx: dir.x, dz: dir.z, L, H, W });
  }
}

const coinGeo = new THREE.CylinderGeometry(0.42, 0.42, 0.1, 10);
const coinMat = psx(new THREE.MeshLambertMaterial({ color: '#f2c14e', emissive: '#6a4a00' }));
const bigCoinMat = psx(new THREE.MeshLambertMaterial({ color: '#ff6b5a', emissive: '#5a1500' }));

export function randomStreetPoint() {
  const vertical = Math.random() < 0.5, k = Math.floor(rnd(0, N + 1));
  const t = rnd(-HALF + 3, HALF - 3), off = rnd(-3.5, 3.5);
  return vertical ? { x: streetLine(k) + off, z: t } : { x: t, z: streetLine(k) + off };
}

function addCoin(world: World, x: number, y: number, z: number, big = false) {
  const m = new THREE.Mesh(coinGeo, big ? bigCoinMat : coinMat);
  m.rotation.x = Math.PI / 2;
  if (big) m.scale.setScalar(1.5);
  m.position.set(x, y, z);
  world.group.add(m);
  world.coins.push({ mesh: m, value: big ? 5 : 1, active: true, respawn: 0, baseY: y, fixed: y > 2 });
}

function spawnCoins(world: World) {
  for (let n = 0; n < 70; n++) {
    const p = randomStreetPoint();
    addCoin(world, p.x, 1, p.z, Math.random() < 0.08);
  }
  for (const r of world.ramps)
    for (let s = 0; s < 3; s++) {
      const d = r.L + 2.5 + s * 2.6;
      addCoin(world, r.x + r.dx * d, 3.2 + Math.sin((s / 2) * Math.PI) * 0.9, r.z + r.dz * d, s === 1);
    }
}
