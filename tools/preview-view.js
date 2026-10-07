#!/usr/bin/env node
// What the player sees: the COLS x ROWS viewport around a tile, the player drawn on it, optionally tinted for night.
// Usage: node tools/preview-view.js [exports/world_1.txt] [x] [y] [scale] [night 0..1]   (x, y default to the spawn)
import path from 'node:path';
import { makeNodeEnv, savePng } from '../src/node-env.js';
import { ROOT } from '../src/paths.js';
import { loadMap, paintMap, tileCache } from './mapfile.js';

const COLS = 16, ROWS = 12;
const [file = 'exports/world_1.txt', xs, ys, scaleS = '5', nightS = '0'] = process.argv.slice(2);
const map = await loadMap(file);
const px = Number(xs) || map.sx, py = Number(ys) || map.sy;
const scale = Number(scaleS) || 5, night = Number(nightS) || 0;
const env = makeNodeEnv();
const tile = tileCache(env);
const cx = px - 0.5, cy = py - 0.5;               // continuous centre, as the client camera does
const vx = cx - COLS / 2, vy = cy - ROWS / 2;      // top-left in continuous tile coords
const canvas = env.createCanvas(COLS * 16, ROWS * 16);
const ctx = canvas.getContext('2d'); ctx.imageSmoothingEnabled = false;
const tx0 = Math.floor(vx), ty0 = Math.floor(vy); // first tile drawn (1-based tile tx0 + 1 starts at pixel (tx0 - vx) * 16)
await paintMap(ctx, map, tile, tx0, ty0, tx0 + COLS + 1, ty0 + ROWS + 1, Math.round((tx0 - 1 - vx) * 16), Math.round((ty0 - 1 - vy) * 16));
ctx.drawImage(await tile('player_down_0'), Math.round((px - 1 - vx) * 16), Math.round((py - 1 - vy) * 16));
if (night > 0) { ctx.fillStyle = `rgba(10,14,40,${night})`; ctx.fillRect(0, 0, canvas.width, canvas.height); }
const out = env.createCanvas(canvas.width * scale, canvas.height * scale);
const octx = out.getContext('2d'); octx.imageSmoothingEnabled = false; octx.drawImage(canvas, 0, 0, out.width, out.height);
const png = path.resolve(ROOT, 'exports', `view_${px}_${py}${night ? '_night' : ''}@${scale}x.png`);
await savePng(out, png);
console.log(`${path.relative(ROOT, png)}  ${out.width}x${out.height}`);
