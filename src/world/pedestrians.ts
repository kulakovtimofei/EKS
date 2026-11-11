import * as THREE from 'three';
import type { PlayerState } from '../physics';
import { canvasTex, folds, grain, lam, pick, rnd } from '../render/psx';
import { N, PLAZA, blockRect, type Rect } from './layout';

/** Townsfolk strolling round the blocks on the pavement. Bumping into them costs speed. */

interface Walker {
  mesh: THREE.Group;
  legs: THREE.Object3D[];
  rect: Rect;
  /** Distance along the block's perimeter. */
  t: number;
  dir: 1 | -1;
  speed: number;
  phase: number;
  stumble: number;
}

const OFFSET = 0.9;
const RADIUS = 0.35;

const TOPS = ['#7a2f2f', '#2f4a6a', '#5a5a52', '#b9a27a', '#3b5a3a', '#d8d4cc', '#6a3f5a'];
const BOTTOMS = ['#3d4f6a', '#2a2a2a', '#5a4a3a', '#6a6a5e', '#4a5a70'];
const SKIN = ['#d9b08c', '#c49270', '#8a5a3c', '#e8c4a4'];
const HAIR = ['#141313', '#4a3020', '#8a6a40', '#bdb6aa'];

function clothTex(color: string) {
  return canvasTex(16, 32, (g, w, h) => {
    g.fillStyle = color;
    g.fillRect(0, 0, w, h);
    folds(g, w, h, 6, 0.12);
    grain(g, w, h, 26);
  });
}

function perimeterPoint(r: Rect, t: number) {
  const x0 = r.x0 - OFFSET, x1 = r.x1 + OFFSET, z0 = r.z0 - OFFSET, z1 = r.z1 + OFFSET;
  const w = x1 - x0, d = z1 - z0, P = 2 * (w + d);
  t = ((t % P) + P) % P;
  if (t < w) return { x: x0 + t, z: z0, a: -Math.PI / 2 };
  t -= w;
  if (t < d) return { x: x1, z: z0 + t, a: Math.PI };
  t -= d;
  if (t < w) return { x: x1 - t, z: z1, a: Math.PI / 2 };
  t -= w;
  return { x: x0, z: z1 - t, a: 0 };
}

function buildWalker(): { mesh: THREE.Group; legs: THREE.Object3D[] } {
  const mesh = new THREE.Group();
  const top = lam({ map: clothTex(pick(TOPS)) });
  const bottom = lam({ map: clothTex(pick(BOTTOMS)) });
  const skin = lam({ color: pick(SKIN) });
  const hair = lam({ color: pick(HAIR) });
  const s = rnd(0.9, 1.08);
  mesh.scale.setScalar(s);
  const legs: THREE.Object3D[] = [];
  for (const x of [-0.1, 0.1]) {
    const hip = new THREE.Group();
    hip.position.set(x, 0.9, 0);
    const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.1, 0.88, 5), bottom);
    leg.position.y = -0.44;
    hip.add(leg);
    mesh.add(hip);
    legs.push(hip);
  }
  const torso = new THREE.Mesh(new THREE.BoxGeometry(0.44, 0.62, 0.26), top);
  torso.position.y = 1.22;
  mesh.add(torso);
  for (const x of [-0.27, 0.27]) {
    const arm = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.07, 0.6, 5), top);
    arm.position.set(x, 1.2, 0);
    mesh.add(arm);
  }
  const head = new THREE.Mesh(new THREE.BoxGeometry(0.23, 0.26, 0.24), skin);
  head.position.y = 1.68;
  mesh.add(head);
  const cap = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.09, 0.26), hair);
  cap.position.y = 1.83;
  mesh.add(cap);
  return { mesh, legs };
}

export class Crowd {
  private walkers: Walker[] = [];
  constructor(group: THREE.Group, count = 34) {
    const blocks: Rect[] = [];
    for (let i = 0; i < N; i++) for (let j = 0; j < N; j++) if (!(i === PLAZA.i && j === PLAZA.j)) blocks.push(blockRect(i, j));
    for (let n = 0; n < count; n++) {
      const { mesh, legs } = buildWalker();
      group.add(mesh);
      this.walkers.push({
        mesh,
        legs,
        rect: pick(blocks),
        t: rnd(0, 200),
        dir: Math.random() < 0.5 ? 1 : -1,
        speed: rnd(0.9, 1.5),
        phase: rnd(0, 6),
        stumble: 0,
      });
    }
    this.update(0);
  }

  update(dt: number): void {
    for (const w of this.walkers) {
      if (w.stumble > 0) w.stumble -= dt;
      else w.t += w.dir * w.speed * dt;
      const p = perimeterPoint(w.rect, w.t);
      w.mesh.position.set(p.x, 0, p.z);
      w.mesh.rotation.y = p.a + (w.dir < 0 ? Math.PI : 0) + (w.stumble > 0 ? Math.sin(w.stumble * 30) * 0.3 : 0);
      w.phase += dt * w.speed * 5;
      const swing = w.stumble > 0 ? 0 : Math.sin(w.phase) * 0.5;
      w.legs[0].rotation.x = swing;
      w.legs[1].rotation.x = -swing;
    }
  }

  /** Push the player off anyone they ride into. Returns true on a fresh bump. */
  collide(P: PlayerState, playerRadius: number): boolean {
    let bumped = false;
    for (const w of this.walkers) {
      const dx = P.x - w.mesh.position.x, dz = P.z - w.mesh.position.z;
      const d = Math.hypot(dx, dz), min = RADIUS + playerRadius;
      if (d >= min || d < 1e-4 || P.y > 1.4) continue;
      P.x = w.mesh.position.x + (dx / d) * min;
      P.z = w.mesh.position.z + (dz / d) * min;
      if (w.stumble <= 0) {
        w.stumble = 0.8;
        bumped = true;
      }
    }
    return bumped;
  }
}
