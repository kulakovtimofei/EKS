/** City grid: N×N blocks of BS metres separated by SW-wide streets. */
export const N = 5;
export const BS = 26;
export const SW = 12;
export const CELL = BS + SW;
export const HALF = (N * CELL + SW) / 2;
export const PLAZA = { i: 2, j: 2 };

export interface Rect {
  x0: number;
  x1: number;
  z0: number;
  z1: number;
}

export function blockRect(i: number, j: number): Rect {
  const x0 = -HALF + SW + i * CELL, z0 = -HALF + SW + j * CELL;
  return { x0, x1: x0 + BS, z0, z1: z0 + BS };
}

/** Centre line of street k (0..N) along either axis. */
export const streetLine = (k: number) => -HALF + SW / 2 + k * CELL;
