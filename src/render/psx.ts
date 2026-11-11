import * as THREE from 'three';

/** Shared uniform: half the internal resolution, drives vertex snapping. */
export const snap = { value: new THREE.Vector2(160, 120) };

/** PS1/PS2-style vertex snapping: positions jump between screen pixels. */
export function psx<M extends THREE.Material>(mat: M): M {
  mat.onBeforeCompile = (sh) => {
    sh.uniforms.uSnap = snap;
    sh.vertexShader =
      'uniform vec2 uSnap;\n' +
      sh.vertexShader.replace(
        '#include <project_vertex>',
        '#include <project_vertex>\n  gl_Position.xy = floor(gl_Position.xy / gl_Position.w * uSnap + 0.5) / uSnap * gl_Position.w;',
      );
  };
  return mat;
}

export const lam = (opts: THREE.MeshLambertMaterialParameters) => psx(new THREE.MeshLambertMaterial(opts));

export const rnd = (a: number, b: number) => a + Math.random() * (b - a);
export const pick = <T,>(a: readonly T[]): T => a[Math.floor(Math.random() * a.length)];

export type Draw = (g: CanvasRenderingContext2D, w: number, h: number) => void;

/** Small hand-painted canvas texture, sampled with nearest filtering for crunchy pixels. */
export function canvasTex(w: number, h: number, draw: Draw): THREE.CanvasTexture {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const g = c.getContext('2d', { willReadFrequently: true })!;
  draw(g, w, h);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  t.magFilter = THREE.NearestFilter;
  t.minFilter = THREE.NearestFilter;
  t.generateMipmaps = false;
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}

/** Monochrome noise over whatever is drawn — the grubby PS2 texture look. */
export function grain(g: CanvasRenderingContext2D, w: number, h: number, amt: number): void {
  const d = g.getImageData(0, 0, w, h);
  for (let i = 0; i < d.data.length; i += 4) {
    const n = (Math.random() - 0.5) * amt;
    d.data[i] += n;
    d.data[i + 1] += n;
    d.data[i + 2] += n;
  }
  g.putImageData(d, 0, 0);
}

/** Soft vertical shading streaks: fabric folds, dirt runs. */
export function folds(g: CanvasRenderingContext2D, w: number, h: number, n: number, alpha: number): void {
  for (let i = 0; i < n; i++) {
    const x = Math.random() * w, fw = rnd(1, 3);
    g.fillStyle = Math.random() < 0.5 ? `rgba(0,0,0,${alpha})` : `rgba(255,255,255,${alpha * 0.7})`;
    g.fillRect(Math.floor(x), 0, Math.ceil(fw), h);
  }
}

export const dirtTex = canvasTex(16, 16, (g, w, h) => {
  g.fillStyle = '#fff';
  g.fillRect(0, 0, w, h);
  grain(g, w, h, 40);
});

/** Scale a BoxGeometry's side UVs so 1 texture tile = `cell` metres. */
export function boxUV(geo: THREE.BoxGeometry, w: number, h: number, d: number, cell = 3): THREE.BoxGeometry {
  const uv = geo.attributes.uv as THREE.BufferAttribute;
  const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
  for (let f = 0; f < 6; f++) {
    const [a, b] = dims[f];
    for (let v = 0; v < 4; v++) {
      const i = f * 4 + v;
      uv.setXY(i, (uv.getX(i) * a) / cell, (uv.getY(i) * b) / cell);
    }
  }
  uv.needsUpdate = true;
  return geo;
}

export function disposeGroup(g: THREE.Object3D): void {
  g.traverse((o) => {
    const m = o as THREE.Mesh;
    if (m.geometry) m.geometry.dispose();
    if (m.material) {
      (Array.isArray(m.material) ? m.material : [m.material]).forEach((mat) => {
        const map = (mat as THREE.MeshLambertMaterial).map;
        if (map && map !== dirtTex) map.dispose();
        mat.dispose();
      });
    }
  });
}
