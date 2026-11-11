/** Analogue speedometer dial drawn once as SVG; only the needle and readout move. */
const MAX = 80; // km/h on the dial
const START = -225, SWEEP = 270; // degrees

function polar(r: number, deg: number) {
  const a = (deg * Math.PI) / 180;
  return [60 + r * Math.cos(a), 60 + r * Math.sin(a)];
}

export class Speedo {
  private needle: SVGLineElement;
  private value: HTMLElement;

  constructor(root: HTMLElement) {
    const ns = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('viewBox', '0 0 120 120');
    let ticks = '';
    for (let v = 0; v <= MAX; v += 5) {
      const deg = START + (v / MAX) * SWEEP;
      const major = v % 20 === 0;
      const [x1, y1] = polar(major ? 44 : 48, deg), [x2, y2] = polar(53, deg);
      const red = v >= 60;
      ticks += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${red ? '#d33' : '#fff'}" stroke-width="${major ? 2.5 : 1.2}"/>`;
      if (major) {
        const [tx, ty] = polar(35, deg);
        ticks += `<text x="${tx}" y="${ty + 3.5}" text-anchor="middle" font-size="10" fill="${red ? '#f55' : '#fff'}">${v}</text>`;
      }
    }
    const [ax, ay] = polar(53, START + (60 / MAX) * SWEEP), [bx, by] = polar(53, START + SWEEP);
    svg.innerHTML =
      `<circle cx="60" cy="60" r="57" fill="rgba(10,12,14,.62)" stroke="rgba(255,255,255,.75)" stroke-width="2"/>` +
      `<path d="M${ax} ${ay} A53 53 0 0 1 ${bx} ${by}" stroke="#c22" stroke-width="5" fill="none" opacity=".85"/>` +
      ticks +
      `<text x="60" y="101" text-anchor="middle" font-size="8" fill="#ccc">км/ч</text>` +
      `<line id="needle" x1="60" y1="60" x2="60" y2="14" stroke="#ff7a2a" stroke-width="3" stroke-linecap="round"/>` +
      `<circle cx="60" cy="60" r="5" fill="#ddd"/>`;
    root.replaceChildren(svg);
    const val = document.createElement('div');
    val.className = 'speed-val';
    root.appendChild(val);
    this.needle = svg.querySelector('#needle') as SVGLineElement;
    this.value = val;
    this.set(0);
  }

  set(kmh: number): void {
    const deg = START + (Math.min(kmh, MAX) / MAX) * SWEEP + 90;
    this.needle.setAttribute('transform', `rotate(${deg} 60 60)`);
    this.value.textContent = String(Math.round(kmh));
  }
}
