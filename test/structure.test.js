// Guard rails from docs/ARCHITECTURE.md: rules about the SHAPE of the Roblox code that a model reading or writing
// it depends on. They run in `npm test` (no Luau binary needed) so they cannot be skipped.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SRC = path.join(ROOT, 'roblox', 'src');
const walk = d => fs.readdirSync(d, { withFileTypes: true }).flatMap(e =>
  e.isDirectory() ? walk(path.join(d, e.name)) : /\.luau?$/.test(e.name) ? [path.join(d, e.name)] : []);
const rel = f => path.relative(SRC, f).split(path.sep).join('/');

// H1: no file over 400 lines. Every entry here names what deletes it, and may only ever SHRINK: the number is a
// ceiling for that file, so a violator cannot quietly grow while it waits for its step.
const CEILING = 400;
const GENERATED = new Set(['shared/Sprites.lua', 'shared/SheetData.lua']);
const ALLOWED = {
  'server/Sim.lua': 1275,          // Track B1-B3 carve it into Bodies / Brains / Fighting (Bands, Tiles, State, Standing are out)
  'shared/WorldGen.lua': 880,      // Track B4: generate / query / encode
  'client/Hud.lua': 1025,          // rung 3 part 5, the client split
  'client/Client.client.lua': 660, // rung 3 part 5
  'client/Viewport.lua': 430,      // rung 4, or never: one job, 29 lines over
};

test('H1: no Lua file over 400 lines (allow-list may only shrink)', () => {
  const seen = new Set();
  for (const f of walk(SRC)) {
    const name = rel(f);
    if (GENERATED.has(name)) continue;
    const lines = fs.readFileSync(f, 'utf8').split('\n').length;
    const limit = ALLOWED[name] ?? CEILING;
    if (ALLOWED[name]) seen.add(name);
    assert.ok(lines <= limit, `${name} is ${lines} lines (limit ${limit}). Split it: docs/ARCHITECTURE.md §4b.`);
    if (ALLOWED[name]) assert.ok(lines > CEILING, `${name} is under ${CEILING} now: delete its allow-list entry.`);
  }
  for (const name of Object.keys(ALLOWED)) assert.ok(seen.has(name), `${name} is allow-listed but does not exist.`);
});

// R5: one clock. os.clock() restarts near zero on every new server, so nothing the world remembers may be stamped
// with it; sim code asks Calendar.now(). The only wall-clock reads allowed on the server are listed here by file,
// with the reason. (os.time() is not policed here: its one durable use is Restore.snapshot's `savedAt`.)
const WALL_CLOCK_OK = {
  'server/Calendar.lua': 'the one place game time is advanced from wall time',
  'server/Map.lua': 'profiling print around WorldGen.generate',
  'server/Server.server.lua': 'Movement budget and the WorldInit rate limit: per-connection, never saved',
  'server/Sim.lua': 'Movement.newBudget only (counted below)',
};

test('R5: os.clock() only where the allow-list says, and only once in Sim.lua', () => {
  for (const f of walk(path.join(SRC, 'server'))) {
    const name = rel(f);
    const code = fs.readFileSync(f, 'utf8').split('\n').filter(l => !l.trim().startsWith('--')).join('\n');
    const n = (code.match(/os\.clock\s*\(/g) || []).length;
    if (!WALL_CLOCK_OK[name]) assert.equal(n, 0, `${name} reads os.clock() ${n}x. Use Calendar.now(): docs/ARCHITECTURE.md R5.`);
    if (name === 'server/Sim.lua') {
      assert.equal(n, 1, `Sim.lua must read os.clock() exactly once (Movement.newBudget); found ${n}.`);
      assert.match(code, /Movement\.newBudget\(os\.clock\(\)\)/);
    }
  }
});
