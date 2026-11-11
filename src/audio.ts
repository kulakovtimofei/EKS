let actx: AudioContext | null = null;

/** Must be called from a user gesture (browsers block autoplay). */
export function initAudio(): void {
  try {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
    actx ??= new Ctx();
  } catch {
    /* no audio */
  }
}

export function beep(freq: number, dur: number, type: OscillatorType = 'square', vol = 0.06, slide = 0): void {
  if (!actx) return;
  const o = actx.createOscillator(), g = actx.createGain();
  o.type = type;
  o.frequency.value = freq;
  if (slide) o.frequency.linearRampToValueAtTime(freq + slide, actx.currentTime + dur);
  g.gain.value = vol;
  g.gain.exponentialRampToValueAtTime(0.0001, actx.currentTime + dur);
  o.connect(g);
  g.connect(actx.destination);
  o.start();
  o.stop(actx.currentTime + dur);
}

export const sfx = {
  coin: (big: boolean) => {
    beep(big ? 1100 : 1500, 0.07, 'square', 0.04);
    setTimeout(() => beep(big ? 1650 : 2000, 0.09, 'square', 0.04), 55);
  },
  jump: () => beep(300, 0.12, 'triangle', 0.05, 200),
  bump: () => beep(110, 0.12, 'sawtooth', 0.05),
  fall: () => beep(90, 0.3, 'sawtooth', 0.06, -40),
  trick: () => {
    beep(660, 0.1, 'square', 0.05);
    setTimeout(() => beep(990, 0.18, 'square', 0.05), 100);
  },
  air: () => beep(740, 0.12, 'triangle', 0.05),
  buy: () => {
    beep(880, 0.1, 'square', 0.05);
    setTimeout(() => beep(1320, 0.15, 'square', 0.05), 90);
  },
  open: () => beep(660, 0.08, 'triangle'),
};
