#!/usr/bin/env node
// Paint an ASCII world dump (from `npm run test:luau`) with the real tiles: exports/world_1.txt -> exports/world_1.png
import fs from 'node:fs/promises';
import path from 'node:path';
import { makeNodeEnv, savePng } from '../src/node-env.js';
import { renderScene } from '../src/render.js';
import { loadScene } from '../src/store.js';
import { ROOT } from '../src/paths.js';

const CHAR = { ' ': ['grass'], ',': ['tall_grass'], '.': ['path'], '~': ['water'], '=': ['ford'], '#': ['farm'],
  'T': ['grass', 'tree'], '^': ['grass', 'rock'], 'O': ['grass', 'cave'], 'H': ['grass', 'hut'], 'B': ['grass', 'hut_burnt'],
  'W': ['grass', 'wall'], 'G': ['path', 'gate'], 'S': ['grass', 'stall'], 'b': ['grass', 'bed'], '@': ['path', 'player_down_0'] };

const file = process.argv[2] || 'exports/world_1.txt';
const scale = Number(process.argv[3]) || 1;
const text = await fs.readFile(path.resolve(ROOT, file), 'utf8');
const rows = text.replace(/\n+$/, '').split('\n');
const env = makeNodeEnv();
const tiles = new Map();
async function tile(name) {
  if (!tiles.has(name)) tiles.set(name, (await renderScene(await loadScene(name), env, { strict: true })).canvas);
  return tiles.get(name);
}
const W = Math.max(...rows.map(r => r.length)), H = rows.length;
const canvas = env.createCanvas(W * 16, H * 16);
const ctx = canvas.getContext('2d');
ctx.imageSmoothingEnabled = false;
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const layers = CHAR[rows[y][x]] || ['grass'];
  for (const l of layers) ctx.drawImage(await tile(l), x * 16, y * 16);
}
let out = canvas;
if (scale !== 1) { out = env.createCanvas(canvas.width * scale, canvas.height * scale); const c = out.getContext('2d'); c.imageSmoothingEnabled = false; c.drawImage(canvas, 0, 0, out.width, out.height); }
const png = path.resolve(ROOT, file.replace(/\.txt$/, '') + (scale !== 1 ? `@${scale}x` : '') + '.png');
await savePng(out, png);
console.log(`${path.relative(ROOT, png)}  ${out.width}x${out.height}`);
