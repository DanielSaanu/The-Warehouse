#!/usr/bin/env node
// Paint the world dump from `npm run test:luau` with the real tiles: exports/world_1.txt -> exports/world_1.png.
// Usage: node tools/preview-world.js [exports/world_1.txt] [scale] [x0 y0 x1 y1]   (a tile window, 1-based, inclusive)
import path from 'node:path';
import { makeNodeEnv, savePng } from '../src/node-env.js';
import { ROOT } from '../src/paths.js';
import { loadMap, paintMap, tileCache } from './mapfile.js';

const [file = 'exports/world_1.txt', scaleS = '1', ...win] = process.argv.slice(2);
const scale = Number(scaleS) || 1;
const map = await loadMap(file);
const [x0, y0, x1, y1] = win.length === 4 ? win.map(Number) : [1, 1, map.w, map.h];
const env = makeNodeEnv();
const canvas = env.createCanvas((x1 - x0 + 1) * 16, (y1 - y0 + 1) * 16);
const ctx = canvas.getContext('2d');
ctx.imageSmoothingEnabled = false;
await paintMap(ctx, map, tileCache(env), x0, y0, x1, y1);
let out = canvas;
if (scale !== 1) { out = env.createCanvas(canvas.width * scale, canvas.height * scale); const c = out.getContext('2d'); c.imageSmoothingEnabled = false; c.drawImage(canvas, 0, 0, out.width, out.height); }
const suffix = (win.length === 4 ? `_${x0}_${y0}_${x1}_${y1}` : '') + (scale !== 1 ? `@${scale}x` : '');
const png = path.resolve(ROOT, file.replace(/\.txt$/, '') + suffix + '.png');
await savePng(out, png);
console.log(`${path.relative(ROOT, png)}  ${out.width}x${out.height}  (${map.w}x${map.h} tiles, spawn ${map.sx},${map.sy})`);
