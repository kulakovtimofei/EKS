import { CITIES, ITEMS, type ItemKind } from '../data';
import { buy, equip, has, type SaveData } from '../save';

export type ShopTab = ItemKind | 'city';

export interface ShopHooks {
  save: SaveData;
  currentCity: () => string;
  onChange: () => void;
  onBuy: () => void;
  onTravel: (id: string) => void;
}

interface Row {
  id: string;
  kind: ItemKind | 'city';
  name: string;
  desc: string;
  price: number;
  ico: string;
}

export function renderShop(box: HTMLElement, tab: ShopTab, h: ShopHooks): void {
  const { save } = h;
  box.replaceChildren();
  const list: Row[] =
    tab === 'city'
      ? CITIES.map((c) => ({ id: c.id, kind: 'city', name: c.name, desc: c.sub, price: c.price, ico: '🎫' }))
      : ITEMS.filter((i) => i.kind === tab);
  const rerender = () => renderShop(box, tab, h);
  for (const it of list) {
    const el = document.createElement('div');
    el.className = 'item';
    const sw = document.createElement('div');
    sw.className = 'sw';
    sw.textContent = it.ico;
    const b = document.createElement('b');
    b.textContent = it.name;
    const span = document.createElement('span');
    span.textContent = it.desc;
    el.append(sw, b, span);
    const btn = document.createElement('button');
    if (!has(save, it.id)) {
      btn.textContent = 'Купить за ' + it.price;
      btn.disabled = save.coins < it.price;
      btn.onclick = () => {
        if (buy(save, it.id, it.price, it.kind === 'look') !== 'ok') return;
        h.onBuy();
        h.onChange();
        rerender();
      };
    } else if (it.kind === 'look') {
      const on = save.equipped[it.id] !== false;
      btn.textContent = on ? 'Надето' : 'Надеть';
      btn.className = on ? 'equipped' : 'off';
      btn.onclick = () => {
        equip(save, it.id, !on);
        h.onChange();
        rerender();
      };
    } else if (it.kind === 'city') {
      const here = h.currentCity() === it.id;
      btn.textContent = here ? 'Ты здесь' : 'Поехать';
      btn.className = here ? 'equipped' : '';
      btn.disabled = here;
      btn.onclick = () => h.onTravel(it.id);
    } else {
      btn.textContent = 'Установлено';
      btn.className = 'equipped';
      btn.disabled = true;
    }
    el.appendChild(btn);
    box.appendChild(el);
  }
}
