# Rung 3: memory, belonging and money — the build plan

DESIGN.md §16 names rung 3 in three lines. This is the order to build it in and why, split into parts the way
rung 2 was, each one its own branch, goals file and QA loop.

Rung 2 ended with a world that lives, remembers you for as long as the server is up, and can be played by a
stranger on a phone. Rung 3 is about that memory outliving the server, about the tribes wanting something from
you rather than merely existing near you — and about the player stopping being a visitor.

---

## The rule above the others

*(Danzo, 2026-09-18. It governs every part below, and it is why several of them changed shape.)*

**The player is a participant, not a customer. Every system the world runs, the player can join — not just
interact with.**

Palworld's draw is that the player is *part* of the world rather than the thing the world is arranged around.
Lowlands already has the harder half of that: tribes, caravans, squads, bands, ecology and families all run on
their own schedule whether or not anyone is watching (pillar 1). What it does not have is a way in. Today a
player can *trade with* a caravan; they cannot *be* the caravan. They can fight a band; they cannot ride with
one.

What this rules out, concretely:

- **No menu that spends coin.** Hiring, building and funding are not shop screens. They are asking a named
  person, who has an opinion of you, to do a thing they already know how to do.
- **No player-only systems, and no NPC-only systems.** If a group of NPCs can walk a trade route and split the
  profit, the player can be one of its members, under the same rules. The machinery is the same machinery.
- **No permission checks, only standing.** A system never asks *are you allowed*; it asks *what are you, to us*.
  That is pillar 5 (the world says yes, the consequences say no) pointed at membership instead of violence.
- **Every system is tolerant of how you play.** There is no correct way to be in this world. Ride with bandits,
  guard caravans, hunt, farm, feud, or wander — each is a way the systems already work, not a mode written for
  you. (Principle 2: you must not be able to answer "what should I be doing".)

The test for any part below: **could an NPC do this, under the same rules, with the same data?** If no, it is a
menu wearing a system's clothes and it needs rethinking.

---

## Decided: one shared world

DESIGN.md §14 already says it — one shared world per server, reputation and memory per player, gossip carries
player names — and Danzo confirmed the direction on 2026-09-18. Recorded here because part 1 previously carried
it as an open question. It is closed.

Why it matters beyond persistence: **"everything remembers" is hollow in a private copy.** The point of a shared
world is that the caravan you joined is the caravan someone else robbed, the village that trusts you is one
another player burned, and the guard who knows your face knows it because of something that actually happened
here. Participation and sharing are the same feature seen from two sides.

Not in v1, per §14: a single world across *all* servers. Roblox starts a second server when the first fills, and
that one loads the last save and diverges. Accepted, and worth revisiting when there are enough players for it to
matter.

---

## Part 1 — The world answers for itself

**What it is.** The living world stops being true only in the numbers and becomes true on screen. Three small
things, all of which make the parts after this one legible.

- **Predation you can see.** `Ecology.lua` already runs a real food web every in-game day: grass is grazed, deer
  and boar breed or starve, **wolves eat them and starve when the prey runs out**. But a wolf sprite standing
  next to a deer sprite ignores it, because `pickNpcTarget` in `Sim.lua` gives hunting behaviour only to hunters,
  guards and caravan guards. A wolf should hunt deer and boar the way a hunter does, and a kill near a player
  should decrement the region count so the visible layer and the abstract layer never disagree. This is pillar 1
  made watchable, and it is nearly free: wolves already know how to chase, telegraph and swing.
