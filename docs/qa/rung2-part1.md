# QA goals: Rung 2 part 1 (generated world, scrolling viewport, validated movement)

Branch: `claude/clever-cerf-5pk2fp`. Commit: "Rung 2 part 1: generated world, scrolling viewport, validated movement".

## Goals of this PR

1. A 96x96 generated world from a seed: meadow, tall grass, forest, a river with fords, a lake, cave mouths,
   dirt roads between three villages. (`roblox/src/shared/WorldGen.lua`)
2. Three villages (farmer, hunter, plunderer), named, laid out from templates. The farmer village is the
   player's plundered starting village (burnt huts, a palisade with a gate, farms, a stall, a bed).
3. A scrolling viewport of 16x12 tiles that follows the player smoothly over the large map and keeps its aspect
   ratio on any screen. (`roblox/src/client/Viewport.lua`)
4. Real-time tile-step movement with WASD / arrows / tap, four facings, a two-frame walk animation.
   Server-authoritative with client prediction and snap correction; other players visible with their names.
   (`roblox/src/client/Client.client.lua`, `roblox/src/server/Server.server.lua`)
5. A day/night clock (10 minute day, 3 of them night) with a visible night tint, a HUD clock, and a village-name
   banner when you enter a village.
6. The pixel art: 22 new 16x16 sprites in one palette (terrain, buildings, player), packed into one sheet.

## Out of scope (next PR; do not penalise absence, but note how the current work sets them up)

Attack, the F interact prompt, talking, resting, camps, NPCs and groups, wildlife, calamities, trade, the
first-five-minutes survivor, hunger, persistence.

## Known limitations the builder is aware of

- Roads are quite straight; fords are only two tiles wide.
- The starting village is sparse and only two huts are burnt.
- Touch: tap-to-move exists but there is no on-screen d-pad.
