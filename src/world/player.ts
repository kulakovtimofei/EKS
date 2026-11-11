import * as THREE from 'three';
import { canvasTex, dirtTex, folds, grain, lam, rnd } from '../render/psx';

/**
 * The rider: messy black hair, oversized striped hoodie, dark tee with a print,
 * fingerless gloves, very baggy faded jeans and chunky sneakers — low-poly
 * shapes carrying hand-painted, noisy textures.
 */

const jacketTex = (stripes: boolean) =>
  canvasTex(32, 64, (g, w, h) => {
    g.fillStyle = '#b9b7b1';
    g.fillRect(0, 0, w, h);
    // broad dark bands across the body
    g.fillStyle = '#4a4a48';
    for (const y of [10, 26, 44]) g.fillRect(0, y, w, 4);
    g.fillStyle = '#d8d6d0';
    for (const y of [5, 20, 37, 55]) g.fillRect(0, y, w, 2);
    folds(g, w, h, 14, 0.12);
    if (stripes) {
      // green striped long-sleeve showing at the cuffs
      for (let y = h - 10; y < h; y += 2) {
        g.fillStyle = (y / 2) % 2 ? '#2f7a6a' : '#9cc23a';
        g.fillRect(0, y, w, 2);
      }
    }
    grain(g, w, h, 34);
  });

const teeTex = canvasTex(32, 32, (g, w, h) => {
  g.fillStyle = '#2b2c28';
  g.fillRect(0, 0, w, h);
  // faded band-tee print: jagged logo + a little skull
  g.fillStyle = '#d9d6cc';
  for (let x = 4; x < 28; x += 2) g.fillRect(x, 8 + Math.floor(rnd(-2, 2)), 1, Math.floor(rnd(2, 6)));
  g.fillRect(13, 15, 6, 5);
  g.fillStyle = '#2b2c28';
  g.fillRect(14, 16, 1, 2);
  g.fillRect(17, 16, 1, 2);
  g.fillStyle = 'rgba(160,60,90,0.6)';
  g.fillRect(8, 22, 16, 3);
  grain(g, w, h, 30);
});

const jeansTex = canvasTex(32, 64, (g, w, h) => {
  g.fillStyle = '#5e7491';
  g.fillRect(0, 0, w, h);
  // stone-wash: lighter in the middle of the thigh and knee
  const grad = g.createLinearGradient(0, 0, w, 0);
  grad.addColorStop(0, 'rgba(20,30,50,0.35)');
  grad.addColorStop(0.5, 'rgba(220,230,240,0.25)');
  grad.addColorStop(1, 'rgba(20,30,50,0.35)');
  g.fillStyle = grad;
  g.fillRect(0, 0, w, h);
  folds(g, w, h, 10, 0.1);
  // bunching at the hem
  g.fillStyle = 'rgba(15,20,35,0.35)';
  for (let y = h - 14; y < h; y += 4) g.fillRect(0, y, w, 1);
  g.fillStyle = 'rgba(210,180,120,0.5)';
  g.fillRect(w / 2, 0, 1, h); // seam
  grain(g, w, h, 30);
});

const skinTex = canvasTex(16, 16, (g, w, h) => {
  g.fillStyle = '#d9b08c';
  g.fillRect(0, 0, w, h);
  grain(g, w, h, 14);
});

const faceTex = canvasTex(32, 32, (g, w, h) => {
  g.fillStyle = '#d9b08c';
  g.fillRect(0, 0, w, h);
  g.fillStyle = 'rgba(120,70,50,0.35)';
  g.fillRect(10, 18, 12, 1); // nose shadow
  g.fillStyle = '#7a4a3c';
  g.fillRect(11, 24, 10, 2); // mouth
  g.fillStyle = '#2a201c';
  g.fillRect(7, 12, 6, 3);
  g.fillRect(19, 12, 6, 3); // eyes
  g.fillStyle = 'rgba(110,40,40,0.55)';
  g.fillRect(22, 17, 1, 6);
  g.fillRect(23, 20, 2, 1); // little scar
  grain(g, w, h, 14);
});

const hairTex = canvasTex(16, 16, (g, w, h) => {
  g.fillStyle = '#141313';
  g.fillRect(0, 0, w, h);
  g.fillStyle = 'rgba(120,120,130,0.35)';
  for (let i = 0; i < 10; i++) g.fillRect(Math.floor(rnd(0, w)), 0, 1, Math.floor(rnd(4, h)));
  grain(g, w, h, 18);
});

