import { describe, expect, it } from 'vitest';
import { SAVE_KEY, buy, equip, loadSave, persist, wearing, type KV } from '../src/save';

const mem = (init: Record<string, string> = {}): KV => {
  const m = new Map(Object.entries(init));
  return { getItem: (k) => m.get(k) ?? null, setItem: (k, v) => void m.set(k, v) };
};

describe('save', () => {
  it('starts fresh in Prague', () => {
    const s = loadSave(mem());
    expect(s).toEqual({ coins: 0, owned: { prague: true }, equipped: {}, city: 'prague' });
  });
  it('survives corrupt data and missing storage', () => {
    expect(loadSave(mem({ [SAVE_KEY]: '{oops' })).coins).toBe(0);
    expect(loadSave(null).city).toBe('prague');
    const throwing: KV = { getItem: () => { throw new Error('blocked'); }, setItem: () => { throw new Error('blocked'); } };
    expect(loadSave(throwing).coins).toBe(0);
    expect(() => persist(throwing, loadSave(null))).not.toThrow();
  });
  it('falls back to Prague for unowned or unknown cities', () => {
    expect(loadSave(mem({ [SAVE_KEY]: JSON.stringify({ city: 'lisbon' }) })).city).toBe('prague');
    expect(loadSave(mem({ [SAVE_KEY]: JSON.stringify({ city: 'atlantis', owned: { atlantis: true } }) })).city).toBe('prague');
  });
  it('round-trips', () => {
    const kv = mem();
    const s = loadSave(kv);
    s.coins = 500;
    buy(s, 'lisbon', 350, false);
    s.city = 'lisbon';
    persist(kv, s);
    expect(loadSave(kv)).toMatchObject({ coins: 150, city: 'lisbon', owned: { lisbon: true } });
  });
  it('buys only with enough coins, once', () => {
    const s = loadSave(null);
    s.coins = 50;
    expect(buy(s, 'cap', 60, true)).toBe('poor');
    expect(buy(s, 'glasses', 40, true)).toBe('ok');
    expect(s.coins).toBe(10);
    expect(buy(s, 'glasses', 40, true)).toBe('owned');
    expect(wearing(s, 'glasses')).toBe(true);
  });
  it('wears only one hat at a time', () => {
    const s = loadSave(null);
    s.coins = 1000;
    buy(s, 'cap', 60, true);
    buy(s, 'beanie', 70, true);
    expect(wearing(s, 'beanie')).toBe(true);
    expect(wearing(s, 'cap')).toBe(false);
    equip(s, 'cap', true);
    expect(wearing(s, 'beanie')).toBe(false);
  });
});
