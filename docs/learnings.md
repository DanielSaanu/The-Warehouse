# Learnings

**Created:** 2026-09-23 · **Last updated:** 2026-09-23

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
*(2026-09-23, rung 3 part 3.)*

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

**T1 — The line ceiling in `test/structure.test.js` is a design input, not a lint you notice at the end.**
`ALLOWED` is a ratchet that *may only shrink*, and `server/Sim.lua` sits at 1282 against 1285. So "add it to Sim"
is not available: new server behaviour goes in a new module, and the cheapest way to pay for it is to move an
existing function out of Sim at the same time. Check the headroom **before** planning where code goes.
*(2026-09-23, handoff H1 — why rung 3 part 3 builds `server/Standing.lua` instead of growing Sim.)*

## G — Git and generated files

*(none yet)*

## Q — QA loop and review

**Q1 — A pure test suite cannot see a missing side effect.** Every gossip rule passed `test:luau` while the player
was never TOLD their standing had changed: the rule moved the right number, and "the number moves visibly" is not
something a pure function can assert. The Studio smoke test found it in one line. So for anything the player is
meant to notice, the checklist item is not "the value changed" but "the line appeared and the HUD refreshed", and
that item belongs in the Studio pass. *(2026-09-23, rung 3 part 3 - `Gossip.onChange`.)*
