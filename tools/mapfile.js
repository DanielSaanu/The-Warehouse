// Shared by preview-world.js and preview-view.js: read the map dump `npm run test:luau` writes to exports/world_1.txt
// (an `IDS w h sx sy` line, then the ground and object layers as WorldGen.encode strings, one byte per tile) and
// paint it with the real tiles. The byte offset is read from WorldGen.lua and the id -> sprite table from
// TileTypes.lua, so neither is copied here and a new tile needs no change in the tools.
import fs from 'node:fs/promises';
import path from 'node:path';
import { renderScene } from '../src/render.js';
import { loadScene } from '../src/store.js';
import { ROOT } from '../src/paths.js';

const SHARED = path.join(ROOT, 'roblox', 'src', 'shared');

/** { offset, ground: Map<id, sprite>, object: Map<id, sprite> } parsed from the Lua sources. */
export async function readTileTable() {
  const gen = await fs.readFile(path.join(SHARED, 'WorldGen.lua'), 'utf8');
  const offset = Number(gen.match(/WorldGen\.OFFSET\s*=\s*(\d+)/)?.[1]);
  if (!offset) throw new Error('WorldGen.OFFSET not found in WorldGen.lua');
  const tt = await fs.readFile(path.join(SHARED, 'TileTypes.lua'), 'utf8');
  const ground = new Map(), object = new Map();
  for (const m of tt.matchAll(/\[(\d+)\]\s*=\s*\{\s*id\s*=\s*\d+,\s*name\s*=\s*"(\w+)",\s*sprite\s*=\s*"(\w+)"/g)) ground.set(Number(m[1]), m[3]);
  for (const m of tt.matchAll(/obj\((\d+),\s*"(\w+)",\s*(?:true|false)(?:,\s*\{([^}]*)\})?\)/g)) {
    const sprite = m[3]?.match(/sprite\s*=\s*"(\w*)"/)?.[1];
    object.set(Number(m[1]), sprite === undefined ? m[2] : sprite);
  }
  return { offset, ground, object };
}

/** Load exports/world_1.txt (or the file given): { w, h, sx, sy, ground: Uint8Array, object: Uint8Array } of ids. */
export async function loadMap(file) {
  const text = await fs.readFile(path.resolve(ROOT, file), 'utf8');
  const lines = text.replace(/\r/g, '').split('\n');
  const head = lines[0].match(/^IDS (\d+) (\d+) (\d+) (\d+)$/);
  if (!head) throw new Error(`${file} does not start with an IDS line; run npm run test:luau first`);
  const [w, h, sx, sy] = head.slice(1).map(Number);
  const { offset, ground, object } = await readTileTable();
  const decode = s => { const out = new Uint8Array(w * h); for (let i = 0; i < w * h; i++) out[i] = s.charCodeAt(i) - offset; return out; };
  if (lines[1].length !== w * h || lines[2].length !== w * h) throw new Error(`${file}: layer length is not ${w}x${h}`);
  return { w, h, sx, sy, ground: decode(lines[1]), object: decode(lines[2]), groundSprite: ground, objectSprite: object };
}

/** Render-once tile cache. */
export function tileCache(env) {
  const tiles = new Map();
  return async name => {
    if (!tiles.has(name)) tiles.set(name, (await renderScene(await loadScene(name), env, { strict: true })).canvas);
    return tiles.get(name);
  };
}

/**
 * Paint tiles x0..x1, y0..y1 (1-based, inclusive, may run off the map: off-map is water) onto ctx with the map's
 * tile (x0, y0) at pixel (ox, oy). Ground first, then objects north row first so the south draws over the north,
 * each sprite standing on its anchor tile with its bottom-left there: a 48x48 hall covers its 3x2 footprint and
 * hangs its top row over the tile behind, as the Viewport does.
 */
export async function paintMap(ctx, map, tile, x0, y0, x1, y1, ox = 0, oy = 0) {
  const at = (x, y) => (y - 1) * map.w + (x - 1);
  const inMap = (x, y) => x >= 1 && y >= 1 && x <= map.w && y <= map.h;
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const name = inMap(x, y) ? map.groundSprite.get(map.ground[at(x, y)]) : 'water_0';
    ctx.drawImage(await tile(name || 'grass'), ox + (x - x0) * 16, oy + (y - y0) * 16);
  }
  // objects whose sprite reaches into the window from below or from the right are drawn too (up to 3 tiles)
  for (let y = y0; y <= y1 + 3; y++) for (let x = x0 - 3; x <= x1; x++) {
    if (!inMap(x, y)) continue;
    const id = map.object[at(x, y)];
    if (!id) continue;
    const name = map.objectSprite.get(id);
    if (!name) continue; // `part`: the body of a multi-tile object, drawn from its anchor
    const img = await tile(name);
    ctx.drawImage(img, ox + (x - x0) * 16, oy + (y - y0 + 1) * 16 - img.height);
  }
}
