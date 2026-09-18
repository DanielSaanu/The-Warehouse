# Design: Lowlands

A 2D top-down pixel-art Roblox game about surviving in a living overworld. Tribes trade, raid and remember you.
Wildlife breeds and starves without you. The world is shared by everyone on the server and keeps living while
you are away. "Rain World energy" on a tile grid.

Source of truth for gameplay decisions. `ideas/INBOX.md` is the scratchpad; things that get agreed move here.

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
  `docs/RUNG3.md` part 1 already names it as the table most likely to outgrow a 4 MB DataStore key. Per-person
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

## 7. Reputation, grudges, gossip

Two numbers per (tribe, player), plus what individuals remember.

- **Reputation** is the current feeling, from hostile to family. It moves on events: trade, gifts, killing
  their people, protecting their caravan, paying tribute, freeing captives. It **fades toward neutral**: half
  the distance every in-game month, so a new player who blundered can come back.
- **Reputation is a record of your conduct, never of your luck** (Danzo, 2026-09-17). The rules, in order:
  - Who drew first is the story. Hitting someone who attacked you costs nothing; killing someone who attacked
    you costs half. Hitting someone who never touched you costs a little (-1 a blow); killing them costs the big
    number (villager -25, guard or hunter -20, bandit -15 with the plunderers and +5 with the settled tribes).
  - Beating someone and letting them go is worth more than killing them: when a broken fighter gets away from
    you, +3 with their tribe, once per fight. They come home with a story, and a story is what gossip carries.
  - Killing someone who is running from you is murder: the full kill penalty, plus a grudge in rung 3.
  - Being killed costs nothing. Dying never feeds a grudge and never stacks, however many times the same band
    kills you. Being murdered is their doing, not yours.
  - If the band chases you and loses you, +2 with the plunderers: they respect what they could not catch.
    Nothing for escaping guards or wolves.
- **Grudge** is the scar. It only comes from serious harm, decays very slowly (years), and it **multiplies**
  the damage of any new bad act against the same people: reputation damage = base x (1 + grudge). So you can be
  forgiven, but if you come back and do it again without ever making amends, they remember everything at once.
  This is what stops farming the same village for loot.
  - Harm done as **part of a group** (you rode with a bandit band) spreads the grudge across the group: small.
  - The same harm done **alone** lands entirely on you: near irreconcilable. "Don't let me recognise you."
  - **Amends** (big gifts, paying what you took back, doing a job for them) reduce grudge. Time alone barely does.
- **Memory** is per NPC group / village: what they personally saw you do, with a timestamp.
- **Gossip**: when two groups (or a group and a village) are on the same or adjacent tile, they exchange
  memories about players. Each hop loses detail and weight. Caravans are the big spreaders. A lone bandit tells
  his band when he gets home. Hunter squads tell the caravan they are guarding. Information really has to travel,
  so you can outrun your reputation for a while, and a tribe on the far side of the map may not know you yet.
- Harming someone from a large farmer tribe hurts you with their friends and family first, then their village,
  then the tribe, as the news spreads.

## 8. Talking: how the player learns anything

Reputation, gossip and the ecosystem are invisible numbers unless the game shows them. The game shows them by
**talking**, not by menus.

- Each village and each group has a **knowledge bank**: facts about the area (wildlife, who is raiding whom,
  prices, the calamity forecast) plus what they know about you.
