/** Pure gameplay math — no three.js, no DOM — so it can be unit-tested. */

export interface Ramp {
  x: number;
  z: number;
  /** Unit direction the ramp rises towards (axis-aligned). */
  dx: number;
  dz: number;
  L: number;
  H: number;
  W: number;
}

export type Collider =
  | { type: 'rect'; x0: number; x1: number; z0: number; z1: number }
  | { type: 'circle'; x: number; z: number; r: number };

export interface PlayerState {
  x: number;
  y: number;
  z: number;
  /** Heading in radians; forward is (-sin h, -cos h). */
  h: number;
  speed: number;
  vy: number;
  ground: boolean;
  /** Vertical velocity of the ground under us (ramp slope), used for launches. */
  vyG: number;
  /** Accumulated spin in the air. */
  spin: number;
  /** Accumulated tailwhip (deck rotation round the stem) in the air. */
  whip: number;
  air: number;
  bump: number;
}

export interface Controls {
  up: boolean;
  down: boolean;
  left: boolean;
  right: boolean;
  whip: boolean;
}

export interface Upgrades {
  turbo: boolean;
  spring: boolean;
}

export const RADIUS = 0.55;
export const GRAVITY = 19;
/** Tailwhip speed: one full deck rotation in ~0.5 s. */
export const WHIP_RATE = 12.5;
export const clamp = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v));

export function createPlayerState(): PlayerState {
  return { x: 0, y: 0, z: 0, h: 0, speed: 0, vy: 0, ground: true, vyG: 0, spin: 0, whip: 0, air: 0, bump: 0 };
}

export function maxSpeed(up: Upgrades): number {
  return up.turbo ? 19.5 : 14.5;
}

/** Height of the tallest ramp surface at (x, z); 0 on flat ground. */
export function rampHeight(ramps: readonly Ramp[], x: number, z: number): number {
  let best = 0;
  for (const r of ramps) {
    const dx = x - r.x, dz = z - r.z;
    const along = dx * r.dx + dz * r.dz;
    const side = -dx * r.dz + dz * r.dx;
    if (along > 0 && along < r.L && Math.abs(side) < r.W / 2) best = Math.max(best, (r.H * along) / r.L);
  }
  return best;
}

/** Push the player out of walls. Returns true if anything was hit. */
export function resolveCollisions(P: PlayerState, colliders: readonly Collider[], half: number, rad = RADIUS): boolean {
  let hit = false;
  for (const c of colliders) {
    if (c.type === 'rect') {
      if (P.x > c.x0 - rad && P.x < c.x1 + rad && P.z > c.z0 - rad && P.z < c.z1 + rad) {
        const l = P.x - (c.x0 - rad), r = c.x1 + rad - P.x, t = P.z - (c.z0 - rad), b = c.z1 + rad - P.z;
        const m = Math.min(l, r, t, b);
        if (m === l) P.x = c.x0 - rad;
        else if (m === r) P.x = c.x1 + rad;
        else if (m === t) P.z = c.z0 - rad;
        else P.z = c.z1 + rad;
        hit = true;
      }
    } else {
      const dx = P.x - c.x, dz = P.z - c.z, d = Math.hypot(dx, dz), min = c.r + rad;
      if (d < min && d > 1e-4) {
        P.x = c.x + (dx / d) * min;
        P.z = c.z + (dz / d) * min;
        hit = true;
      }
    }
  }
  const lim = half - rad;
  if (Math.abs(P.x) > lim || Math.abs(P.z) > lim) {
    P.x = clamp(P.x, -lim, lim);
    P.z = clamp(P.z, -lim, lim);
    hit = true;
  }
  return hit;
}

