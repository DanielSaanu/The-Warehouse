#!/usr/bin/env node
// What the player sees: crop the painted world to the COLS x ROWS viewport around a tile, draw the player,
// optionally tint for night. Usage: node tools/preview-view.js [world.txt] [x] [y] [scale] [night 0..1]
import fs from 'node:fs/promises';
import path from 'node:path';
import { makeNodeEnv, savePng } from '../src/node-env.js';
import { renderScene } from '../src/render.js';
import { loadScene } from '../src/store.js';
import { ROOT } from '../src/paths.js';

const COLS = 16, ROWS = 12;
const CHAR = { ' ': ['grass'], ',': ['tall_grass'], '.': ['path'], '~': ['water'], '=': ['ford'], '#': ['farm'],
  'T': ['grass', 'tree'], '^': ['grass', 'rock'], 'O': ['grass', 'cave'], 'H': ['grass', 'hut'], 'B': ['grass', 'hut_burnt'],
  'W': ['grass', 'wall'], 'G': ['path', 'gate'], 'S': ['grass', 'stall'], 'b': ['grass', 'bed'], '@': ['path'] };

const [file = 'exports/world_1.txt', xs, ys, scaleS = '5', nightS = '0'] = process.argv.slice(2);
const rows = (await fs.readFile(path.resolve(ROOT, file), 'utf8')).replace(/\n+$/, '').split('\n');
let px = Number(xs), py = Number(ys);
if (!px || !py) { for (let y = 0; y < rows.length; y++) { const i = rows[y].indexOf('@'); if (i >= 0) { px = i + 1; py = y + 1; } } }
const scale = Number(scaleS) || 5, night = Number(nightS) || 0;
const env = makeNodeEnv();
const tiles = new Map();
async function tile(name) { if (!tiles.has(name)) tiles.set(name, (await renderScene(await loadScene(name), env, { strict: true })).canvas); return tiles.get(name); }
const cx = px - 0.5, cy = py - 0.5;               // continuous centre, as the client camera does
const vx = cx - COLS / 2, vy = cy - ROWS / 2;      // top-left in continuous tile coords
const canvas = env.createCanvas(COLS * 16, ROWS * 16);
const ctx = canvas.getContext('2d'); ctx.imageSmoothingEnabled = false;
for (let r = -1; r <= ROWS; r++) for (let c = -1; c <= COLS; c++) {
  const tx = Math.floor(vx) + c + 1, ty = Math.floor(vy) + r + 1;
  const ch = rows[ty - 1]?.[tx - 1];
  const layers = ch == null ? ['water'] : (CHAR[ch] || ['grass']);
  for (const l of layers) ctx.drawImage(await tile(l), Math.round((tx - 1 - vx) * 16), Math.round((ty - 1 - vy) * 16));
}
ctx.drawImage(await tile('player_down_0'), Math.round((px - 1 - vx) * 16), Math.round((py - 1 - vy) * 16));
if (night > 0) { ctx.fillStyle = `rgba(10,14,40,${night})`; ctx.fillRect(0, 0, canvas.width, canvas.height); }
const out = env.createCanvas(canvas.width * scale, canvas.height * scale);
const octx = out.getContext('2d'); octx.imageSmoothingEnabled = false; octx.drawImage(canvas, 0, 0, out.width, out.height);
const png = path.resolve(ROOT, 'exports', `view_${px}_${py}${night ? '_night' : ''}@${scale}x.png`);
await savePng(out, png);
console.log(`${path.relative(ROOT, png)}  ${out.width}x${out.height}`);