- F on a **regular villager** gives one random line from the bank. Flavour and rumours.
- **Role NPCs** hold the vital stuff and open a **multiple-choice window** (Ask about the road / the tribes /
  prices / me). Roles: village **guard** (survival basics and what's dangerous nearby), **caravan master**
  (trade and standing), **merchant** (prices, what's scarce), **elder** (tribe politics, grudges).
  Examples of the tone:
  - Guard: "There are bandits afoot because of the plunderers in the north. Head that way, don't start trouble."
  - Caravan master: "Get close with the villages round here and they'll cut you a deal. Get on their bad side
    and they won't trade at all. Or worse."
- Role NPCs are **named people**. If one dies, another villager takes the role, preferably a relative (same
  last name). The knowledge bank belongs to the village, not the person, so the role carries on.
- **Names identify people; roles decide what they can tell you.** A guard knows guard things (danger, the road,
  who was seen where), a merchant prices and scarcity, a caravan master trade and standing, an elder or priest
  (later) the tribe's politics, grudges and the long arc: story beats, tutorial beats, player events. Each role
  reads its own slice of the village bank, and the bank holds only what has happened here or what gossip has
  carried here. Far villages know less about you, and about the world, than near ones.
- NPCs that are hostile to you won't talk. That is itself information.
- A standing screen on a key shows your reputation per tribe as words, not numbers ("wary", "welcome").

## 9. Wildlife, ecosystem, migration

- Per region: counts of **grass health**, **deer**, **boar**, **wolf** (v1; add more later).
- Daily tick per region: herbivores eat grass and breed if fed; predators eat herbivores and breed if fed;
  starving populations shrink; small migration between neighbouring regions.
- **The borders are a void that breathes.** Animals migrate across the map edges in both directions, with a
  general north-south flow: wolves push in from the north, deer drift south ahead of them, boar fill what the
  deer leave, and so on. This reshuffles populations and keeps the world stable-ish without anything being
  scripted. Kill every wolf in a region and the north refills it in a few weeks; the deer boom in between is real.
- Players kill individuals, which decrements the region count. Kill every wolf and the deer explode and strip the
  grass; strip the grass and the deer starve; burn a forest (later) and the region loses habitat.
- Hunters hunt from these counts too, so hunter tribes are part of the ecosystem, not outside it.
- The **ratio of wildlife you see** is the live state of the numbers. That is the whole "it should show".
- **Player strength is fixed** on purpose: the ecosystem is balanced against a known player, not a level 40 one.

## 10. Time, night, calamities

- Day = 10 real minutes: 7 day, 3 night. Night: lower visibility, wolves out, campfire radius matters.
- Week = 70 minutes. Once per in-game week, one calamity, chosen with weights by season (later):
  - **Flood**: rivers spill, low tiles become water for the day, caravans stop, food stocks damaged.
  - **Beast tide**: wolves pour in from the north and roam by day everywhere (the north worst, every region some),
    villages take losses unless walled or defended.
  - **Blizzard**: movement halved, no farming, animals shelter, cold damage outside a village.
  - **Drought**: grass health drops, herbivores starve, food prices spike, tribute demands rise.
- Warning signs the day before (sky tint, NPC dialogue line), so shelter is a choice you make.
- This replaces the 90-second rain timer in the current prototype.

## 11. Player, controls, combat

- Move: WASD / arrows, real-time tile steps. Touch: swipe direction or a d-pad (later).
- Attack: left mouse button. Strikes the adjacent tile in the facing direction. Weapons change damage and reach.
- **Combat feel (rung 2)**: attack cooldown, hit flash, one-tile knockback, short invulnerability after being
  hit, enemies telegraph for a beat before they swing. Bows for hunters later.
- **Fights end in flight, not always in death.** Every fighter has a break point and runs for home or for its
  group when it is reached, and stops fighting unless chased: bandits at 40% health (guerrillas avoid a fair
  fight), boar and wolves at 30% (a pack retreats), guards at 25% (they are defending home), hunters at 20%
  (the best fighters one on one). Villagers and merchants run at the first blow, deer at the first sight of you.
  A runner that reaches home heals over a day. Surrender in words is a talk-system feature (rung 3); for now
  running is the surrender. The point: a fight that always ends in death leaves no witnesses, and witnesses are
  what "everything remembers" is made of.
- **Later**: dash on double-tap Space; block by holding right mouse with a shield equipped.
- Interact: F. A prompt ("F: Trade", "F: Talk", "F: Pick up", "F: Rest", "F: Camp") appears when adjacent to
  something interactable. Only one prompt at a time, the nearest.
- Stats: hp, attack, defence, speed. NPCs use the same stats, so the "hunters are strongest individually" rule
  is just numbers. The player's base stats never change; gear changes them.
- **Tall grass** hides you: detection radius drops while you stand in it. Plunderers use it, so can you.
- Day one kit: knife (weak weapon, also skins animals), waterskin, 2 food, and one **camper set** (bedroll +
  flint). It is what a person grabs when their village gets plundered.
- Camp: F on a free tile outside a village **uses up** a camper set and places a camp (bedroll + campfire).
  Single use: it cannot be packed back up. Resting at it sets your spawn point. The fire keeps wildlife off a small
  radius at night while it burns (a few in-game hours), then it goes out; the bedroll stays as your spawn point
  until bandits, a beast tide or a flood destroy it. Placing a new camp abandons the old one. More camper sets are
  bought from farmer and hunter merchants, or taken from bandits who took them from someone else. This is the
  first thing that gives you a reason to earn coin. Later: cook at the fire.
- Rest in a village: F at a bed to set your spawn point. Villages whose tribe is **hostile** to you refuse
  ("They won't let you stay"). Neutral and better allow it. Village rest is the safe option; the camp is the free one.
  The plundered starting village is your first rest point automatically.
- Death: respawn where you last rested, village bed or camp. If a camp was destroyed, or a village has since turned hostile
  (you did something, or gossip caught up), you wake at the nearest village that still allows you, and the game tells you why.
  Inventory dropped where you fell in a bag only you can see for 10 minutes, then anyone. A flat reputation hit
  with the tribe you died fighting, and only that: dying never adds a grudge and never stacks, however many times
  the same band kills you. Being murdered is their doing, not yours.
- Hunger comes in rung 3 if it makes the food economy matter; not in v1.

## 12. The first five minutes

You wake in your village the morning after the plunder. Huts are burnt, a few people are left. One survivor
(a named relative) is the only prompt: F to talk. They teach the three controls in three lines, tell you the
bandits came from the north, and point you down the road to the hunter village for help. The road is clear and
straightforward; one encounter happens on it (a deer to hunt, or a wounded caravan guard to talk to, picked so
the player learns one more thing). No quest log. Just a person who told you where to go.

### After the first job: the elder is the compass (2026-09-18)

Rung 2 part 4 added a visible first job — one line under the clock, five steps, retired for good at the first
calamity. That line is pillar 6 in miniature, and retiring it was right: it is scaffolding for the first minute.
But nothing replaces it, and **the lost minute at hour twenty is the one that loses players**. What replaces it:

- **Ask the elder "what now".** A topic on the elder's multiple-choice window (§8) that answers with the next
  step of the long arc, chosen from where the player actually stands: what they own, who trusts them, what they
  have not seen. "You have coin and no roof. Kenstow would sell you a hut if you were worth more to them."
- It reads the village's knowledge bank like every other topic, so **a far elder gives worse advice than a near
  one**, an elder who dislikes you gives grudging advice, and an elder who is dead gives none until the role is
  taken up again. The compass is a person and can be wrong, biased or absent. That is the feature.
- It never opens a quest log, never adds a marker, never blocks anything, and it is happy to tell you that you
  have already done the thing it was going to suggest (principle 1.5 in `docs/PRINCIPLES.md`: a step completed
  by accident is the proof it is guidance).
- Cheap: it is one more topic on a role that already exists, reading a bank that already exists. Lands naturally
  with the chief role and the full talk system in rung 3.

## 13. The long arc: becoming a power

Everything a tribe can do, the player can eventually **initiate and take part in**, from a chosen **true home**:
the plundered starting village or any village that comes to trust you.

- **Hire villagers to build** (huts, walls, a market, a gate). Reputation and coin gate what they'll build for you.
- **Raise groups**: fund a caravan, hire a hunter squad, lead a raid. Their success feeds your village's stock
  and standing, and their losses are yours.
- **Politics**: pay or demand tribute, tax villages in your territory, make peace or war between tribes.
- **Take over places**: absorb a ruin, seat your people in a captured village, expand your territory.
- Multiplayer: several players can build the same home village up together, or build rivals.
- The endgame is a world superpower that you built, in a world that will still push back.

### Hirelings, not gear, are the composable thing (2026-09-18)

Measured against principle 2 in `docs/PRINCIPLES.md`, Lowlands is already systems-shaped in the world and
content-shaped in the player's hands, and it is worth being honest about which is which before rung 4:

- **Already multiplying.** A person sits in the family tree, the gossip network, a role, and a tribe's
  population at once — harm one and four systems answer. Wildlife counts feed ecology, which feeds tribe food,
  which feeds caravans, which feeds prices, which feeds what a raid is worth stealing. These are real edges and
  they were free, because everything is a record in §4.
- **Not multiplying.** Goods are sell-value and nothing else. The 10-slot inventory is things you carry to a
  merchant. No levels is right (pillar 4), but nothing in the player's own kit *composes* with anything —
  it is the flattest part of the game.

The fix is not to bolt a crafting tree on. It is to notice that **the game's Pal-shaped entity is a named
person**, and the data for it already exists:

- A hireling is in the family tree (their relatives have an opinion about how you use them), the gossip network
  (they tell people what they saw you do, which makes betraying your own hires expensive), their birth tribe
  (hiring shifts standing on both sides), combat (strength, and who they will not fight), and labour (build,
  carry, guard, farm, hunt). **One entity, five systems, no new subsystems required.**
- That makes §13's "hire villagers to build" and "fund a caravan" the same mechanic wearing two hats, and it
  makes a roster of people the progression that replaces levels and gear.
- Orthogonal axes to give a person, added slowly (principle 2's cost note): what they are **good at**, what
  they **will not do**, who they are **related to**, and who they have **told about you**. Four axes, all of
  which already have data behind them.

Rung 4 work. Written down now so hiring is not built as a menu that spends coin.

### Chiefs, heirs, and taking a tribe (Danzo, 2026-09-18)

The kingdom end of the arc runs on the family registry from §15, so most of it is a lookup rather than a system.

- Every tribe has a **chief**: a named person, a role NPC like the guard or the elder (§8). The registry already
  knows their children, siblings and surname, so "who is next" needs no new data.
- **Killing the chief does not end the tribe.** It is the tempting version and it is the wrong one: a world that
  loses a tribe every time you win gets emptier the more you play, which is the exact opposite of pillar 5. What
  happens instead:
  - the registry names an **heir**: eldest adult child, else a sibling, else the strongest surviving squad or
    caravan leader;
  - with no clear heir and a violent death, the tribe **drops a size tier** — fewer groups out, caravans stop,
    walls go unmanned;
  - with two equal claimants it **splinters**: the loser walks out with a share of the people and founds a new
    small tribe of the same type. That is where new small tribes come from, besides resettled ruins (§5);
  - and the tribe carries a **grudge at tribe level, for years**. Killing a chief is the largest single grudge
    in the game, and §7 makes sure the far side of the map hears about it eventually.
- **Two roads to a throne, both legitimate.** Take it by force and hold it, or earn standing with the chief
  until they hand it over: kin by marriage, regent while an heir is a child, chief by acclamation where there is
  no heir at all. The slow road leaves you a tribe that still works; the fast one leaves you a tribe that is
  afraid of you and neighbours who all know. Pillar 5 says both roads stay open, and neither is the "good end".
- A player holding a tribe inherits what tribes already do in §6: groups to send out, tribute to collect from the
  villages in the territory, tax, war and peace with the neighbours. Section 13's "become a power" is then not
  new machinery at all — it is the tribe systems already built, pointed at a player.

This is rungs 4 and 5; the data model in section 4 is shaped for it from the start.

## 14. Persistence and multiplayer

- One shared world per server. Reputation, grudge and memory are per player. Gossip carries player names.
- No PvP damage for now. Tribes judge players individually: one player's massacre is that player's problem.
- The world state (tribes, groups, villages, regions, calamity clock) is saved to DataStore every 2 minutes and
  on server shutdown. Player state is saved separately on leave.
- **Catch-up**: on load, the server runs the simulation for the missed time at coarse steps (one step per
  in-game hour, capped at 4 weeks), so caravans arrive, tribes breed, the ecosystem drifts. Players are not
  simulated while offline.
- If two servers run the same world (Roblox can start a second server when the first is full), the second loads
  the last save and diverges. v1 accepts this. Later: one world per server slot.

## 15. Names

Every entity gets a random first name and last name: NPCs, players' NPC relatives, animals that get notable
(the wolf that ate your caravan), villages and tribes (from a different generator). Children born in the
simulation keep the father's last name, so a family you wronged stays recognisable across generations. Names are
how gossip refers to people and how grudges stay attached to someone.

**Families (from rung 2).** Every person is a record with parents, children, birth day and, when it comes,
death day and cause (who, or what). That is the family tree, and it is the spine of grudges and gossip later:
"you killed my father" is a lookup. The human clock runs on the in-game calendar and is much slower than the
beasts', which breed on the daily ecology tick:
- Three stages, no in-betweens, one sprite each (Danzo, 2026-09-17): a **pregnant** woman (her own sprite) for
  one in-game week (70 real minutes), then a **baby** (its own sprite, it stays where it is put, by the parents'
  hut) for two weeks, then an **adult** villager (the sprite that exists). Villagers carry a sex; there is no
  separate adult woman sprite yet.
- A village with room under its visible cap (9 named people) and at least one couple conceives about once an
  in-game week. The baby takes the father's surname and its own first name. Killing a baby or a pregnant woman is
  the worst thing you can do to a village (-40).
- Couples form between two unrelated adults of the same village; widows and widowers may re-pair after a month.
- Villages lose people to fights, calamities and (later) raids; they refill by births, not by respawning, so a
  village you emptied stays empty for weeks and its neighbours notice. This is what keeps the population loop
  from becoming murder, respawn, repeat.
- Ideas box: villagers are named, but their roles are what the world sees. See §8.

## 16. Build rungs

Rung 1 is done (grid, movement, one room, rain timer, upload pipeline).

**Rung 2, next: a small living world**
- Scrolling camera; 96x96 map from a seed: meadow, tall grass, forest, river, cave mouths, dirt paths.
- Three villages (farmer, hunter, plunderer; all mid), huts, one wall segment for the farmers. Named.
- Player starts in the plundered farmer village with the day one kit; the first-five-minutes survivor.
- Left click attack with the feel rules; F prompt; talk to villagers (random line) and one role NPC (guard).
- NPC groups as records with routes: one farmer caravan, one hunter squad, one bandit band. Visible when near.
- Reputation per tribe (grudges come in rung 3). Trade at a merchant (4 goods, coin). Rest at a bed. Camp.
- Wildlife from regional counts: deer and boar visible, wolves at night. Border migration on.
- Weekly calamity clock with two calamities (flood, beast tide). Day/night tint.
- No persistence yet (world regenerates each server) but the state is already structured for it.
- Part 3 (after the first QA loop): fights end in flight (break points per kind, runners go home and heal),
  conduct-based reputation (who drew first, mercy, escape), families (records with parents and children, births
  on the weekly clock, children come of age, villages refill by birth only).

**Rung 3: memory and money** — build plan in `docs/RUNG3.md`
- Gossip propagation, grudges and amends. Tribute, tax, extortion. Size tiers. Hunger. Save + catch-up.
- Blizzard and drought. Knights and adventurers. Hiring. Full talk system with all roles and replacement.
- Dash and shield block. Bows. Settlement healing and ruins.
- Order: save + catch-up first (it gates everything and nothing a player does survives a shutdown without it),
  then gossip and grudges, then tribute and tax, then hunger, then the rest. One open decision before part 1
  starts: one world per server, or one world shared by everyone.

**Rung 4: the map grows**
- More villages, expansion, large tribes, hunting parties, raids on villages, walls and gates that matter.
- Hiring villagers to build. Funding caravans. Territory politics.

**Rung 5: the superpower and the polish**
- Taking over places, absorbing ruins, tribe-level war and peace. Title screen, music, touch controls,
  animations, the extra 200 sprites.

**Parked: going public (do before rung 3 ships, not before rung 2 plays)**

Rojo is a dev-time cable only. Nothing in `roblox/src/` talks to a dev machine (no HttpService, no localhost),
so once the place is published Roblox hosts it on their servers and Danzo's PC can be off. Publishing is the
handoff: Studio > File > Publish to Roblox, then Creator Dashboard > Settings > Playability > **Public**, or
nobody can join. Code changes need a re-publish; running servers keep the old build until they shut down.

Two chores to do before strangers see it:
- ~~Hard-code the resolved image id instead of leaning on `Sprites.ResolveOnServer`~~ **done (rung 2 part 4)**:
  `Sprites.lua` carries the image id with `Resolved = true`, and `ResolveOnServer` skips a sheet marked that way,
  so no server start does the decal lookup any more. `roblox build` sets the flag for any sheet whose lock entry
  holds a real image id. **Redo this after every upload**, because a new upload gives a new decal:
  `npx warehouse roblox build --upload`, then in the Studio command bar
  `local d = game:GetObjects("rbxassetid://<decal id>")[1] print(d.Texture)`, then
  `npx warehouse roblox setid 0 <that number>`, and commit `Sprites.lua` + `assets.lock.json`.
- ~~Reword the loading message in `Client.client.lua`~~ **done (rung 2 part 4)**: past 5 s it now says
  "Still loading. If this stays, the server is starting up." and never mentions `rojo`.

Money: game passes and developer products via `MarketplaceService` (nothing wired yet), plus engagement-based
payouts from Premium playtime. Robux to cash goes through DevEx (13+, ID check, Premium, a minimum balance;
thresholds move, check the current page). Roblox keeps roughly a third of in-experience sales. **Do not charge
before rung 3's save + catch-up lands** — until then the world regenerates per server and anything sold
evaporates on shutdown. Publish free well before that: real players find what we cannot.

## 17. Asset plan for rung 2 (about 45 sprites)

| Group | Sprites | Source |
| --- | --- | --- |
| terrain | grass, grass variant, tall grass, dirt path, water, water edge, forest (tree), cave mouth, hill/rock | draw + Kenney Tiny Town |
| buildings | hut, hut burnt, wall, gate, farm plot, market stall, bed | Kenney Tiny Town + draw |
| people | villager, guard, merchant, hunter, bandit (each 2 frames: idle, step); player 2 frames x 4 facings | draw (base body + recolor per tribe) |
| animals | deer, boar, wolf (2 frames each) | draw |
| items | food, hide, tool, ore, coin, knife, camper set (bundle icon), waterskin | game-icons recolored + draw |
| camp | bedroll placed, campfire lit (2 frames), campfire out | draw |
| fx / hud | hit flash (white silhouette via tint), rain, flood water, night tint handled in Lua, heart, prompt bubble ("F"), bag | draw |

Style: 16x16, 1px dark outline, one shared palette (pick a LoSpec palette and snap everything to it).

## 18. Code layout (Rojo)

```
roblox/src/shared/     Config, Sprites (generated), TileTypes, Rng, Names, WorldGen (pure Luau, testable outside Studio)
roblox/src/server/     World (state + generation), Sim (ticks), Tribes, Groups, Wildlife, Migration, Calamity,
                       Combat, Trade, Reputation, Knowledge (talk banks), Persist (rung 3), PlayerService
roblox/src/client/     Viewport (scrolling window over the map, entity sprites), Client (input, prediction, HUD), later Prompt, Dialogue
```

## 19. Open questions

- ~~Name~~ **Lowlands** (Danzo, 2026-09-18). The Rojo project is named for it, so Studio is too.
- ~~Touch controls layout for phones~~ **decided (rung 2 part 5)**: a d-pad in the bottom-left corner and the four
  verbs (bag, standing, act, swing) in the bottom-right, both thumbs where they already rest. Tap-to-move stays,
  because travel wants it even when a doorway does not. DESIGN.md §11 offered swipe instead; the d-pad won because
  a tile game wants discrete steps and a d-pad is the one a new player can see.
  Known limit, not worth fixing yet: the layout is chosen once, from `UserInputService.TouchEnabled` at load, so
  pairing a Bluetooth keyboard mid-session leaves the d-pad up and a tablet with a keyboard attached never gets
  one. Every verb is on a key in that case, so nobody is stuck.
- Portrait on a narrow phone. A 44 px d-pad needs about 140 px however you draw it, so on a 390 px-wide play area
  the two thumb clusters leave only a quarter of the width clear. Landscape is the intended orientation.
- Exact cap numbers (section 4 has first guesses; tune on a real phone).
- **Do goods get a second axis?** They are pure sell-value today, which makes the inventory the least systemic
  part of the game (§13). Cheapest candidates that plug into systems already built: goods that are *food* (feeds
  a village, matters in a drought), goods that are *tribute* (a plunderer wants specific things), goods that
  **spoil**, and goods a tribe type cannot make itself. Do not add a crafting tree to fix this.
- ~~Do we commit to a shared world?~~ **Yes** (Danzo, 2026-09-18). §14 above; `docs/RUNG3.md` part 1.
- **Does the "what now" elder topic (§12) go in rung 3 part 3 with the chief, or earlier?** It is the only
  answer to the hour-twenty lost minute and it is maybe half a day of work, so it could ride along with almost
  anything. Argument for earlier: the first public players (rung 2 part 5) will hit the lost minute and quit
  before rung 3 exists.
- **When does the chief role appear?** §13's succession needs one, and rung 3 part 3 (tribute and tax) needs a
  face to make the demand. Recommendation: add `chief` in part 3 rather than waiting for the full talk system in
  part 5 — it is one more role reading the village bank, and it makes "who do I pay" answerable.
- **Does a player-held tribe keep running while that player is offline?** Catch-up (§14) simulates the world,
  not players, so a tribe you own would keep sending caravans and collecting tax without you. Probably right —
  it is the world-does-not-need-you pillar applied to your own kingdom — but it means you can lose a war in your
  sleep. Decide before rung 4.
- **"A little bit of the third dimension" (Danzo, 2026-09-18) — which kind?** `docs/RUNG3.md` parks real
  elevation and interiors in rung 4 because elevation touches every routing call and the wire format. Fake
  height (taller sprites on their own draw layer, cliff edges, drop shadows) changes no server code and could go
  in any week it is wanted. If the goal is that the world *looks* like it has depth, that is the cheap one and we
  can do it soon; if the goal is climbing and rooftops and being on a level someone else is not, that is rung 4.
