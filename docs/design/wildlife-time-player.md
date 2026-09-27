# Design §9–§11: wildlife, time and calamities, the player and combat

Part of [`docs/DESIGN.md`](../DESIGN.md), which maps every § to its file. Moved here verbatim on
2026-09-27 (handoff H2). A bare "§n" below means that section of DESIGN.md, wherever it now lives.

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
