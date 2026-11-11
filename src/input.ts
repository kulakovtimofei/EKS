import type { Controls } from './physics';

export type Key = keyof Controls | 'jump';

const KEYMAP: Record<string, Key> = {
  KeyW: 'up', ArrowUp: 'up',
  KeyS: 'down', ArrowDown: 'down',
  KeyA: 'left', ArrowLeft: 'left',
  KeyD: 'right', ArrowRight: 'right',
  Space: 'jump',
  ShiftLeft: 'whip', ShiftRight: 'whip', KeyQ: 'whip',
};

export class Input {
  readonly keys: Controls & { jump: boolean } = { up: false, down: false, left: false, right: false, whip: false, jump: false };
  private jumpQueued = false;
  readonly isTouch = matchMedia('(pointer: coarse)').matches;

  constructor(private readonly active: () => boolean) {
    addEventListener('keydown', (e) => {
      const k = KEYMAP[e.code];
      if (!k) return;
      if (this.active()) e.preventDefault();
      this.press(k);
    });
    addEventListener('keyup', (e) => {
      const k = KEYMAP[e.code];
      if (k) this.keys[k] = false;
    });
    addEventListener('blur', () => this.releaseAll());
    document.querySelectorAll<HTMLElement>('.tb[data-k]').forEach((b) => {
      const k = b.dataset.k as Key;
      const on = (e: PointerEvent) => {
        e.preventDefault();
        b.setPointerCapture?.(e.pointerId);
        b.classList.add('down');
        this.press(k);
      };
      const off = (e: PointerEvent) => {
        e.preventDefault();
        b.classList.remove('down');
        this.keys[k] = false;
      };
      b.addEventListener('pointerdown', on);
      b.addEventListener('pointerup', off);
      b.addEventListener('pointercancel', off);
      b.addEventListener('lostpointercapture', off);
    });
  }

  private press(k: Key) {
    if (k === 'jump' && !this.keys.jump) this.jumpQueued = true;
    this.keys[k] = true;
  }

  /** Jump is edge-triggered: true once per press. */
  takeJump(): boolean {
    const j = this.jumpQueued;
    this.jumpQueued = false;
    return j;
  }

  releaseAll(): void {
    for (const k of Object.keys(this.keys) as Key[]) this.keys[k] = false;
    this.jumpQueued = false;
  }
}
