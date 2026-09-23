# server/ — one line per module (docs/ARCHITECTURE.md H6)

Read this first. Update it in the same commit as any move. Sizes are line counts, rounded.

| Module | Owns | Lines |
| --- | --- | --- |
| `Server.server.lua` | remotes, player join/leave, the movement handler | 190 |
| `State.lua` | the ground everything stands on: `State.state` (the World Record), tile occupancy, the two remotes, and the client-facing helpers (`notice`, `text`, `hud`, `broadcastEntity/Object`, `restText`) | 121 |
| `Tiles.lua` | camps and bags, and every runtime write to the map's object layer: `placeCamp`, `dropBag`, `takeBag`, `tick`, `stampAll`/`unstampAll` | 144 |
| `Map.lua` | the generated map and `Map.encoded` (what joining clients are sent). Was `World.lua` | 40 |
| `Persistence.lua` | the ONLY DataStore code: `loadWorld`, `saveWorld`, player keys, autosave, the policy (never write a key you failed to read; one server holds the lease) | 174 |
| `Goals.lua` | the goal line under the clock: `set`, `clear`, `rebuild`, `tick` (carved verbatim out of Sim when it hit its ceiling) | 65 |
| `Calendar.lua` | `meta.gameSeconds`, the ONE clock: `now()`, `clock()`, `setDay()`, `skipTo()` (catch-up adds its lump to `meta.gameSeconds` directly, in `Tick.catchUp`) | 60 |
| `Restore.lua` | `Sim.state` <-> a save: `snapshot()`, and `apply(data, slept)` = the RESTORE constructor (bodies, routes, stamped tiles, overlay, `Map.reencode`) | 199 |
| `Bands.lua` | groups (caravan, squad, band): making the rows, their transient half, bodies in and out (`materialise`, `collapse`), the 1 Hz tick, turning for home. Abstract movement stays in `shared/Tick.groups` | 198 |
| `Sim.lua` | everything else, for now: entities, AI, fighting, calamities, the tick loops | 1282 |
| `Sides.lua` | who takes whose side in a fight | 280 |
| `Villagers.lua` | a villager's day: out to a plot in the morning, home to a hut door at night, home at a run from wolves and strange bandits; scans huts and plots off the map. What the farms YIELD is `shared/Farms.lua` (pure, in `Tick.daily`, saved as `tribes[].plots`) | 152 |
| `Interact.lua` | the F key: talk, trade, rest, gifts | 344 |
| `Debug.lua` | the test console (Workspace attribute `Debug`) | 290 |

## Track A progress (the plan's save-critical steps)

- [x] **A0** guard rails: `test/structure.test.js` (400-line ceiling, `os.clock` allow-list), this file, `World`→`Map`
- [x] **A1** one clock: every sim timer is `Calendar.now()` game seconds; Debug `night`/`day`/`jump` only move forward
- [x] **A2** pure ticks: `shared/Tick.lua` (`daily`, `families`, `groups`, `catchUp`); Sim turns their events into bodies and prints
- [x] **A3** records and references: `t.villageId` + `Map.village(id)` (no live village tables), `Person.village` is an id,
      `Calamity.applyOverlay` (what a load re-lays) split from `startCalamity` (the one-time half), `Ecology.wolfSurge` /
      `setTide`, bags have their own saved counter (`meta.nextBagId`)
- [x] **A4** `shared/Save.lua` (encode / decode / check / gravestones / players) + `Restore.lua` (snapshot, apply).
      Debug `reload [seconds]` saves through real JSON and restores in place, sleeping that long first
- [x] **A5** `Persistence.lua` + the boot order in `Server.server.lua`. Debug `savetest [seconds]` runs save -> lease ->
      load -> restore against a store in memory. **The real DataStore needs Studio's Game Settings -> Security ->
      "Enable Studio Access to API Services"**; without it the server says so and runs NO-SAVE, by design

## After Track A

- [x] **Headlines**: `shared/Headlines.lua`, a 64-entry ring in `meta.headlines` (births from `Tick.families` - so catch-up writes
      them - deaths and calamities from Sim). A returning player gets "Welcome back / You were gone N days" plus up to three
      lines, from tribes that would tell them. Debug `welcome <days>` shows it on demand.

