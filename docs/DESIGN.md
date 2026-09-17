# Design: the tribes game (working title: Lowlands)

A 2D top-down pixel-art Roblox game about surviving in a living overworld. Tribes trade, raid and remember you.
Wildlife breeds and starves without you. The world is shared by everyone on the server and keeps living while
you are away. "Rain World energy" on a tile grid.

Source of truth for gameplay decisions. `ideas/INBOX.md` is the scratchpad; things that get agreed move here.

## 1. Pillars

1. **The world does not need you.** Tribes and animals follow their own rules whether or not a player is nearby.
2. **Everything remembers.** Every tribe, group and creature keeps a relationship with each player, and they tell each other.
3. **Simple to touch, deep underneath.** Move, attack, interact. That's the whole controller. The depth is in who you did it to.

## 2. Decisions made (do not relitigate without a reason)

| Topic | Decision |
| --- | --- |
| View | Top-down tile grid, 16x16 sprites, scrolling camera over a large map |
| Movement | Real time, tile steps (Zelda / Stardew feel), server authoritative |
| Attack | Left mouse button (touch: on-screen button later). Hits the tile you face |
| Interact | F key. A prompt appears when something interactable is adjacent (touch: tap the prompt) |
| Death | Wake at the village you last **rested** in. Lose carried goods and some reputation |
| Rest | F at a bed / campfire in a village sets your spawn point. Not allowed in villages hostile to you |
| Persistence | World state is saved to DataStore and **caught up** on load: the simulation runs the missed time |
| Setting | Grasslands overworld: meadows, forest, rivers, caves, hills. Primitive tribes, real wildlife |
| Player | Just a person. Starts in a village that was just plundered |
| First map | About 96x96 tiles, three villages (one per tribe type, mid sized) |
| Time | 1 in-game day = 10 real minutes. 7 days = 1 week. One calamity per week |

## 3. The world is numbers; the grid is a window

The server runs an **abstract simulation**. Nothing in it is a sprite:

- **Tribe**: type (farmer / hunter / plunderer), size tier (small / mid / large), home village, stockpile,
  relations with every other tribe, reputation with every player, list of active groups.
- **Group**: kind (caravan, hunter squad, bandit band, patrol, hunting party), owning tribe, position on the
  map, route, members (count + strength), cargo, **gossip table**.
- **Village**: tribe, footprint tiles, buildings, walls, stock, tax/tribute ledger.
- **Region** (the map is cut into 16x16-tile regions): biome, grass health, wildlife populations as counts
  (deer, boar, wolf, ...), last calamity effects.
- **Player**: position, hp, inventory, home village, reputation per tribe, personal memories other NPCs hold.

Clients only see what is near them. When a group's position comes within view of a player, the server
materialises it as individual NPC sprites; when nobody is near, it collapses back into a record. Wildlife
individuals are spawned near players from the region's counts and folded back into counts when they leave.
This is how RimWorld, Dwarf Fortress and Mount & Blade keep a whole world alive cheaply.

Tick rates: movement 10 Hz for things near players; world sim 1 Hz; economy and breeding once per in-game day.

## 4. Tribes

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

## 5. Trade, tribute, tax

- Goods for v1: **food, hides, tools, ore**. Each tribe type overproduces one and needs another (farmers make
  food, hunters make hides, plunderers "make" whatever they stole and always need food).
- Prices are per village, move with stock, and get a multiplier from the player's reputation there.
- **Tribute**: weaker tribe pays a stronger plunderer tribe a share of stock per week to be left alone.
- **Tax**: large farmer tribes take a share from small villages in their territory.
- **Extortion**: a plunderer group meeting a caravan may demand a cut instead of fighting. Caravans accept
  based on strength comparison and how much they carry.
- The player trades through the interact prompt at a merchant or a group leader.

## 6. Reputation and gossip

- **Reputation** is one number per (tribe, player), from hostile to family. It moves on events: trade,
  gifts, killing their people, protecting their caravan, paying tribute, freeing captives.
- **Memory** is per NPC group / village: what they personally saw you do, with a timestamp.
- **Gossip**: when two groups (or a group and a village) are on the same or adjacent tile, they exchange
  memories about players. Each hop loses detail and weight. Caravans are the big spreaders. A lone bandit tells
  his band when he gets home. Hunter squads tell the caravan they are guarding. Information really has to travel,
  so you can outrun your reputation for a while, and a tribe on the far side of the map may not know you yet.
- Harming someone from a large farmer tribe hurts you with their friends and family first, then their village,
  then the tribe, as the news spreads.

## 7. Wildlife and ecosystem

- Per region: counts of **grass health**, **deer**, **boar**, **wolf** (v1; add more later).
- Daily tick per region: herbivores eat grass and breed if fed; predators eat herbivores and breed if fed;
  starving populations shrink; small migration between neighbouring regions.
- Players kill individuals, which decrements the region count. Kill every wolf and the deer explode and strip the
  grass; strip the grass and the deer starve; burn a forest (later) and the region loses habitat.
- Hunters hunt from these counts too, so hunter tribes are part of the ecosystem, not outside it.
- The **ratio of wildlife you see** is the live state of the numbers. That is the whole "it should show".

