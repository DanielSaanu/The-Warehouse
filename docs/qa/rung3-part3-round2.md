# QA round 2 — rung 3 part 3 (gossip and grudges)

**Score: 7/10** · 2026-10-05 · reviewer: Opus (independent subagent), Studio Play run · branch `refactor/ai-friendly` (after f4b3cf7)

## Report (verbatim)

SCORE: 7/10

All five round-1 fixes are in and they work. I tested them under real Roblox, and the three items the builder had not checked in Studio all pass. One new defect matters to the player: a group's arrival always swaps news with its OWN village, at both ends of its route. So the squad "tells" Kenstow when it turns round in the forest, and the caravan never tells Kenstow anything. That undercuts the "watch the news walk home" test the human is about to play.

**What I ran and saw**
- `npm test`: exit 0, fail 0. `lint:luau`: all ok. `test/luau/run.js`: all ok.
- I rendered `world_1.png`, `view_29_70@5x.png` and `view_29_70_night@5x.png`. They look as before; no art changed.
- **Studio Play.** Boot was clean:
  - `[Persistence] loaded the world: saved 1327 s ago`
  - `[Restore] day 45, 37 living ... 3 groups`
  - `Stifffchoclate is back: You were gone 3 days. (1 lines)`
- **Kills, through ServerStorage.Debug** (`spawn hunter` and `strike`), with a client hook on Remotes.Notice:
  - **Witnessed kill:** the Notice log showed `Kenstow now thinks of you as wary.` then `Someone saw that.` The debug `gossip` output read `#1 day 45 kill hunter x1.00`, `v2 knows #1@0`, `you: v2 -20`, `grudge: hunter 0.30`.
  - **Second kill, rep reset to 0:** `#2 ... x1.30`, `v2 -26`, `grudge 0.60`. The scar multiplies.
  - **Kill at 88,12 with nobody near:** `Nobody saw that.` The ring and every number stayed the same.
- **v3 → v4 under real Roblox:** I read the live `Lowlands_v1/world` key (stored as v4) and rebuilt it in memory as a v3 save, with `hops` on the rumour rows, none per holder, and no `owed`. `Save.decode` returned it as v4. The rumour rows had no `hops` left, every village got `hops 2,2`, and it re-encoded as JSON and passed `Save.check`. `savetest`: `saved 15786 bytes ... reloaded as 'loaded': true`.
- I stopped Play.
- **Side effect:** autosave wrote my two test kills into Danzo's world (`world saved: day 45`). That is fine in dev mode.

**Scratch Luau probe:** squad seeds a kill, then `Tick.groupTurn` runs at the far end of its route (`dir == 1`). Output: `v1 20` (where it stands, unchanged) and `v2 -15` (home Kenstow, a whole route away, moved at 1 hop).

GOALS:
- Squad-only rumour moves the village only after one contact, once: partial. Correct in the pure tests, but the "contact" also fires at the outbound end (Tick.lua:129 → Gossip.lua:306-309), so the village hears before the squad walks home.
- Strength falls exactly HOP_FADE per hop: met. Hops are per holder (Gossip.lua:244-246); live dump shows `#1@0` at the eyewitnesses.
- A holder never applies a rumour twice: met. Booking into `knows` is the apply (Gossip.lua:238-245), and compaction scrubs `hops` with `knows`.
- No witnesses means nothing: met. Studio: `Nobody saw that.`, nothing changed.
- Grudge multiplies, gift reduces, fades; kindness never multiplied: met. Studio x1.30 → -26; Gossip.lua:201.
- catchUp(n) equals n live seconds: met. `meet` is slot-gated, and `arrive` uses the same `Tick.groupTurn` live (Bands.lua:137) and in catch-up.
- Old news leaves at STALE_DAYS: met. Gossip.lua:171-184, and owed standing no longer depends on the ring.
- Offline player gets it on return, once: met. The `w.owed` ledger is paid silently in `catchUpPlayer`, then deleted.
- Worst case in bytes: met (7750 B, plus 154 B per owed player).
- v2 and v3 saves migrate in place: met. Tested, plus my v3 → v4 run in real Studio.
- The standing-change HUD line and Debug `gossip`: met. Both seen live.
- A human plays it: not met. Still open.

PRESERVE (done well, must survive future iterations):
- Applying at tell time plus the `w.owed` ledger: logging off can no longer launder a kill, and nothing is replayed from a ring that evicts.
- Hops per holder beside `knows`: strength now depends on distance, not on the order of exchanges, and the eyewitnesses stay "sure".
- Silence as a parameter (`move(..., silent)`) instead of a module flag: an error can no longer leave it stuck on.
- `Gossip.seed` dropping events that move nobody (Gossip.lua:260-268): animal kills no longer fill the ring.
- `Gossip.rekey` is pure and decided by the saved record (Gossip.lua:367-375), with a test seeded from `newRep()`.
- Each new test was confirmed to fail on its reintroduced bug: this is why the round-1 bugs cannot quietly return.
- `Someone saw that.` / `Nobody saw that.` and the named-village line: they make the feature readable, and both are confirmed on the wire.

