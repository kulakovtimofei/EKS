import * as THREE from 'three';

/**
 * Final pass that sells the early-2000s console look:
 * renders the scene into a low-res target, then grades it — slightly
 * desaturated, lifted blacks, warm-grey cast — and adds ordered dithering,
 * animated film grain and a soft vignette. Upscaled with nearest filtering.
 */
const frag = /* glsl */ `
precision highp float;
uniform sampler2D tScene;
uniform vec2 uRes;
uniform float uTime;
varying vec2 vUv;

float bayer4(vec2 p){
  int x = int(mod(p.x, 4.0)), y = int(mod(p.y, 4.0));
  int i = x + y * 4;
  float m[16];
  m[0]=0.;m[1]=8.;m[2]=2.;m[3]=10.;m[4]=12.;m[5]=4.;m[6]=14.;m[7]=6.;
  m[8]=3.;m[9]=11.;m[10]=1.;m[11]=9.;m[12]=15.;m[13]=7.;m[14]=13.;m[15]=5.;
  for (int k=0;k<16;k++) if (k==i) return m[k]/16.0 - 0.5;
  return 0.0;
}
float hash(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
vec3 toSRGB(vec3 c){
  c = clamp(c, 0.0, 1.0);
  return mix(c * 12.92, 1.055 * pow(c, vec3(1.0/2.4)) - 0.055, step(0.0031308, c));
}

void main(){
  vec3 c = toSRGB(texture2D(tScene, vUv).rgb);
  // grade: pull saturation down, lift shadows, roll off highlights, grey-warm tint
  float l = dot(c, vec3(0.299, 0.587, 0.114));
  c = mix(vec3(l), c, 0.78);
  c = c * 0.9 + 0.045;
  c = c / (1.0 + 0.18 * c) * 1.12;
  c *= vec3(1.02, 1.0, 0.95);
  // vignette
  vec2 q = vUv - 0.5;
  c *= 1.0 - dot(q, q) * 0.75;
  // grain (changes every frame, ~24 fps)
  vec2 px = floor(vUv * uRes);
  float n = hash(px + floor(uTime * 24.0) * 17.0) - 0.5;
  c += n * 0.055;
  // 15-bit colour with ordered dither, like the console framebuffer
  c += bayer4(px) / 32.0;
  c = floor(c * 31.0 + 0.5) / 31.0;
  gl_FragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
}`;

export class PostFX {
  readonly target: THREE.WebGLRenderTarget;
  private readonly scene = new THREE.Scene();
  private readonly cam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  private readonly mat: THREE.ShaderMaterial;

  constructor() {
    this.target = new THREE.WebGLRenderTarget(320, 240, {
      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter,
      depthBuffer: true,
    });
    this.mat = new THREE.ShaderMaterial({
      uniforms: {
        tScene: { value: this.target.texture },
        uRes: { value: new THREE.Vector2(320, 240) },
        uTime: { value: 0 },
      },
      vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }',
      fragmentShader: frag,
      depthTest: false,
      depthWrite: false,
    });
    this.scene.add(new THREE.Mesh(new THREE.PlaneGeometry(2, 2), this.mat));
  }

  setSize(w: number, h: number): void {
    this.target.setSize(w, h);
    (this.mat.uniforms.uRes.value as THREE.Vector2).set(w, h);
  }

  render(renderer: THREE.WebGLRenderer, scene: THREE.Scene, camera: THREE.Camera, time: number): void {
    this.mat.uniforms.uTime.value = time;
    renderer.setRenderTarget(this.target);
    renderer.render(scene, camera);
    renderer.setRenderTarget(null);
    renderer.render(this.scene, this.cam);
  }
}