- **Everyone is a witness, and witnesses take sides.** This is the big one, and it is what Danzo actually asked
  for on 2026-09-18: *"different outcomes depending on who's doing what around whom."*

  Today there is no comparison anywhere in the code. One entity per tribe — the `guard` — reacts, and only to
  the player hitting one of their own (`Sim.lua`, `hitEntity`); everyone else in the village stands there. Guards
  attack bandits within five tiles unconditionally, whoever the bandit is fighting and whatever they think of the
  other party. Nobody else in the world ever intervenes in anything.

  Replace all of that with one rule applied by **every NPC who can see a fight**:

  > **Help the side you dislike less, if the gap is worth a fight. If you dislike both, watch. If you like both,
  > shout but do not swing.**

  Three inputs, all of which already exist: **what the witness thinks of each side** (per-tribe standing now,
  per-group memory after part 3, and tribe-to-tribe relations for NPC parties — hunters and plunderers are
  natural enemies per `ideas/INBOX.md`), **what the witness is** (a guard or hunter can fight; a villager,
  merchant or pregnant woman cannot), and **whose ground it is**.

  Four outcomes: **join in** on one side, **watch**, **flee**, or **raise the alarm** — an unarmed witness runs
  for the nearest armed person of their tribe, which is how a village that is not looking finds out.

  The situations this creates are the point, and none of them are written anywhere today:
  - Bandits chase you into a village that likes you → the guard *and* the hunters who are home turn out for you.
  - Bandits chase you into a village that is **wary** of you → they watch. You brought this here.
  - Someone the village hates jumps you while they are merely **neutral** about you → they help you anyway,
    because they hate the other one more. Standing is comparative, not a permission check.
  - You murder someone in the square of a village you are **family** in → they still turn on you. What they just
    watched outweighs what they thought this morning.
  - And it is not about the player at all: a band hitting a hunter squad near a farmer village, and the farmers
    deciding whether this is their business.

  Numbers to tune: how far a witness can see, how big the gap has to be before it is worth a fight, and a cap on
  how many join so a village does not all pile onto one wolf. Unarmed witnesses that flee still **carry what they
  saw** — which is the hook part 3 plugs straight into.

  This is also what makes part 4 mean anything. The moment you can ride with a band, "whose side are you on"
  stops being hypothetical, and every guard in the world already knows how to answer it.
- **Villages defend themselves.** A beast tide currently gets answered by one guard while everyone else flees.
  Hunters who are home should turn out, and a village should field defenders in proportion to its size tier.
  Villagers still flee — a farmer running is correct — but the village as a whole should not be a bystander.
  This falls out of the witness rule: a wolf is something everyone dislikes.

**Depends on:** nothing at all, which is why it goes first. It is also the only part of rung 3 a player can see
happening without being told, and the ground part 4 stands on.

**Done when:** stand still in a forest at night and watch a wolf take a deer. Get chased by bandits into a
village that likes you and watch four people turn out for you; do it again at a village that is wary of you and
watch them fold their arms. Kill a villager in a square where you are family, and watch the same people who
would have defended you come for you instead.

---

## Part 2 — Save and catch-up

**What it is.** The world and every player survive a server restart, and time keeps passing while nobody is
looking. Part 1 is the one thing that goes before it, because part 1 is small, visible and depends on nothing;
everything from part 3 on is worth less until this lands.

- A grudge that decays over years is meaningless in a world that forgets overnight.
- Tribute is a relationship over weeks, and there are no weeks.
- A caravan you are three days into is not a thing you can be three days into.
- DESIGN.md §16 is explicit: **do not charge for anything before save + catch-up lands.**

`Sim.state` is *shaped* for this — `day`, `tribes`, `people`, `regions`, `groups`, `players`, `camps`, `bags`,
`calamity` are all top-level tables, and entities are deliberately transient. But it is **not serialisable
today**, and saying so was wrong: `tribes[i].village` is a live reference to a `WorldGen` table, `regions` carry
derived fields, `calamity.flood` is a computed tile list, and a player record holds a `Player` Instance and a
function. `docs/ARCHITECTURE.md` is the plan that fixes it, and its step 1 is a prerequisite for this part
rather than a nice-to-have.

- **World save**: seed, day, tribe stock and population, the family registry, region ecology counts, group route
  positions, camps and bags. Versioned, written on a timer and on `BindToClose` (§14 says every 2 minutes).
- **Player save**: position, inventory, coin, reputation per tribe, rest point, `goalStage`. Keyed by UserId.
- **Catch-up**: on load, run the missed days through the daily tick at coarse steps — one per in-game hour,
  capped at four weeks (§14) — so caravans arrive, tribes breed, the ecosystem drifts. Players are not simulated
  while offline. Tell the player what changed: "You were gone eleven days. Kenstow has a new guard."