FIX (done poorly; why it matters; concretely how to fix):
- **`Gossip.arrive` always exchanges with `villageKey(g.tribe)`** (Gossip.lua:306-309), but the spec (RUNG3.md:246-249) says "the holder at that end".
  - Squad and band: when they turn round at the forest or ambush end, news jumps straight home. Danzo will see Kenstow change before the squad is back.
  - Caravan (tribe 1, Glenworth → Kenstow): arriving at Kenstow, it tells Glenworth. The tribe-to-tribe carrier never delivers to the place it reaches.
  - Fix: pass the end into `arrive`. In `Tick.groupTurn`, the end is `g.to` when `g.dir == 1` and `g.from` when `g.dir == -1`. Find the village whose spawn is that tile (WorldGen villages, or a stored `toVillage` on the group). Exchange with it, or with nobody when the end is not a village (forest, ambush spot).
  - Test: call `groupTurn` at the far end with `dir = 1` and assert the home village is unchanged. My probe above is that test; it currently fails.

CONSIDER (fine but could change; why; how):
- **`owe` sums without clamping** (Gossip.lua:227). My probe: six unseen child-kills owed -240, paid as -100. Online, the number clamps at each step, so a kill followed by a gift ends differently for an online and an offline player. Fix: clamp the running owed sum to ±(the range of a rep), or document the difference.
- **The announcement comes before the verdict line:** `Kenstow now thinks of you as wary.` arrives before `Someone saw that.` Calling `Standing.sawIt` before `Standing.event` (Sim.lua:428-432) reads as cause, then effect.
- **A tribe member who is not in a group counts as its whole village** (`holderOf`, Gossip.lua:47-51). A lone hunter near Glenworth seeing a kill moved Kenstow at hop 0, instantly. This is rare in normal play (villagers stay home), but worth recording as a known limit, or making the holder "the village they are standing in".
- **Village key parsing is repeated:** `rowOf` and `tribeOf` each pattern-match `^v%d+$`. Group ids are fixed strings, so a group id that looked like `v1` would collide. One `isVillageKey` helper would remove the risk.

UNCERTAIN (could not verify):
- **The squad walking home and Kenstow changing over a day, by hand:** I did not summon and fight the squad. My finding comes from the pure probe plus reading `Tick.groupTurn`.
- **The live owed path with a real leave and rejoin:** there was one Studio player, so I could not test it; I relied on the pure tests.
- **How the new HUD lines read on a phone-sized screen:** they arrive as text notices, and I did not take a screenshot.

## Builder decisions

The FIX and the owed-clamp CONSIDER are in `shared/Gossip.lua` (trigger 2), so they went to the heavy agent as H5.
Worked by the heavy agent on 2026-10-05 (H5). Reasoning is in `docs/RUNG3.md` part 3, "QA round 2".

**Fixed**
- FIX `Gossip.arrive`: it now exchanges with the village AT the end it reached (`to` if `dir == 1`, else `from`,
  matched against the village boxes by `Gossip.villageAt`), and with nobody at a forest or ambush end.
  `Tick.groupTurn(w, g, now, events, world)` passes the map (Tick.groups and Bands.turn both have it). The
  reviewer's probe is a test, and it fails when the old body is restored.
- CONSIDER owe clamp: the running owed sum is clamped to ±200 (a test fails without it). The remaining online vs
  offline difference is written down as a known limit.
- CONSIDER order: `Standing.sawIt` now runs before `Standing.event` in `killEntity`.
- CONSIDER key parsing: one `Gossip.villageIndex`, used by `tribeOf` and `rowOf`.

**Kept**: every PRESERVE item (tell-time apply and `w.owed`, per-holder hops, silence as a parameter, `seed`
dropping events that move nobody, the saved record deciding in rekey, mutation-checked tests, the saw-it lines).

**Deferred**: a lone tribe member counting as their whole village, recorded as a known limit in RUNG3 (part 4).

**Changes since last round** (for the round-3 reviewer)
- `Gossip.arrive(w, g, world)` and `Tick.groupTurn(..., world)`; new `Gossip.villageAt`, `Gossip.villageIndex`.
- `owe` clamps to ±(MAX − MIN).
- `Gossip.rekey` moved to `Save.rekeyRep` (Gossip had passed 400 lines); `Standing.rekey` calls it. Same rule.
- `Sim.killEntity`: "Someone saw that." / "Nobody saw that." comes before the standing line.
- Tests: the arrive probe (far end tells Kenstow nothing, the village at that end hears it at 1 hop, Kenstow
  hears on the walk home, a non-village end tells nobody) and the owe clamp. The existing tests that called
  `arrive` now set the squad walking home (`dir = -1`), which is the state groupTurn calls it in (-> Q3).
- No save format change. Not checked in Studio.