const shoeTex = canvasTex(16, 16, (g, w, h) => {
  g.fillStyle = '#c9cbc8';
  g.fillRect(0, 0, w, h);
  g.fillStyle = '#2a2a2a';
  g.fillRect(0, h - 4, w, 4);
  g.fillStyle = '#5a5c5e';
  for (let x = 3; x < 12; x += 3) g.fillRect(x, 3, 2, 1);
  grain(g, w, h, 20);
});

const gloveTex = canvasTex(8, 8, (g, w, h) => {
  g.fillStyle = '#26261f';
  g.fillRect(0, 0, w, h);
  g.fillStyle = '#d9b08c';
  g.fillRect(0, 0, w, 2); // bare fingers
  grain(g, w, h, 18);
});

export interface Rider {
  root: THREE.Group;
  /** Leans and spins with the rider. */
  body: THREE.Group;
  /** The scooter itself — rotates for tailwhips. */
  scooter: THREE.Group;
  /** Rear (kicking) leg pivots at the hip. */
  kickLeg: THREE.Group;
  setLook(look: Look): void;
}

export interface Look {
  glasses: boolean;
  cap: boolean;
  beanie: boolean;
  phones: boolean;
  stripes: boolean;
  neon: boolean;
  golddeck: boolean;
}

export function buildRider(): Rider {
  const root = new THREE.Group();
  const body = new THREE.Group();
  root.add(body);
  const box = (parent: THREE.Object3D, w: number, h: number, d: number, mat: THREE.Material, x: number, y: number, z: number) => {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
    m.position.set(x, y, z);
    parent.add(m);
    return m;
  };
  const cyl = (parent: THREE.Object3D, rt: number, rb: number, h: number, seg: number, mat: THREE.Material, x: number, y: number, z: number) => {
    const m = new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg), mat);
    m.position.set(x, y, z);
    parent.add(m);
    return m;
  };

  // --- scooter: rotates round the stem for tailwhips, so its pivot is the stem axis ---
  const scooterPivot = new THREE.Group();
  scooterPivot.position.set(0, 0, -0.47);
  body.add(scooterPivot);
  const scooter = new THREE.Group();
  scooter.position.set(0, 0, 0.47);
  scooterPivot.add(scooter);
  const deckMat = lam({ color: '#2c2e31', map: dirtTex });
  box(scooter, 0.34, 0.07, 1.05, deckMat, 0, 0.2, 0);
  const wheelMat = lam({ color: '#1a1a1a', map: dirtTex });
  const wg = new THREE.CylinderGeometry(0.13, 0.13, 0.1, 8);
  for (const z of [-0.45, 0.45]) {
    const w = new THREE.Mesh(wg, wheelMat);
    w.rotation.z = Math.PI / 2;
    w.position.set(0, 0.13, z);
    scooter.add(w);
  }
  const metal = lam({ color: '#9aa0a6', map: dirtTex });
  // the stem + bars stay in the rider's hands
  const stem = cyl(body, 0.03, 0.03, 1.05, 6, metal, 0, 0.72, -0.47);
  stem.rotation.x = -0.08;
  const bar = cyl(body, 0.025, 0.025, 0.6, 6, metal, 0, 1.22, -0.5);
  bar.rotation.z = Math.PI / 2;

  // --- rider ---
  const jeans = lam({ map: jeansTex });
  const tee = lam({ map: teeTex });
  const skin = lam({ map: skinTex });
  const hair = lam({ map: hairTex });
  const shoe = lam({ map: shoeTex });
  const glove = lam({ map: gloveTex });
  const plainJacket = jacketTex(false), stripedJacket = jacketTex(true);
  const jacket = lam({ map: plainJacket });

  // Very baggy jeans: tapered cylinders that flare towards the hem.
  const frontLeg = new THREE.Group();
  frontLeg.position.set(-0.1, 1.05, -0.05);
  body.add(frontLeg);
  cyl(frontLeg, 0.1, 0.15, 0.82, 6, jeans, 0, -0.41, 0);
  box(frontLeg, 0.15, 0.1, 0.3, shoe, 0, -0.84, -0.05);

  const kickLeg = new THREE.Group();
  kickLeg.position.set(0.1, 1.05, 0.18);
  body.add(kickLeg);
  cyl(kickLeg, 0.1, 0.15, 0.82, 6, jeans, 0, -0.41, 0);
  box(kickLeg, 0.15, 0.1, 0.3, shoe, 0, -0.84, -0.05);

  // Oversized hoodie: wide boxy torso, hood bunched behind the neck.
  const torso = box(body, 0.52, 0.66, 0.32, jacket, 0, 1.36, 0.02);
  torso.rotation.x = -0.15;
  const front = box(body, 0.2, 0.46, 0.02, tee, 0, 1.36, -0.15);
  front.rotation.x = -0.15;
  box(body, 0.44, 0.2, 0.18, jacket, 0, 1.68, 0.16); // hood
  for (const s of [-1, 1]) {
    const arm = cyl(body, 0.075, 0.095, 0.6, 6, jacket, s * 0.28, 1.36, -0.24);
    arm.rotation.x = Math.PI / 4;
    box(body, 0.13, 0.13, 0.13, glove, s * 0.25, 1.2, -0.48);
  }
  // head + messy hair
  // BoxGeometry face order: +x, -x, +y, -y, +z, -z → the face is on -z (forward).
  const head = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.28, 0.26), [skin, skin, skin, skin, skin, lam({ map: faceTex })]);
  head.position.set(0, 1.84, -0.02);
  body.add(head);
  box(body, 0.3, 0.12, 0.31, hair, 0, 2.0, 0);
  box(body, 0.3, 0.3, 0.08, hair, 0, 1.86, 0.13);
  for (let i = 0; i < 6; i++) {
    const tuft = box(body, rnd(0.06, 0.1), rnd(0.12, 0.2), rnd(0.06, 0.1), hair, rnd(-0.13, 0.13), rnd(1.9, 2.02), rnd(-0.16, 0.14));
    tuft.rotation.set(rnd(-0.6, 0.6), rnd(-0.6, 0.6), rnd(-0.6, 0.6));
  }
  box(body, 0.06, 0.22, 0.24, hair, -0.15, 1.85, 0);
  box(body, 0.06, 0.22, 0.24, hair, 0.15, 1.85, 0);
  box(body, 0.22, 0.08, 0.04, hair, 0.03, 1.94, -0.16); // fringe

  // --- accessories ---
  const glasses = box(body, 0.27, 0.06, 0.03, lam({ color: '#2fd09a', emissive: '#0d5a40' }), 0, 1.86, -0.16);

  const cap = new THREE.Group();
  body.add(cap);
  const capMat = lam({ color: '#c23a32', map: dirtTex });
  box(cap, 0.32, 0.1, 0.34, capMat, 0, 2.07, 0);
  box(cap, 0.22, 0.03, 0.16, capMat, 0, 2.03, 0.23);

  const beanie = new THREE.Group();
  body.add(beanie);
  const beanieMat = lam({ color: '#1b1b1d', map: dirtTex });
  box(beanie, 0.33, 0.16, 0.34, beanieMat, 0, 2.06, 0);
  box(beanie, 0.34, 0.05, 0.35, lam({ color: '#d8d8d2', map: dirtTex }), 0, 1.99, 0);

  const phones = new THREE.Group();
  body.add(phones);
  const phMat = lam({ color: '#202020', map: dirtTex });
  box(phones, 0.34, 0.04, 0.06, phMat, 0, 2.08, 0.01);
  box(phones, 0.06, 0.15, 0.13, phMat, -0.17, 1.85, 0.01);
  box(phones, 0.06, 0.15, 0.13, phMat, 0.17, 1.85, 0.01);

  return {
    root,
    body,
    scooter: scooterPivot,
    kickLeg,
    setLook(l: Look) {
      glasses.visible = l.glasses;
      cap.visible = l.cap;
      beanie.visible = l.beanie;
      phones.visible = l.phones;
      jacket.map = l.stripes ? stripedJacket : plainJacket;
      wheelMat.color.set(l.neon ? '#3fe0c0' : '#1a1a1a');
      wheelMat.emissive.set(l.neon ? '#1fa890' : '#000000');
      deckMat.color.set(l.golddeck ? '#e8b931' : '#2c2e31');
      deckMat.emissive.set(l.golddeck ? '#4a3200' : '#000000');
    },
  };
}
