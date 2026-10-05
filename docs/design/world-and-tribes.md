# Design §4–§6: the world is numbers, tribes, trade

Part of [`docs/DESIGN.md`](../DESIGN.md), which maps every § to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of DESIGN.md, wherever it now lives.

## 4. The world is numbers; the grid is a window

The server runs an **abstract simulation**. Nothing in it is a sprite:

- **Tribe**: type (farmer / hunter / plunderer), size tier (small / mid / large), home village, stockpile,
  relations with every other tribe, reputation and grudge with every player, list of active groups.
- **Group**: kind (caravan, hunter squad, bandit band, patrol, hunting party), owning tribe, position on the
  map, route, members (named, with strength), cargo, **gossip table**.
- **Village**: tribe, footprint tiles, buildings, walls, stock, tax/tribute ledger, **knowledge bank**.
- **Region** (the map is cut into 16x16-tile regions): biome, owner tribe (or none), grass health, wildlife
  populations as counts (deer, boar, wolf, ...), last calamity effects.
- **Player**: position, hp, inventory, rest point, reputation and grudge per tribe, memories other NPCs hold.

Clients only see what is near them. When a group's position comes within view of a player, the server
materialises it as individual NPC sprites; when nobody is near, it collapses back into a record. Wildlife
individuals are spawned near players from the region's counts and folded back into counts when they leave.
This is how RimWorld, Dwarf Fortress and Mount & Blade keep a whole world alive cheaply.

**Territory**: each region is owned by the tribe of the nearest village within influence range, or by nobody.
Patrols, tax, tribute and "you are in bandit land" all hang off region ownership.

Tick rates: movement 10 Hz for things near players; world sim 1 Hz; economy, breeding and migration once per
in-game day.

**Caps (tunable, first guesses)**: 40 groups alive on the map; 60 NPC sprites and 40 animal sprites
materialised across all players at once; a client renders only its viewport plus a 2-tile margin (20x16 tiles).
If a cap is hit, the furthest-from-any-player things stay abstract.

**Data budget** (Danzo asked it straight, 2026-09-18: "what the fuck is a little bit of data, an extra array?").
Mostly he is right, and the answer differs by what you hang it on:

- **Per tribe, per village, per region, per role: free.** There are a couple of dozen of each, forever. A new
  list, tree or table there costs nothing and never grows on its own. Hang things here by default.
- **Per group: nearly free.** Capped at 40 alive (above), so a gossip table per group is affordable by design.
- **Per person: the one to watch.** The family registry grows with every birth and never shrinks, and
  `docs/RUNG3.md` part 2 already names it as the table most likely to outgrow a 4 MB DataStore key. Per-person
  cost also multiplies by every player who has an opinion attached.

So the rule: **a person record carries only small fixed fields** (parents, children, birth day, death day and
cause, role, sex). Anything list-shaped, per-player, or growing lives on the village, group or tribe. Memory of
what a player did belongs to the place and the party, never to each villager separately, which is what §7 wants
anyway: gossip travels by caravans and bands, not by a thousand independent diaries. And the long dead get
pruned to name, surname, death day and killer.

## 5. Tribes

Three archetypes. Every tribe has a size tier that scales what it does. (Written up from Danzo's notes in
`ideas/INBOX.md`; the notes remain the flavour reference.)

### Farmers: strength is coordination and numbers
- Peaceful by default. Trade with anyone whose relationship allows it, including plunderers.
- Pay **tribute** to plunderers for protection against other plunderers or wildlife.
- Send **caravans** to trade with other villages and return home with goods. Only mid tribes with the most
  resources and every large tribe run caravans; small tribes never do. Large tribes run large processions.
- Spawn **merchants** in their villages and **knights** (peacekeepers) in their territory; more with size.
- Large tribes fortify: walls, gates. They collect **tax** from smaller villages in their territory and want to
  expand because they have many mouths to feed. They are the most "civilised" and the most numerous.
- Many mid-strength fighters, defensively minded, timid on the road: the goal is to get the goods home.
- If a player is known to harm people frequently, prices go up and eventually trade closes.

### Hunter-gatherers: strength is individual skill and squad chemistry
- Even temper. Will fight, not aggressive. Trade happens but is not their focus.
- Natural enemies of plunderers, because their small squads are what bandits ambush.
- Go out in **squads of 4 to 5** on short trips (a week or two), kill, come home. Strongest fighters one on one.
- Spawn **hunters** and **adventurers / adventurer groups** who can be **hired** by merchants and caravans.
  Stronger tribes produce stronger groups.
- No tax, no tribute. Large tribes can send **hunting parties** of several squads to deal with dangerous
  wildlife, or to attack a plunderer village if the relationship is bad enough.

### Plunderers: strength is sudden brutality
- Kill and take. Guerrilla tactics. Weakest tribe type in a fair fight, so they avoid fair fights.
- Raid caravans; hesitant to hit big caravans unless the tribe is large, or they think they can win, or the
  situation forces it, or they particularly hate the target.
- Also trade, with each other and with the player, if they don't want to kill you on sight.
- Spawn **bandit groups and thieves** roaming their territory; more with size.
- Small and mid tribes prefer caravans of mid-sized tribes over villages. Large tribes prefer villages, rule
  their territory and make the tribes inside it pay **tribute**. They don't destroy nearby villages outright
  (that kills the income) and often **extort** caravans instead of plundering them, because turning every big
  tribe against them is bad business.

### Size tiers (first pass numbers, tune in play)

| Tier | Villages | Population | Groups out at once | Notes |
| --- | --- | --- | --- | --- |
| small | 1 | 10 to 20 | 1 | no caravans, no walls |
| mid | 1 to 2 | 30 to 60 | 2 to 3 | farmer: caravans only if richest; plunderer: hits mid caravans |
| large | 3+ | 100+ | 4 to 6 | walls, tax/tribute, big processions, hunting parties |

### Settlements heal too
A village that takes losses rebuilds over weeks if any of its people survive. A village wiped out entirely
becomes a **ruin**; survivors join the nearest friendly village, and after a while a migrant group resettles the
ruin as a new small tribe (type weighted by the neighbours). A tribe's population regrows slowly toward its tier.

## 6. Trade, tribute, tax

- Goods for v1: **food, hides, tools, ore**. Each tribe type overproduces one and needs another (farmers make
  food, hunters make hides, plunderers "make" whatever they stole and always need food).
- Coin exists as the convenience currency; barter is always allowed.
- Prices are per village, move with stock, and get a multiplier from the player's reputation there.
- **Tribute**: weaker tribe pays a stronger plunderer tribe a share of stock per week to be left alone.
- **Tax**: large farmer tribes take a share from small villages in their territory.
- **Extortion**: a plunderer group meeting a caravan may demand a cut instead of fighting. Caravans accept
  based on strength comparison and how much they carry.
- The player trades through the interact prompt at a merchant or a group leader.