/** Throttle, brake, coasting and steering / in-air spinning. */
export function applyControls(P: PlayerState, c: Controls, up: Upgrades, dt: number): void {
  const maxSp = maxSpeed(up);
  const acc = up.turbo ? 13 : 9.5;
  if (c.up) P.speed += acc * dt;
  else if (c.down) P.speed -= (P.speed > 0 ? 18 : 6) * dt;
  else P.speed -= Math.sign(P.speed) * Math.min(Math.abs(P.speed), 2.4 * dt);
  P.speed = clamp(P.speed, -4, maxSp);

  const steer = (c.left ? 1 : 0) - (c.right ? 1 : 0);
  if (P.ground) {
    const grip = clamp(Math.abs(P.speed) / 3, 0, 1);
    P.h += steer * dt * (2.5 - (0.9 * Math.abs(P.speed)) / maxSp) * grip * Math.sign(P.speed || 1);
  } else {
    P.spin += steer * dt * 8.2;
    // Once started, a tailwhip carries on until the deck is round again.
    const target = Math.ceil(P.whip / (Math.PI * 2) - 1e-6) * Math.PI * 2;
    if (c.whip) P.whip += dt * WHIP_RATE;
    else if (P.whip < target) P.whip = Math.min(target, P.whip + dt * WHIP_RATE);
  }
}

export type VerticalEvent = 'jump' | 'launch' | 'land' | null;

/**
 * Ground following, ramp launches, jumps and gravity.
 * `g` is the ground height under the player after horizontal movement.
 */
export function stepVertical(P: PlayerState, g: number, jump: boolean, up: Upgrades, dt: number): VerticalEvent {
  let ev: VerticalEvent = null;
  if (P.ground) {
    if (jump) {
      P.vy = (up.spring ? 9.2 : 7) + Math.max(0, P.vyG);
      P.ground = false;
      P.air = 0;
      ev = 'jump';
    } else if (g < P.y - 0.05 && P.vyG > 0.5) {
      // Rolled off the lip of a ramp: keep the upward momentum.
      P.vy = P.vyG;
      P.ground = false;
      P.air = 0;
      ev = 'launch';
    } else {
      P.vyG = dt > 0 ? clamp((g - P.y) / dt, -12, 9) : 0;
      P.y = g;
    }
  }
  if (!P.ground) {
    P.vy -= GRAVITY * dt;
    P.y += P.vy * dt;
    P.air += dt;
    if (P.y <= g && P.vy < 0) {
      P.y = g;
      P.ground = true;
      P.vy = 0;
      P.vyG = 0;
      ev = 'land';
    }
  }
  return ev;
}

export type Landing =
  | { kind: 'fall' }
  | { kind: 'trick'; name: string; turns: number; whips: number; bonus: number }
  | { kind: 'air'; bonus: number }
  | { kind: 'none' };

const FULL = Math.PI * 2;

/** Whole rotations and how far off a clean landing angle we are. */
function rotations(angle: number): { turns: number; off: number } {
  const s = Math.abs(angle);
  const turns = Math.round(s / FULL);
  return { turns, off: Math.abs(s - turns * FULL) };
}

const MULTI = ['', '', 'Double ', 'Triple ', 'Quad '];

export function trickName(turns: number, whips: number): string {
  const parts: string[] = [];
  if (turns > 0) parts.push(String(turns * 360));
  if (whips > 0) parts.push((MULTI[whips] ?? `${whips}x `) + 'Tailwhip');
  return parts.join(' ');
}

/**
 * Judge a landing from body spin, deck tailwhip (radians) and airtime (seconds).
 * Landing sideways or with the deck half-way round is a fall.
 */
export function judgeLanding(spin: number, air: number, whip = 0): Landing {
  const sp = rotations(spin), wh = rotations(whip);
  if ((Math.abs(spin) > 0.8 && sp.off > 0.95) || (Math.abs(whip) > 0.8 && wh.off > 0.9)) return { kind: 'fall' };
  if (sp.turns >= 1 || wh.turns >= 1) {
    const bonus = sp.turns * 6 + wh.turns * 8 + (sp.turns && wh.turns ? 10 : 0) + Math.round(air * 3);
    return { kind: 'trick', name: trickName(sp.turns, wh.turns), turns: sp.turns, whips: wh.turns, bonus };
  }
  if (air > 0.75) return { kind: 'air', bonus: 2 };
  return { kind: 'none' };
}
