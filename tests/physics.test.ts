import { describe, expect, it } from 'vitest';
import {
  applyControls,
  createPlayerState,
  judgeLanding,
  maxSpeed,
  rampHeight,
  resolveCollisions,
  stepVertical,
  trickName,
  type Controls,
  type Ramp,
} from '../src/physics';

const none: Controls = { up: false, down: false, left: false, right: false, whip: false };
const base = { turbo: false, spring: false };
const TAU = Math.PI * 2;

describe('rampHeight', () => {
  const ramp: Ramp = { x: 0, z: 0, dx: 1, dz: 0, L: 6, H: 2, W: 4 };
  it('rises linearly along the ramp', () => {
    expect(rampHeight([ramp], 3, 0)).toBeCloseTo(1);
    expect(rampHeight([ramp], 5.9, 1.9)).toBeCloseTo(2 * 5.9 / 6);
  });
  it('is flat outside', () => {
    expect(rampHeight([ramp], -1, 0)).toBe(0);
    expect(rampHeight([ramp], 3, 2.1)).toBe(0);
    expect(rampHeight([ramp], 7, 0)).toBe(0);
  });
});

describe('resolveCollisions', () => {
  it('pushes out of a building along the shortest axis', () => {
    const P = createPlayerState();
    P.x = 0.2; P.z = 5;
    const hit = resolveCollisions(P, [{ type: 'rect', x0: 0, x1: 10, z0: 0, z1: 10 }], 100, 0.5);
    expect(hit).toBe(true);
    expect(P.x).toBeCloseTo(-0.5);
  });
  it('keeps the player inside the city bounds', () => {
    const P = createPlayerState();
    P.x = 500;
    expect(resolveCollisions(P, [], 100, 0.5)).toBe(true);
    expect(P.x).toBeCloseTo(99.5);
  });
});

describe('applyControls', () => {
  it('accelerates up to the cap, higher with turbo', () => {
    const P = createPlayerState();
    for (let i = 0; i < 600; i++) applyControls(P, { ...none, up: true }, base, 1 / 60);
    expect(P.speed).toBe(maxSpeed(base));
    for (let i = 0; i < 600; i++) applyControls(P, { ...none, up: true }, { turbo: true, spring: false }, 1 / 60);
    expect(P.speed).toBeGreaterThan(maxSpeed(base));
  });
  it('coasts to a stop', () => {
    const P = createPlayerState();
    P.speed = 3;
    for (let i = 0; i < 300; i++) applyControls(P, none, base, 1 / 60);
    expect(P.speed).toBe(0);
  });
  it('finishes a started tailwhip after the key is released', () => {
    const P = createPlayerState();
    P.ground = false;
    applyControls(P, { ...none, whip: true }, base, 0.1);
    for (let i = 0; i < 60; i++) applyControls(P, none, base, 1 / 60);
    expect(P.whip).toBeCloseTo(TAU);
  });
});

describe('stepVertical', () => {
  it('jumps and lands back on flat ground', () => {
    const P = createPlayerState();
    expect(stepVertical(P, 0, true, base, 1 / 60)).toBe('jump');
    let ev = null, n = 0;
    while (ev !== 'land' && n++ < 1000) ev = stepVertical(P, 0, false, base, 1 / 60);
    expect(ev).toBe('land');
    expect(P.y).toBe(0);
    expect(P.air).toBeGreaterThan(0.6);
  });
  it('spring jumps higher', () => {
    const peak = (spring: boolean) => {
      const P = createPlayerState();
      stepVertical(P, 0, true, { turbo: false, spring }, 1 / 60);
      let top = 0;
      while (!P.ground) { stepVertical(P, 0, false, { turbo: false, spring }, 1 / 60); top = Math.max(top, P.y); }
      return top;
    };
    expect(peak(true)).toBeGreaterThan(peak(false));
  });
  it('launches off a ramp lip', () => {
    const P = createPlayerState();
    // climb: ground rises 0.1 per step
    for (let i = 1; i <= 10; i++) stepVertical(P, i * 0.1, false, base, 1 / 60);
    expect(stepVertical(P, 0, false, base, 1 / 60)).toBe('launch');
    expect(P.ground).toBe(false);
  });
});

describe('judgeLanding', () => {
  it('scores a clean 360', () => {
    const r = judgeLanding(TAU + 0.2, 1);
    expect(r).toMatchObject({ kind: 'trick', name: '360', turns: 1, whips: 0 });
  });
  it('scores a tailwhip and a combo', () => {
    expect(judgeLanding(0, 0.8, TAU)).toMatchObject({ kind: 'trick', name: 'Tailwhip' });
    const combo = judgeLanding(TAU, 1, 2 * TAU);
    expect(combo).toMatchObject({ kind: 'trick', name: '360 Double Tailwhip' });
    if (combo.kind === 'trick') expect(combo.bonus).toBe(6 + 16 + 10 + 3);
  });
  it('falls when landing sideways or mid-whip', () => {
    expect(judgeLanding(Math.PI, 1).kind).toBe('fall');
    expect(judgeLanding(0, 1, Math.PI).kind).toBe('fall');
  });
  it('rewards plain airtime a little', () => {
    expect(judgeLanding(0, 0.9)).toEqual({ kind: 'air', bonus: 2 });
    expect(judgeLanding(0, 0.3)).toEqual({ kind: 'none' });
  });
  it('names tricks', () => {
    expect(trickName(2, 0)).toBe('720');
    expect(trickName(0, 3)).toBe('Triple Tailwhip');
  });
});
