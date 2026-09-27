# Design §1–§3: pillars, decisions made, the session loop

Part of [`docs/DESIGN.md`](../DESIGN.md), which maps every § to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of DESIGN.md, wherever it now lives.

## 1. Pillars

1. **The world does not need you.** Tribes and animals follow their own rules whether or not a player is nearby.
2. **Everything remembers.** Every tribe, group and creature keeps a relationship with each player, and they tell each other.
3. **Simple to touch, deep underneath.** Move, attack, interact. That's the whole controller. The depth is in who
   you did it to. The sharper form of this (Danzo, 2026-09-18): **hand the player systems, not content, and ask
   them what they want to do with it** — systems related to systems, enough of them that nobody can tell you
   which one you are supposed to be using. A person here is in the family tree *and* the gossip network *and* a
   role *and* a tribe's headcount, so killing one moves four systems at once. That, not the quantity of things,
   is where the game is supposed to get deep. The portable version is principle 2 in `docs/PRINCIPLES.md`.
4. **You get better, your numbers don't.** No levels. Skill, gear, standing and knowledge are the progression.
5. **The world says yes; the consequences say no.** (Danzo, 2026-09-18, off a Palworld video.) Freedom is the
   draw. Palworld is fun because it hands the player an absurd amount of rope and never takes it back, and that
   is the vibe here: anything you can think to do, you should probably be able to do. So a system never refuses
   an action just because it was not designed for it. No invincible NPCs, no "you can't do that here", no
   content gates on doors the fiction leaves open. If a thing is in the world you may kill it, rob it, buy it,
   burn it, work for it or marry into it. What stops you is the world answering: §7 carries what you did to
   people who were not there, §5's tribes answer for their own, and §13 lets you become the thing that answers
   back. **When a builder has to choose between blocking an action and letting it through with a consequence,
   let it through.** The exceptions are few and they are all technical, not design: no PvP damage (§14), and the
   caps in §4 stay caps.
   **The same rule governs belonging, not just violence** (Danzo, 2026-09-18): every system the world runs, the
   player can *join*, not merely interact with. Ride with a caravan, hunt with a squad, ride with a band, and
   later hire and build — all under the rules NPCs already follow, because a group is a record with members and
   the player can be one of them. No player-only systems and no NPC-only ones; no permission checks, only
   standing; and never a menu that spends coin where a person should be asked. The test for any feature:
   **could an NPC do this, with the same data, under the same rules?** Built in `docs/RUNG3.md` part 4.
6. **The main story is the compass, not the spine.** (Danzo, 2026-09-18.) You can get from the start of
   Lowlands to the end of it by only ever doing what interests you — hunt, trade, feud, build, take a tribe.
   The main story exists for the minutes when nothing does: the first one, and the one at hour twenty when you
   have just finished a thing and are standing still. So it never gates a system, never expires, never scolds,
   points rather than choreographs, and everything it leads to is reachable without it. **In Lowlands the
   compass is a person, not a log** — see §12. The general form of this, kept portable for whatever gets built
   after Lowlands, is principle 1 in `docs/PRINCIPLES.md`.

## 2. Decisions made (do not relitigate without a reason)

| Topic | Decision |
| --- | --- |
| View | Top-down tile grid, 16x16 sprites, scrolling camera over a large map |
| Movement | Real time, tile steps (Zelda / Stardew feel), server authoritative |
| Attack | Left mouse button (touch: on-screen button later). Hits the tile you face |
| Interact | F key. A prompt appears when something interactable is adjacent (touch: tap the prompt) |
| Death | Wake where you last **rested** (village bed or your camp). Lose carried goods and some reputation |
| Rest | F at a bed in a village, or at your own camp, sets your spawn point. Hostile villages refuse |
| Day one kit | Knife, waterskin, 2 food, and one **camper set** (bedroll + flint). The camper set is **single use** |
| Progression | No XP, no levels. Player base stats are fixed so the ecosystem stays balanced. Gear, reputation, knowledge, and your own skill |
| Persistence | World state is saved to DataStore and **caught up** on load: the simulation runs the missed time |
| Players vs players | No PvP damage for now. Tribes judge each player individually. A dropped bag is visible only to its owner for 10 minutes |
| Setting | Grasslands overworld: meadows, forest, rivers, caves, hills. Primitive tribes, real wildlife |
| Player | Just a person. Starts in a village that was just plundered |
| First map | About 96x96 tiles, three villages (one per tribe type, mid sized) |
| Time | 1 in-game day = 10 real minutes (7 day, 3 night). 7 days = 1 week. One calamity per week |
| Inventory | 10 slots, goods stack |
| Names | Every entity has a random first and last name. Children keep the father's last name |

## 3. The session loop (what you actually do)

Hunt or gather -> carry it to a village -> sell -> buy a better weapon, a shield, a camper set -> push one
region further out -> be home or camped before the weekly calamity. **Selling is the heartbeat, the calamity is
the clock.** Every system below exists to make one of those steps interesting: who you sell to, what the road
between costs you, and what the world did while you were away.