## After Track A, continued

- [x] **A villager's day and farms that grow** (2026-09-21): ported from the unpushed `world-up-close` branch, which built it
      before Track A existed, onto this layout: the rule is pure (`shared/Farms.lua`, counts living villagers, so catch-up farms
      too), the walk is a projection (`Villagers.lua`), plot growth is saved, plot positions are derived. Debug `farms` reports.
      Smoke-tested in Studio (work by day, home at night, a harvest, a flood); **no QA reviewer has looked at it.**

## Rung 3 part 3 — gossip and grudges

- [x] **Part 3 built** (2026-09-23, branch `rung3-part3-gossip`). Reputation used to be instant and global; now it
      TRAVELS. The decision behind it (handoff H1, heavy session): memory is the transport, reputation and grudge are
      the ledger - a rep derived from capped memory would HEAL on eviction, which is the opposite of DESIGN §7. So
      `ps.rep` is still stored, but keyed by **holder** (`v1`..`v3` for villages, the group id for groups) instead of
      by tribe type. `shared/Gossip.lua` is the whole rule and is pure; `server/Standing.lua` is the adapter and
      `Sim.applyRep` moved into it (`Sim.lua` 1282 → 1275, ceiling 1285 → 1275).
      Two new world nodes: `villages[]` (its own tier - rung 4 gives a tribe several) and `rumours[]` (a 64 ring).
      **Save v2 → v3, upgraded IN PLACE: nothing lost, no world reset** - and `PLAYER_VERSION` deliberately stays 1,
      because `applyPlayer` discards a record whose version differs. `shared/Witness.lua` needed no change at all.
      Studio: **Danzo's real saved world migrated v2 → v3 on load** (day 13, 30 living, 3 groups, 1 camp, 3 bags, the
      welcome line, no errors), and the gossip path ran under real Roblox - a kill seen only by a squad moved the
      squad's number and not their village's, and moved the village's by exactly `HOP_FADE` once they walked home.
      Debug `gossip` dumps the ring and who knows what. **No QA reviewer has looked at it**: goals in
      `docs/qa/rung3-part3.md`, and the play-through at the bottom of it is still unticked.

## Track B (carving Sim.lua) — started, then parked

- [x] **B1 (part)** `State.lua` and `Tiles.lua` carved out verbatim; `Sim.lua` 1570 → 1410, its ceiling 1580 → 1420.
      `State.lua` is the seam the rest of Track B needs: new modules `require` it instead of being handed a `ctx`
      through `bind()`, and it can never form a cycle because it requires only `Map` and `shared/`.
- [x] **B1 (Bands, the move)** 2026-09-21: `Bands.lua` carved verbatim; `Sim.lua` 1417 → 1278, ceiling 1420 → 1285. Studio: a squad
      materialised, walked its route, collapsed when the player left, and kept moving as a record.
- [x] **B1 (stable members)** 2026-09-21: group members are PEOPLE (`Tick.enlist`: `members[].person`, `Person.group`), the same
      faces on every materialise; a death removes that person and the replacement is somebody new. People on the road are not
      `Families.villagers` (no cap, no pairing, no inheriting). **Save format v2; a v1 world is obsolete by Danzo's choice** (no
      upgrade step). Debug `group <id>` lists the members. Studio: same four hunters across a collapse.
- [x] **QA loop on all of the above** (2026-09-21): two Opus rounds, 8 then 8.5 against a bar of 8.5 - `docs/qa/track-b1-summary.md`.
      That loop also covered `State.lua` and `Tiles.lua`, which had been parked without a review.
- [ ] **B1 (rest)** the calamity half of `Calendar`. Members as `{ player = userId }` is part 4, not here.
- [ ] **B2** `Bodies`, `Brains`, `Fighting`. **B3** name the owners (R2/R3). **B4** split `WorldGen.lua`.

**Parked on purpose (Danzo, 2026-09-18): do not continue Track B without asking.** What is carved so far is tested
and smoke-tested in Studio but **no QA reviewer has looked at it** — run `/qa-loop` on it before building on it.
