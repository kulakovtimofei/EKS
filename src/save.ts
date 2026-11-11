import { CITIES, HEADWEAR } from './data';

export const SAVE_KEY = 'eurokick-save-v1';

export interface SaveData {
  coins: number;
  owned: Record<string, boolean>;
  /** Look items: false = owned but taken off. Missing = worn. */
  equipped: Record<string, boolean>;
  city: string;
}

export interface KV {
  getItem(k: string): string | null;
  setItem(k: string, v: string): void;
}

function defaults(): SaveData {
  return { coins: 0, owned: { prague: true }, equipped: {}, city: 'prague' };
}

/** Load and sanitise a save. Never throws: bad or blocked storage gives a fresh save. */
export function loadSave(storage: KV | null): SaveData {
  const save = defaults();
  try {
    const raw = storage?.getItem(SAVE_KEY);
    if (raw) {
      const s = JSON.parse(raw) as Partial<SaveData>;
      if (typeof s.coins === 'number' && Number.isFinite(s.coins) && s.coins >= 0) save.coins = Math.floor(s.coins);
      if (s.owned && typeof s.owned === 'object') Object.assign(save.owned, s.owned);
      if (s.equipped && typeof s.equipped === 'object') Object.assign(save.equipped, s.equipped);
      if (typeof s.city === 'string') save.city = s.city;
    }
  } catch {
    /* corrupt or unavailable storage: keep defaults */
  }
  save.owned.prague = true;
  if (!CITIES.some((c) => c.id === save.city) || !save.owned[save.city]) save.city = 'prague';
  return save;
}

export function persist(storage: KV | null, save: SaveData): void {
  try {
    storage?.setItem(SAVE_KEY, JSON.stringify(save));
  } catch {
    /* private mode etc. */
  }
}

export const has = (save: SaveData, id: string): boolean => !!save.owned[id];
export const wearing = (save: SaveData, id: string): boolean => has(save, id) && save.equipped[id] !== false;

export type BuyResult = 'ok' | 'owned' | 'poor';

export function buy(save: SaveData, id: string, price: number, isLook: boolean): BuyResult {
  if (has(save, id)) return 'owned';
  if (save.coins < price) return 'poor';
  save.coins -= price;
  save.owned[id] = true;
  if (isLook) equip(save, id, true);
  return 'ok';
}

/** Toggle a look item; putting on a hat takes the other hat off. */
export function equip(save: SaveData, id: string, on: boolean): void {
  save.equipped[id] = on;
  if (on && HEADWEAR.includes(id)) for (const h of HEADWEAR) if (h !== id) save.equipped[h] = false;
}
