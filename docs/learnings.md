# Learnings

**Created:** 2026-09-23 · **Last updated:** 2026-10-06

Rules that **generalise** — things a session got wrong once and should never get wrong again. One-off typos and
trivia stay in the QA goals file or the commit message; they do not earn a line here.

`docs/PRINCIPLES.md` is the other rulebook: that one is about *what makes a good game*, this one is about *how
to work in this repo*. If a rule tells you what to do at a fork while building, it goes here. If it tells you
what to do at a fork while designing, it goes there.

Each rule has a stable ID so a handoff, a QA report or a commit can cite it (e.g. "→ S2"). Sections:

| ID | Section |
|---|---|
| **A** | Art — sprites, scenes, the renderer |
| **S** | Shared Luau — purity, ticks, determinism |
| **P** | Persistence — save format, DataStore, catch-up |
| **T** | Tooling — node CLI, Rojo, luau, the MCP Studio link |
| **G** | Git and generated files |
| **Q** | QA loop and review |

Behind each rule: the date and the branch or handoff that paid for it.

---

## A — Art

*(none yet)*

## S — Shared Luau

**S3 — A dedupe set for "has this been applied" must be keyed by everything the application is keyed by.**
Gossip books a rumour at a HOLDER, so one rumour legitimately moves several numbers. My first `ps.heard[id]` was
keyed by rumour alone, so a rumour known in two villages moved the first village's number and silently skipped the
second. It is now `ps.heard[holderKey][id]`. The general shape: if the write is per (a, b), the "already done" set
is per (a, b) too, and a set keyed by less than that is a bug that only shows up in the second case.
*(2026-09-23, rung 3 part 3. Since H3 the gossip case needs no such set: applying at tell time made `knows` the
only one.)*

**S4 — A quantity that differs per reader does not live on the shared row.** Gossip's `hops` was one counter on
the rumour, but "how many hands did this come through" is a fact about each holder that heard it. On the shared
row it rose with every exchange anywhere, so strength depended on exchange order, a replay later read a bigger
number than the live path had, and the eyewitnesses' own story turned into hearsay. Put it beside the per-reader
link (`hops[i]` next to `knows[i]`). Same for anything "as seen by" someone. *(2026-10-05, handoff H3.)*

**S5 — "Apply it later" from a capped transport is S1 again.** Replaying `knows` for a player who was offline
made the ring a ledger by the back door: whatever left the ring before they returned was never applied. If
something is owed, write what is owed at the moment it becomes owed (`w.owed`), and let the transport drop freely.
*(2026-10-05, handoff H3.)*