- **The data budget applies here first** (DESIGN.md §4). A person record carries only small fixed fields —
  parents, children, birth day, death day and cause, role, sex. Anything list-shaped, per-player or growing lives
  on the village, group or tribe, and the long dead are pruned to name, surname, death day and killer. That is
  what keeps the registry inside a 4 MB key, and it is a rule to build to from the first commit.

**Risks:** DataStore request budgets, 4 MB per key, writes on shutdown that do not finish.

**Done when:** stop the server mid-game, start it again, and your coin, your standing, your camp and the guard's
name are all still there, and the calendar moved on.

---

## Part 3 — Gossip and grudges

**What it is.** The pillar from DESIGN.md §7, and the reason this is not just another survival game. Reputation
today is instant and global: hit a hunter and every hunter in the world knows at once. That is a placeholder.
What §7 describes is information that has to **travel**.

**Decided 2026-09-23** (heavy session, handoff H1). The fork the routine session found — does `Reputation` stay
the stored truth with gossip feeding deltas, or become derived from per-holder memory — is answered **neither**:
reputation stays **stored**, but it is **re-keyed from tribe type to holder**. The rest of this section is the
spec to build; nothing below needs re-deriving.

### The decision, and why it is not "derived"

- **Derived-from-memory is unsound here, not merely expensive.** Memory has to be capped (§4's data budget), and a
  reputation recomputed from capped memory *heals when the cap evicts*. §7 wants the opposite: "you can be
  forgiven, but if you come back and do it again without ever making amends, they remember everything at once."
  A capped list cannot be a ledger. Memory is the **transport**; reputation and grudge are the **ledger**.
- **A ledger keyed by tribe type cannot express the thing part 3 is for.** `ps.rep` is keyed by `"farmer" |
  "hunter" | "plunderer"` today (`Reputation.START`), so the moment a hunter *squad on the road* learns something,
  `ps.rep.hunter` moves and their village knows too. The "done when" below is then impossible.
- So `ps.rep` is keyed by **holder**: `"v1" | "v2" | "v3"` for the three villages, and the group id
  (`"caravan" | "squad" | "band"`, already strings) for groups. A holder is *anything that can know something and
  can meet another holder*: a village or a group. 6 today, at most 43 at DESIGN §4's caps (40 groups + 3 villages).
- **`ps.rep` stays sparse.** `Gossip.standing(w, ps, holderKey)` falls back holder → that holder's village →
  `Reputation.START[tribeType]`, so a key only exists once that holder's opinion has actually *diverged*. A player
  who has only ever traded has three keys, not forty-three.
- **The read path does not change shape.** Every hot caller still reads one number out of one table by one key.
  There is no scan, no derivation and no cache anywhere in `Sides`, `Witness`, `Talk` or `Trade`.
  **`shared/Witness.lua` needs no edit at all** — `Witness.Party.rep` is already just "the number this witness
  holds", so part 1 survives untouched.

### The records

Three durable things. Nothing else is added.

**1. `ps.rep[holderKey]: number`** (player's own key) — unchanged in every way but its key. -100..100,
`Reputation.word`, `Reputation.fade`, the daily fade loop and `Restore.player`'s away-fade all work verbatim.

**2. `ps.grudge[tribeType]: number`** (player's own key, NEW, optional) — 0..`Gossip.GRUDGE_MAX`. The scar, and it
is **tribe-wide, not per holder**: a scar is what a people carry, and keying it per holder would let it dilute by
eviction. Damage multiplier: a negative delta becomes `delta * (1 + grudge)`.

**3. Holder memory**, on the records, at the tier the tier-rule puts it:

```
world
├─ rumours[]    NEW top-level node: a bounded ring of what is travelling
│               { id: number, about: number (UserId), event: string, victim: string?,
│                 victimPerson: number?, tribe: number?, day: number, hops: number,
│                 mult: number, aggressor: boolean?, fleeing: boolean? }
├─ villages[]   NEW node (ARCHITECTURE §2 reserved it for exactly this): { id: number, knows: {number} }
├─ groups{}     + knows: {number}
└─ meta         + nextRumourId: number
```

- A rumour stores **the event, not its consequences**: `Reputation.deltas(event, victim, tribeType, ctx)` is
  re-derived at the moment it is applied. That is R4, it is 117 B instead of 138 B, and it makes it impossible for
  a saved rumour to disagree with the rule.
- `mult` is the grudge multiplier **frozen at creation**: what you did is judged by the grudge you had when you did
  it, not by the grudge you have when the news lands days later.
- `knows[]` is a dense array of rumour ids — that is the per-holder memory, *and* it is the dedupe set:
  **appending to `knows` is what applies the rumour**, so no rumour can ever be booked twice at one holder.
- **Village memory goes on a `villages[]` node, not on the tribe row.** ARCHITECTURE §8.4 settled that villages
  are their own tier because rung 4 gives a tribe several of them, and "what this village heard" is not true of
  the whole tribe. This adds `State.state.villages` (`{ [i] = { id = i, knows = {} } }`); `tribeId` is derived
  from the tribe rows and is not stored.

### What travels and what does not

| Event | Behaviour | Why |
| --- | --- | --- |
| `kill`, `mercy`, `escape`, `gift` | a **rumour**: seeded at every witness holder, then carried | these are stories. §7: "they come home with a story, and a story is what gossip carries" |
| `hit`, `trade`, `rest`, `died_to` | **instant and local**: applied to the holders present, no rumour | a -1 slap and a two-coin trade are not news. It also keeps one long fight's blows from filling the ring |

**No witness, no rumour, no reputation change.** That is the feature ("you can outrun your reputation"), and it
has one consequence to build deliberately: when nobody saw a kill, `killEntity` passes **no killer name** to
`Families.die`, so the headline reads "Tam Ashdown of Kenstow was killed." with no "by". The tribe genuinely does
not know who. One line each way on the player's HUD — "Nobody saw that." / "Someone saw that." — is what makes the
whole mechanic legible; without it part 3 is invisible.

Witnesses are collected **in the loop `Sides.witnessed` already runs** (one sweep per blow, not two): every entity
within `Sides.WITNESS_RANGE` that is not an animal and not a baby, mapped through `Gossip.holderOf(e)` — its group
if it has one, else its village. A fleeing unarmed villager counts: part 1 promised they "carry what they saw",
and this is that hook. The victim counts too, if they lived.

### How it spreads

Two contact rules, both O(number of groups), both driven only by `gameSeconds`:

1. **Arrival.** `Tick.groupTurn` already fires exactly when a group reaches either end of its route, and `from`
   and `to` are stored — so the holder at that end is known without a search. The group and that village exchange
   every rumour neither has. This is the main channel and it is free: "a lone bandit tells his band when he gets
   home", the caravan arrives, the squad comes back.
2. **Meeting on the road.** When `math.floor(now / Gossip.EVERY)` increments, groups are bucketed by
   `math.floor(tile / 2)` of their current route tile and everything in a bucket exchanges. Bucketing makes it
   O(n), not O(n²) — a pairwise sweep at 1 Hz would be 13 million comparisons over a full catch-up.

An exchange is `Gossip.tell(w, ps, holder, id)` per rumour in the other holder's `knows`. Rumour rows are shared,
so `hops` lives on the row and means "how many exchanges this rumour has been through": it is incremented once per
successful `tell` that is not the seeding one. Strength is `Gossip.HOP_FADE ^ hops`, so the far tribe gets a
weaker, vaguer version — which is exactly the "done when".

### Does gossip spread during catch-up?

**Yes, and at the same granularity as live play**, which is the point. Movement stays 1 Hz (ARCHITECTURE §9's
"one stated granularity" — an hourly lump moves a group one leg where live ticking moves it eleven). Contact is
*not* a second movement granularity: it is a schedule computed from `gameSeconds` only, so `Tick.groups` run live
for n seconds and `Tick.catchUp(n)` produce the identical sequence of exchanges. A2's existing invariant test
("`catchUp(n)` equals n live steps of the same pure functions") is extended to cover `knows` and `rep`, and that
test is the guard against anyone lumping it later.

### Decay, and the four-week catch-up cap

Grudges "decay over years" and catch-up stops at four in-game weeks. There is no conflict, because **nothing
decays by ticking.** Reputation already proves the pattern: `Reputation.fade(v, days)` is a closed form, applied
once per day online and once by `day - lastSeenDay` on join (`Restore.player`). Grudge does the same with its own
half-life: `Config.GRUDGE_FADE_DAYS = 364` — one in-game year to halve, about 61 real hours of play.

The world that slept past the cap is not a special case either: `S.day` only advances by what was replayed, and
every decay is measured in **in-game days**. A world nobody plays does not age, and there is nothing to
reconcile. The rule, stated once: *anything that decays over a span longer than the catch-up cap is a closed form
over a day count, never a per-tick decrement.*

Rumour rows do not fade with age — only with hops (§7 says hops). Age decides **staleness**: a rumour older than
`Gossip.STALE_DAYS` leaves the ring at the daily tick. Old news stops travelling.

### The module layout

```
shared/Gossip.lua     NEW, pure, ~200 lines. The whole rule: holderOf, standing, witnessed, tell, contact,
                      exchange, grudge gain / amends / fade, the ring and its compaction. test:luau covers it.
shared/Reputation.lua unchanged except `newTable` takes the holder keys to seed. deltas/word/fade/clamp untouched.
shared/Tick.lua       + the two contact hooks (in groupTurn and on the EVERY schedule) and the stale drop in daily.
shared/Save.lua       + villages / rumours / knows / nextRumourId; VERSION 2 -> 3 with a real migrate step.
shared/Talk.lua       + Context.heard: what this village has heard about you, from its newest rumour.
server/Standing.lua   NEW adapter, ~120 lines. R2 already names `Standing` as the owner of "memory on villages and
                      groups, player rep, grudges". Sim's `applyRep` MOVES here.
server/Sides.lua      collects witness holders in the sweep it already runs; playerParty asks Standing.
server/Debug.lua      + a `gossip` command (the ring, and who knows what). Part 3 cannot be QA'd without it.
```

**`Sim.lua` must not grow.** It is 1282 lines against an allow-list ratchet of 1285 in `test/structure.test.js`
that *may only shrink* — three lines of headroom. This is why the adapter is a new module and why `applyRep` moves
out of Sim rather than growing there. Moving it buys headroom instead of spending it.

### The save step

**World key: `Save.VERSION` 2 → 3, with the first real in-place migration** (the v1→v2 comment asked for exactly
this: "The next format change should upgrade in place"). **Nothing is lost and no world is reset.**

```lua
if v == 2 then
    data.villages = {}                                -- one row per tribe row, from tribes[i].villageId
    for i, t in ipairs(data.tribes) do data.villages[i] = { id = t.villageId or i, knows = {} } end
    data.rumours, data.meta.nextRumourId = {}, 0
    for _, g in ipairs(data.groups) do g.knows = {} end
    data.meta.version = 3
    v = 3
end
```

A v2 world comes back with everybody having heard nothing yet, which is the correct starting state.
**Do not touch `WorldGen.GEN_VERSION`** — part 3 changes no map generation, and bumping it would discard the world
Danzo is playing (`Save.decode`'s genVersion check).

**Player key: `Save.PLAYER_VERSION` stays 1.** `Save.applyPlayer` *discards the whole record* on a version
mismatch (`if data.version ~= Save.PLAYER_VERSION then return nil, nil end`), so a bump would wipe every player's
coin, inventory and standing. `grudge` is therefore an **additive optional field** with an empty default, and the
`rep` re-key happens in `Restore.player` after `applyPlayer`: a key that is a tribe type is copied onto that
tribe's village holder, any other key is copied as-is. Lossless, no bump, and it runs once.

### The numbers, measured

Every figure below is `HttpService:JSONEncode`-equivalent bytes, counted by encoding the real records (three
tribes at their `Families.cap`, 36 regions, three full groups, a full headline ring):

| | bytes |
| --- | --- |
| the world key today (day 1 / day 30 / day 120 with 110 dead) | 15.7 K / 20.1 K / 32.0 K |
| one rumour row | **117 B** |
| gossip, today's 6 holders, ring full, **every holder knows every rumour** | **+9.6 K** |
| gossip, DESIGN §4's cap of 43 holders, ring 64, everybody knows everything | **+22.2 K** |
| gossip, realistic (6 rumours in flight) | +1.2 K |
| `ps.rep` re-keyed, all 46 holders diverged, in the player's own key | 449 B (40 B today) |
| for contrast: per-(holder, player) memory, 43 holders × 32 players × 3 entries | **216 K** — rejected |

So the worst case is about **1.4% of the 4 MB key**, and the decisive property is that **the ring does not grow
with the number of players**: 300 players make the same 64-row ring, where ARCHITECTURE §5's per-(holder, player)
shape was headed for 3.9 MB. §5's memory budget is superseded by these numbers.

`knows` never needs a cap of its own: a holder can know at most every rumour in the ring, and when the ring evicts
a row, `Gossip.push` compacts that id out of all 43 holders in the same call — so no dangling ids can reach
`Save.check`, and the bound is exact.

### Numbers to tune

`Gossip.MAX_RUMOURS = 64` (the same as `Headlines.MAX`, one number to remember) · `HOP_FADE = 0.75` ·
`STALE_DAYS = 14` · `EVERY = 60` game seconds (a tenth of an in-game day) · `GRUDGE_MAX = 3` · grudge gained: 0.5
for murder of a runner, 0.3 for any other killing of a person, 0.2 for a bandit · `GRUDGE_GROUP = 0.25` (the share
that lands on you for harm done while riding with a group — §7's "spreads thin"; dormant until part 4 passes
`ctx.withGroup`) · `AMEND_GIFT = 0.1` per gift · `Config.GRUDGE_FADE_DAYS = 364`.

### What this costs in edits

`ps.rep` is touched at 28 places across six server files. Four need nothing: the two fade loops
(`Sim.lua:1148`, `Restore.lua:63`) work verbatim on holder keys, `Sim.lua:1159` is `Reputation.newTable`, and
`State.lua:109` becomes the three-key aggregate. **The other 24 are mechanical**, and each resolves to one of
three calls:

- `Standing.at(ps, holderKey)` — where an *entity* has the opinion: `Sides.lua:58`, `Interact.lua:105,165`,
  `Sim.lua:804`.
- `Standing.tribe(ps, tribeIdx)` — the tribe's seat, i.e. its village: `Interact.lua:51,57,89,98,139,285`,
  `Sim.lua:572,575`, `Restore.lua:71`, `Debug.lua:75,77`.
- `Standing.apply(ps, holderKey, deltas)` — every write: `Interact.lua:146,171,300,312,323`,
  `Sim.lua:407-411` (the body of `applyRep`, which moves into `Standing`), `436,549,596,708,747`.

**The wire format does not change and the client is not touched.** `State.hud` sends the same three-key
`{ farmer, hunter, plunderer }` it sends today, built from the three village holders — which is what
`Hud.toggleStanding` (`Hud.lua:986-996`) and `Client.client.lua:105` already expect.
Two assertions in `test/luau/sim.test.luau:54-55` are about `Reputation.newTable()`'s keys and must be **updated,
not removed**: the new assertion is that every holder key is seeded from its tribe type's `START`.

**Depends on:** part 2 (a grudge that resets nightly is not a grudge) and track-b1's named group members (a rumour
about a person needs that person to still be the same person).

**Not in part 3.** `tribes[].news` is **not deleted**. `docs/qa/track-b1-summary.md:58` says "gossip replaces
news", and what it replaces is the *sticky-single-string pattern* for things said about the player. `news` keeps
its real job — the village's own family news, read by `Talk.Context.familyNews` — and gossip is a second,
separate channel (`Context.heard`). Collapsing the two is a job for part 7's full talk system.
Also not in part 3: the ledger key becoming the **village id** rather than one holder key per village. Today
village ↔ tribe type is 1:1, so "the village knows, the tribe does not" is not observable until rung 4 gives a
tribe several villages; when it does, that is a change of key inside `Gossip.standing`'s fallback chain and
nothing else.

**Done when:**

- `npm run test:luau` passes a new `test/luau/gossip.test.luau`: a rumour seeded at the squad does not move the
  hunter village's number, and does after one contact — **once**, and not again on the next contact; strength
  falls with hops; a holder never applies a rumour twice, including across a ring eviction and compaction; grudge
  multiplies the next kill and a gift reduces it; grudge halves in `GRUDGE_FADE_DAYS`; `catchUp(n)` equals n live
  seconds *including* every exchange; and the worst case above is asserted in bytes, so a future shape change has
  to argue with a number.
- `npm test` passes `save.test.luau`: `Save.check(encode)` with the gossip nodes, `decode(encode)` deep-equal, and
  a v2 fixture migrating in place with every group and village getting an empty `knows` and nothing else changed.
- In Studio: kill a hunter where exactly one person sees it, walk the other way, and watch the news reach their
  village over the next in-game day — and reach the far tribe later still, weaker and vaguer. Kill one where
  nobody at all sees it, and watch nothing happen, to you or to the headline. Then go back and do it again, and
  watch the grudge make the second one cost far more than the first.

---

## Part 4 — Belonging: party up, ride along, join

**What it is.** The rule above the others, built. This turns the player from a visitor into a participant, and it
is the biggest single win available in rung 3.

The machinery already exists, which is the whole reason it is affordable. A group in `Sim.lua` is a record with
`members`, a route, a position along it, and a rule for materialising into entities when a player is near. **A
player joining a group is the player becoming one of its members.** Same record, same route, same rules.

- **Ride with a caravan.** Ask the caravan master — a role that already exists and already talks about trade and
  standing. While you travel with it you walk its route, bandits that hit the caravan hit you, you take a share
  of the profit when it arrives, and your standing moves at **both** endpoint villages. Leave halfway if you
  like; pillar 5 says the world lets you, and the master remembers that you did.
- **Hunt with a squad.** Ask at the hunter village. You walk out with four hunters, kills are shared, and running
  from a fight is remembered by four witnesses who will be home tonight (part 3 carries it).
- **Ride with a band.** The plunderers. DESIGN.md §7 already anticipates exactly this — *"harm done as part of a
  group (you rode with a bandit band) spreads the grudge across the group: small"* — so the consequence model is
  written and only the joining is missing. Settled tribes' standing falls, plunderer standing rises, and guards
  who see you with the band treat you as one of them (part 2 is what makes that work).
- **One system, three flavours.** Not three features. A group is a group; what differs is who will have you and
  what it costs you elsewhere. That is the systems-in-systems test passed: an NPC does this today, under the same
  rules, with the same data.
- **How you join is a conversation, not a menu.** You ask a person, they say yes or no based on what they think
  of you, and you walk with them. No party UI, no gold, no confirm button.

**Depends on:** part 1 (so the world can notice whose side you are on) and part 3 (so it travels). Buildable
without part 3, but riding with a band is only interesting once word gets out.

**Done when:** you walk Glenworth to Kenstow as a caravan guard, get ambushed on the road, and arrive to find the
village thinks better of you than it did this morning — while a player who rode with the band instead finds the
gate shut.

---

## Part 5 — Tribute, tax and extortion

**What it is.** The tribes stop being scenery and start wanting things from you. `ideas/INBOX.md` describes this
at length and none of it exists yet.

- Size tiers (small, mid, large) per tribe, driving how much of everything they do.
- **A `chief` role.** DESIGN.md §19 recommends part 3 for it and the reasoning holds: tribute needs a face to
  make the demand, "who do I pay" has to be answerable by pointing at a person, and §13's succession arc needs a
  chief to exist before rung 4 can take one's place. One more role reading the village bank that guards and
  merchants already read.
- Plunderer tribes demand tribute from villages in their territory, and from the player once they have anything
  worth taking. Large bands extort rather than destroy: they want a paying neighbour, not a ruin.
- Farmer tribes collect tax from smaller villages in their territory and send caravans from the strongest.
- Pay, refuse, or fight — each remembered by part 3's machinery. And per part 4, you can be on the collecting
  side of any of it.

**Depends on:** part 3.

---

## Part 6 — Hunger, and the second axis on goods

DESIGN.md §11 parks hunger with a condition: **"if it makes the food economy matter"**. It only does once there
is something to spend food on and something to lose by running out. After parts 2, 4 and 5 there is: a caravan to
supply, tribute to pay, and a long walk that persists across sessions.

It is also the cheapest answer to §19's **"do goods get a second axis?"** — goods are pure sell-value today,
which principle 2 correctly calls the flattest part of the game. Food that feeds a village, matters in a drought
and can be demanded as tribute is a second axis on a good that already exists. **Not a crafting tree.**

---

## Part 7 — The rest

Ordered by how much each adds per day of work:

- Blizzard and drought (the calamity machinery already takes a `kind`).
- The full talk system: every role answers topics, and roles get replaced when their holder dies.
- **The elder's "what now"** — see the urgent note at the bottom; it should not wait this long.
- Knights and adventurers, and hiring them (as participation, never as a menu — see below).
- Dash on double-tap, shield block, bows for hunters.
- Settlement healing and ruins.

---

## What is deliberately not in rung 3

**Hirelings and city building.** Principle 2 says the composable entity in Lowlands is a named person, and
DESIGN.md §13 works out why: a hireling sits in the family tree, the gossip network, their birth tribe, combat
and labour at once. That is the biggest multiplication available to this game, and it is rung 4 — partly because
it wants parts 1 to 5 underneath it, and partly because building it before gossip exists would make it a menu
that spends coin.

**When it is built, it is part 4's machinery again**, not a new system: hiring is asking a named person who has
an opinion of you, their relatives have an opinion about how you use them, and building a village is people
working, not a progress bar. Danzo was explicit about this on 2026-09-18, and it is written here so nobody builds
a shop screen in rung 4.

**Interiors and elevation.** Real elevation touches every routing call in the game and the wire format; interiors
want to be sub-maps rather than a height axis. Both rung 4. **Fake height** — taller sprites on their own draw
layer, cliff edges, drop shadows — changes no server code at all and could be slipped in any week it is wanted
(DESIGN.md §19).

---

## Suggested order, and why

1. **The world answers for itself** — depends on nothing, is the only part anyone can *see*, and it is the
   ground part 4 stands on. Danzo put it first on 2026-09-18, ahead of persistence, and he is right: it is an
   afternoon's work against weeks of invisible plumbing, and it makes every later part legible.
2. **Save and catch-up** — gates everything from part 3 on, and is the least fun, so it goes before them.
3. **Gossip and grudges** — the pillar; the reason to play.
4. **Belonging** — the player stops being a visitor. The biggest win in the rung.
5. **Tribute, tax, extortion** — the tribes come to you, and you can be on either side of it.
6. **Hunger** — small, and only earns its place after 5.
7. **The rest** — content, in whatever order looks most fun.

Publishing free happens before all of it (rung 2 part 5), because real players will change what is on this list.

---

## The one thing principle 1 changes

Rung 2 part 4 gave the game a goal line and **retired it for good at the first calamity** — about seventy real
minutes in. That was right for what it was: scaffolding for the first minute. But principle 1 names two moments a
compass exists for, and we built only one:

- the **first minute**, which the survivor and the goal line handle; and
- the **lost minute at hour twenty**, where open worlds actually lose people, and which is invisible in a
  thirty-minute playtest.

Nothing replaces the goal line when it retires. A player who gets past day 7 has no direction at all. DESIGN.md
§12 already specifies the fix — **the elder answers "what now"**, from where the player actually stands, as a
topic on a role that already exists reading a bank that already exists — and §19 prices it at about half a day.

Danzo dropped the rush to publish on 2026-09-18, so this is no longer a race against strangers arriving. It is
still the only answer to the hour-twenty lost minute, and it is still half a day. **Fold it in wherever it is
convenient** — it rides along with almost anything, and it gets more to say with every part above. Note it is a
*person* answering, who can be wrong, biased, far away or dead; never a quest log.
