export interface CityDef {
  id: string;
  name: string;
  price: number;
  sub: string;
  plaster: string[];
  trim: string;
  shutter: string | null;
  brick?: boolean;
  tiles?: boolean;
  stone?: boolean;
  roof: string;
  road: string;
  sky: string;
  floors: [number, number];
  /** Chance (0..1) that a building gets a pitched roof. */
  pitched: number;
  signs: string[];
}

export type ItemKind = 'look' | 'up';

export interface ItemDef {
  id: string;
  kind: ItemKind;
  name: string;
  desc: string;
  price: number;
  ico: string;
}

export const CITIES: CityDef[] = [
  {
    id: 'prague', name: 'Прага', price: 0, sub: 'брусчатка и черепица',
    plaster: ['#d9c9a3', '#c9a87a', '#e3d6b8', '#b89a7a', '#d8b9a0', '#c7c09a'], trim: '#efe6d2', shutter: null,
    roof: '#9c4a2f', road: '#77706a', sky: '#cdbf9f', floors: [3, 5], pitched: 0.75,
    signs: ['KAVÁRNA', 'PIVO', 'TRAFIKA', 'PEKÁRNA', 'POTRAVINY', 'HOSPODA'],
  },
  {
    id: 'amsterdam', name: 'Амстердам', price: 150, sub: 'кирпич и узкие дома',
    plaster: ['#6a3e2c', '#7a4a34', '#4c3a33', '#8a5a40', '#5a3328', '#3f3a38'], trim: '#f1efe8', shutter: null, brick: true,
    roof: '#2c2a2a', road: '#5f5d5a', sky: '#9fb0b8', floors: [3, 5], pitched: 0.55,
    signs: ['CAFÉ', 'FIETSEN', 'BAKKERIJ', 'KAAS', 'DROGIST', 'BAR'],
  },
  {
    id: 'lisbon', name: 'Лиссабон', price: 350, sub: 'плитка азулежу и солнце',
    plaster: ['#f2d16b', '#e8a8a0', '#f0ede5', '#8fb9d9', '#e6b37a', '#b9d6c2'], trim: '#fbf8f0', shutter: '#2f6d5a', tiles: true,
    roof: '#b5562f', road: '#8a8278', sky: '#a8d0e8', floors: [2, 4], pitched: 0.6,
    signs: ['PASTELARIA', 'CAFÉ', 'TABACARIA', 'FARMÁCIA', 'TASCA', 'FADO'],
  },
  {
    id: 'kotor', name: 'Котор', price: 600, sub: 'камень и горы',
    plaster: ['#cfc6b4', '#bfb5a0', '#d9d2c2', '#c4b8a2', '#b3a994'], trim: '#e9e3d6', shutter: '#4b5d3e', stone: true,
    roof: '#a85a3a', road: '#8f8a80', sky: '#b7c9d6', floors: [2, 4], pitched: 0.85,
    signs: ['KAFANA', 'PEKARA', 'APOTEKA', 'MARKET', 'KONOBA', 'GELATO'],
  },
];

export const ITEMS: ItemDef[] = [
  { id: 'glasses', kind: 'look', name: 'Зелёные очки', desc: 'Тонированные, как в 2003 году.', price: 40, ico: '🕶️' },
  { id: 'phones', kind: 'look', name: 'Наушники', desc: 'Большие, накладные, с проводом в карман.', price: 50, ico: '🎧' },
  { id: 'cap', kind: 'look', name: 'Кепка назад', desc: 'Красная, козырьком к спине.', price: 60, ico: '🧢' },
  { id: 'beanie', kind: 'look', name: 'Шапка-бини', desc: 'Чёрная, с белой полосой. Носится до лета.', price: 70, ico: '🎿' },
  { id: 'stripes', kind: 'look', name: 'Полосатые рукава', desc: 'Лонгслив в зелёную полоску под футболку.', price: 80, ico: '🧶' },
  { id: 'neon', kind: 'look', name: 'Неоновые колёса', desc: 'Светятся бирюзовым на любой улице.', price: 90, ico: '🛞' },
  { id: 'golddeck', kind: 'look', name: 'Золотая дека', desc: 'Бесполезно и очень красиво.', price: 160, ico: '✨' },
  { id: 'turbo', kind: 'up', name: 'Турбо-аккумулятор', desc: 'Максимальная скорость выше на треть.', price: 120, ico: '🔋' },
  { id: 'spring', kind: 'up', name: 'Пружина в деке', desc: 'Прыжок выше: больше времени на трюки.', price: 100, ico: '🌀' },
  { id: 'magnet', kind: 'up', name: 'Магнит', desc: 'Монеты рядом сами летят к тебе.', price: 180, ico: '🧲' },
];

/** Headwear items that can't be worn at the same time. */
export const HEADWEAR = ['cap', 'beanie'];
