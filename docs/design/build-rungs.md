# Design §16–§18: build rungs, the rung 2 asset plan, code layout

Part of [`docs/DESIGN.md`](../DESIGN.md), which maps every § to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of DESIGN.md, wherever it now lives.

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