**S1 — A capped list can be a memory, but never a ledger.**
Anything with an eviction rule (an LRU, a ring, a "keep the last N") *heals when it evicts*. So a number that is
supposed to be permanent — reputation, a grudge, a debt — must be **stored**, and the capped thing is only the
transport that moves it. Deriving a durable number from a bounded history is the bug, and it looks exactly like
good normalisation until the cap is reached. Test for it by filling the cap past its limit and asserting the
number did not move. *(2026-09-23, handoff H1 — why rung 3 part 3's reputation is not derived from gossip.)*

**S2 — Before proposing a data shape, encode it and count the bytes.**
"Free per tribe, careful per person" is a rule of thumb, not a number, and the two candidate shapes for part 3's
memory came out **216 KB** and **22 KB** for the same feature. Measuring took twenty minutes with `test/luau/run.js`'s
`bundle()` and a `jlen` walker over the encoded table; guessing would have shipped the wrong one. Put the number
in the doc, and then put it in a test, so the next shape change has to argue with it. *(2026-09-23, handoff H1.)*

**S6 — A record that mirrors a live body moves on what the body DID, never on what it was asked to do.** Sim set
the group's route index the moment it asked for a path, whether or not one was found, so the record walked home
while the bodies stood in the forest, and everything keyed on the record (gossip, the stock, the headlines)
believed it. Update the mirror from the outcome (a path found, a step taken, the leader on the tile), and when the
two have drifted, re-anchor the record to the body. *(2026-10-05, handoff H6.)*

**S7 — Before putting a new kind of thing into an existing list, find every reader that counts or walks it.**
ARCHITECTURE planned a joining player as one more `g.members` row (`{ player = userId }`). Three rules read that
list as people: `materialise` makes a body per row, `Tick.daily` refills by counting rows, the band breaks at
`#members * 2 < fullSize`; and the list is saved. A player row would have spawned an NPC double, blocked
replacements, skewed the break and sat in the world key after they left. Grep the list's name, read every loop and
`#`, and if any reader assumes the old kind, give the new kind its own field (`g.riders`). *(2026-10-05, handoff H7.)*

**S8 — Measure "closer" in the metric the move uses, and test a fallback in the exact shape that triggers it.**
`followPath`'s side-step took a neighbour strictly closer by Chebyshev distance, but steps are 4-way: on a straight
road every side tile is equally far, and at a corner only the goal itself is closer, so the fallback could never
fire. It read as working for months because nothing ever showed it failing; a caravan master stood ringed by his
own guards for minutes. Write the test where the fallback is the ONLY way out (ringed, blocked on a straight
line), and watch it fail before the fix. *(2026-10-06, handoff H9.)*

## P — Persistence

**P1 — A change to the PLAYER key is additive-optional, never a version bump.**
`Save.applyPlayer` starts `if data.version ~= Save.PLAYER_VERSION then return nil, nil end` — a mismatch discards
the **whole** record, so bumping `PLAYER_VERSION` wipes every player's coin, inventory, standing and rest point.
New player fields therefore go in with an empty default (`data.grudge or {}`) and the version stays where it is.
Re-shaping an existing field (part 3 re-keys `rep`) happens **after** `applyPlayer`, in `Restore.player`, where
the world is there to map it with. The world key is the opposite: it bumps `Save.VERSION` and gets a real step in
`Save.migrate`. *(2026-09-23, handoff H1 — found while pricing rung 3 part 3.)*

**P2 — Anything that decays over longer than the catch-up cap is a closed form over a day count.**
`Tick.CATCHUP_CAP` is four in-game weeks, so a per-tick decrement simply does not happen for a world that slept
longer. `Reputation.fade(v, days)` is the pattern to copy: applied once per day online and once by
`day - lastSeenDay` on join. Every span is measured in **in-game days**, and a world nobody plays does not age —
which is the answer, not a problem to reconcile. Never invent a wall-clock span to "make up" the missed decay:
that is a second clock, and R5 says there is one. *(2026-09-23, handoff H1 — grudges "decay over years".)*

**P3 — Never touch `WorldGen.GEN_VERSION` for a change that is not to the map generator.**
`Save.decode` discards the world key on a `genVersion` mismatch — by design, because the seed would no longer grow
the map the records were made on. A save-format change bumps `Save.VERSION`; a generator change bumps
`GEN_VERSION` and means a new world. Confusing the two silently deletes the world Danzo is playing.
*(2026-09-23, handoff H1.)*

**P4 — A mode that must never touch the real save is gated where the store is OPENED, and read once at boot.**
Returning early from `loadWorld` is not enough on its own: a later code path (a test hook, a new feature) that
calls the store directly would still reach the real data. So dev mode also makes `getStore()` refuse, and the flag
is read once, because a mode that flips mid-session puts a throwaway world on the path to the real key. Default the
mode to the side that cannot lose data. *(2026-10-05, handoff H4.)*

## T — Tooling

**T2 — Rojo does NOT sync into a Studio session that is already in Play, and a Studio `require` cache is per
DataModel.** Edits made after Play started are invisible until Play stops and starts again, and an `execute_luau`
call that required a module earlier keeps the OLD copy for the life of that DataModel. Both cost a full round of
"the fix did not work" when the fix was fine. Stop Play, start Play, then test. Also: `execute_luau` gets its own
require cache, so it cannot read the running server's `Sim.state` - build a state of the right shape and bind the
module under test instead. *(2026-09-23, rung 3 part 3.)*

**T3 — `Map.village` throws unless `Map.init` has run**, so it is not safe in a code path that might run before
the world is built. A cosmetic label is never worth an error: look it up in a `pcall` and word the line the plain
way if it fails. *(2026-09-23, rung 3 part 3 - the standing-change line.)*

**T5 — A Studio test harness that moves the player is part of the experiment: put it where a player would
stand.** Following the caravan by teleporting onto the tile beside the leader parked a body on the leader's next
step, and the leader stalled; read as "the caravan is broken" it cost three Play restarts. Follow from BEHIND
(the side the route came from), at a distance, and before blaming the code, move the harness away and see whether
the fault goes with it. *(2026-10-05, handoff H8.)* The same goes for blockers you spawn: read the map first (`exports/world_1.txt`).
A stranger parked on the tile inside Glenworth's one GATE is an impassable wall, and a leader waiting there is right
(2026-10-06, H9).

**T1 — The line ceiling in `test/structure.test.js` is a design input, not a lint you notice at the end.**
`ALLOWED` is a ratchet that *may only shrink*, and `server/Sim.lua` sits at 1282 against 1285. So "add it to Sim"
is not available: new server behaviour goes in a new module, and the cheapest way to pay for it is to move an
existing function out of Sim at the same time. Check the headroom **before** planning where code goes.
*(2026-09-23, handoff H1 — why rung 3 part 3 builds `server/Standing.lua` instead of growing Sim.)*

**T4 — Comments count against the line ceilings too.** `test/structure.test.js` counts every line, comments
included. `Sim`, `WorldGen`, `Hud`, `Viewport` and `Client.client` sit 1–3 lines under ceilings that may only
shrink, so even a documentation pass cannot add a header line to them. Put that information in the folder README
instead. Check headroom (`wc -l` against `ALLOWED`) before adding anything to a big file.
*(2026-09-27, `refactor/ai-friendly`.)*

## G — Git and generated files

**G1 — Generated files are regenerated, never edited, and only Danzo uploads.** `roblox/src/shared/Sprites.lua`
and `roblox/assets.lock.json` come from `node bin/warehouse.js roblox build`. Claude runs the
build (it keeps the old asset id and prints CHANGED); Danzo runs `--upload` and commits the pair. On the PC, if
those two are locally modified, `git checkout -- roblox/src/shared/Sprites.lua roblox/assets.lock.json` before
`git pull`. *(From CLAUDE.md, restated as a rule 2026-09-27.)*

**G2 — The Rojo instance tree is an API: prove it unchanged with a sourcemap diff.** Code finds modules by name
(`Shared:WaitForChild("Gossip")`, `script.Parent:WaitForChild("Map")`) and remotes by name
(`Remotes:WaitForChild("Move")`), so any file move, rename or re-nest must leave the tree identical: the same names,
parents and classes (`.server.lua` Script, `.client.lua` LocalScript, `.lua` ModuleScript). Run
`rojo sourcemap roblox/default.project.json` before and after, and compare names, classNames and nesting. `.md`
files in `src/` are ignored by Rojo. Also: Windows paths are case-insensitive, so `docs/architecture.md` IS
`docs/ARCHITECTURE.md` here. Never create a file that differs from an existing one only by case.
*(2026-09-27, `refactor/ai-friendly`.)*

**G3 — A doc that other files cite by section is an API too: split it behind a hub at the old path.** Luau
comments, tests and other docs say `ARCHITECTURE.md R5` or `DESIGN.md §7`; moving that text strands every one of
them, and editing the Luau ones is a trigger for no gain. So keep the old file as a hub with a table mapping every §
and rule ID to its new file, keep the § numbers in the moved headings, and move by LINE RANGE with a script (never
retype). Prove "lose nothing" mechanically: every non-blank line of the old file (`git show <ref>:<path>`) must be in
the multiset of hub + new files; then a relative-link check over all tracked `.md`. *(2026-09-27, handoff H2.)*

## Q — QA loop and review

**Q3 — A test that calls the inner function directly can pin the bug in place.** Every gossip test called
`Gossip.arrive(w, squad)` on a squad standing at pos 1 heading OUT, and passed only because `arrive` ignored which
end it was at and always told the home village. Drive the rule through the caller that fires it in production
(`Tick.groupTurn` at a real route end), or set the fixture to the exact state that caller is in.
*(2026-10-05, handoff H5.)*

**Q2 — Build a test's fixture the way production builds the object, or the test hides the bug.** `Standing.rekey`
was "lossless" in every hand check because each check started `rep` empty; production seeds `rep` with START at
every village before rekey runs, so "copy only if empty" never copied and every v2 player was reset. Before
asserting a migration or a merge, trace the real call order (`Sim.addPlayer` -> `applyPlayer` -> `rekey`) and seed
the fixture to match. *(2026-10-05, handoff H3.)*

**Q4 — A per-cycle counter resets on the cycle's own signal, not on one of the paths that ends it.** Round 1 reset a
rider's leg (`g.walked`) in `Ride.arrive`, which only a MATERIALISED turn calls, so every leg a group walked folded
piled into the next ridden one (`rode 53 of 163`, paid 2 not 7). It passed its own Studio check because Debug
`summon` + `arrive` reset the leg by hand. Find the state that defines the cycle (here `dir`) and reset on its
change, so every path that ends a cycle (folded, live, catch-up, a debug command) resets it; then test the path the
repro did NOT use. *(2026-10-06, handoff H10.)*

**Q1 — A pure test suite cannot see a missing side effect.** Every gossip rule passed `test:luau` while the player
was never TOLD their standing had changed: the rule moved the right number, and "the number moves visibly" is not
something a pure function can assert. The Studio smoke test found it in one line. So for anything the player is
meant to notice, the checklist item is not "the value changed" but "the line appeared and the HUD refreshed", and
that item belongs in the Studio pass. *(2026-09-23, rung 3 part 3 - `Gossip.onChange`.)*