## 8. Time and calamities

- Day = 10 real minutes, week = 70 minutes. Day/night tint on the map.
- Once per in-game week, one calamity, chosen with weights by season (later):
  - **Flood**: rivers spill, low tiles become water for the day, caravans stop, food stocks damaged.
  - **Beast tide**: a region's predators surge and roam, villages take losses unless walled or defended.
  - **Blizzard**: movement halved, no farming, animals shelter, cold damage outside a village.
  - **Drought**: grass health drops, herbivores starve, food prices spike, tribute demands rise.
- Warning signs the day before (sky tint, NPC dialogue line), so shelter is a choice you make.
- This replaces the 90-second rain timer in the current prototype.

## 9. Player, controls, combat

- Move: WASD / arrows, real-time tile steps. Touch: swipe direction or a d-pad (later).
- Attack: left mouse button. Strikes the adjacent tile in the facing direction. Weapons change damage and reach.
- Interact: F. A prompt ("F: Trade", "F: Talk", "F: Pick up", "F: Rest") appears when adjacent to something
  interactable. Only one prompt at a time, the nearest.
- Stats: hp, attack, defence, speed. NPCs use the same stats, so the "hunters are strongest individually" rule
  is just numbers.
- Rest: interact (F) with a bed or campfire inside a village to set your spawn point. Villages whose tribe is
  **hostile** to you refuse ("They won't let you stay"). Neutral and better allow it. The plundered starting
  village is your first rest point automatically.
- Death: respawn at the village you last rested in. If that village has since turned hostile (you did something,
  or gossip caught up), you wake at the nearest village that still allows you, and the game tells you why.
  Inventory dropped where you fell (can be recovered if nobody took it), reputation hit with the tribe you died fighting.
- Hunger comes in rung 3 if it makes the food economy matter; not in v1.

## 10. Persistence and multiplayer

- One shared world per server. Reputation and memory are per player. Gossip carries player names.
- The world state (tribes, groups, villages, regions, calamity clock) is saved to DataStore every 2 minutes and
  on server shutdown. Player state is saved separately on leave.
- **Catch-up**: on load, the server runs the simulation for the missed time at coarse steps (one step per
  in-game hour, capped at, say, 4 weeks), so caravans arrive, tribes breed, the ecosystem drifts. Players are not
  simulated while offline.
- If two servers run the same world (Roblox can start a second server when the first is full), the second loads
  the last save and diverges. v1 accepts this. Later: one world per server slot.

## 11. Build rungs

Rung 1 is done (grid, movement, one room, rain timer, upload pipeline).

**Rung 2, next: a small living world**
- Scrolling camera; 96x96 map from a seed: meadow, forest, river, cave mouths, dirt paths between villages.
- Three villages (farmer, hunter, plunderer; all mid), huts, one wall segment for the farmers.
- Player starts in the plundered farmer village. Left click attack, F interact prompt.
- NPC groups as records with routes: one farmer caravan, one hunter squad, one bandit band. Visible when near.
- Reputation per tribe. Trade at a merchant (4 goods). Bump into a bandit and they fight back.
- Wildlife from regional counts: deer and boar visible, wolves at night.
- Weekly calamity clock with two calamities (flood, beast tide). Day/night tint.
- No persistence yet (world regenerates each server) but the state is already structured for it.

**Rung 3: memory and money**
- Gossip propagation. Tribute, tax, extortion. Size tiers for tribes. Hunger. Save + catch-up.
- Blizzard and drought. Knights and adventurers. Hiring.

**Rung 4: the map grows**
- More villages, expansion, large tribes, hunting parties, raids on villages, walls and gates that matter.

**Rung 5: polish**
- Title screen, music, touch controls, animations, the extra 200 sprites.

## 12. Asset plan for rung 2 (about 40 sprites)

| Group | Sprites | Source |
| --- | --- | --- |
| terrain | grass, grass variant, dirt path, water, water edge, forest (tree), cave mouth, hill/rock | draw + Kenney Tiny Town |
| buildings | hut, hut damaged, wall, gate, farm plot, market stall | Kenney Tiny Town + draw |
| people | villager, merchant, hunter, bandit (each 2 frames: idle, step); player 2 frames x 4 facings | draw (base body + recolor per tribe) |
| animals | deer, boar, wolf (2 frames each) | draw |
| items | food, hide, tool, ore, coin | game-icons recolored |
| fx / hud | rain, flood water, night tint handled in Lua, heart, prompt bubble ("F") | draw |

Style: 16x16, 1px dark outline, one shared palette (pick a LoSpec palette and snap everything to it).

## 13. Code layout (Rojo)

```
roblox/src/shared/     Config, Sprites (generated), Grid, TileTypes, Net (remote names)
roblox/src/server/     World (state + generation), Sim (ticks), Tribes, Groups, Wildlife, Calamity,
                       Combat, Trade, Reputation, Persist (rung 3), PlayerService
roblox/src/client/     Camera (viewport over the map), Input (move/attack/interact), Hud, Prompt, Entities
```

## 14. Open questions

- Name. Working title Lowlands until something better shows up.
- What does the player carry on day one? (Nothing, a knife, a bag of food?)
- Touch controls layout for phones.
