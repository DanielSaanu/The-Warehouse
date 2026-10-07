# 06 · World liveliness: ambient detail, the clock, routines, calamity telegraphing, marks of history

Hub: [README](README.md). Sources: [07-sources](07-sources.md).
Tags: **[measured]** = numbers or documented mechanics. **[dev]** = a developer's stated reasoning. **[opinion]** = a
secondary writer or this report's inference.

## Takeaway

Liveliness comes from many small things that move without the player's input and from each place having one
memorable detail. None of it needs a 3D renderer: sprite swaps, 2–3 frame loops, scheduled positions, a palette tint
on the clock. Lowlands already has the autonomous movers (caravans, squads, wildlife that hunts, villagers walking to
plots); the gap is *visibility*. A clock reads as alive only when at least three systems key off it; a tint alone is
decoration. The weekly calamity is well-precedented (7 Days to Die, Don't Starve, Rain World) and the precedents all
telegraph it in stages, give it a direction, scale it to the player, and let it leave a mark when nobody is there.

## Ambient life at 16×16

- Barone: Harvest Moon felt alive because "time moved forward with or without your input"; his aim was "a strong
  sense of community and a relaxed pace" [dev] ([NPR](https://www.npr.org/2025/01/24/g-s1-44510/the-legacy-and-future-of-the-farming-game-stardew-valley)).
- Pixpil (Eastward, 200+ characters): "at least one special part of each character and environment ... It's the
  uniqueness makes people remember" [dev] ([Game Developer: Eastward](https://www.gamedeveloper.com/disciplines/road-to-the-igf-pixpil-s-i-eastward-i-)).
- CrossCode: "we don't want NPCs to be just mere decoration"; reviewers singled out NPCs "complaining about gameplay
  mechanics" and "the little details" [dev + review] ([CrossCode devlog](https://radicalfishgames.itch.io/crosscode/devlog/66501/crosscode-103-more-quests-and-npc),
  [Nintendo Life](https://nintendolife.com/reviews/switch-eshop/crosscode)).
- Rain World: "outside of your frame they're all still alive" [dev] ([Game Developer: Rain World](https://www.gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-)).
- Walking Pokemon in HGSS is a pure sprite follower on a tile grid [measured] ([Bulbapedia](https://bulbapedia.bulbagarden.net/wiki/Walking_Pok%C3%A9mon)).

The cheap set for a tile renderer [opinion]: 2–3 frame idle loops on a few tiles per screen (water, smoke, a flag);
critters that exist only to *react* (a bird that flies off when you come within N tiles) because reaction is what
players read as alive; one bespoke detail per village rather than many generic ones; a follower (a dog, a bought
animal) as one extra entity with a path trail. Route caravans and predators past the roads players use rather than
across empty map, so the autonomous movers are *seen*.

## Day and night: three systems or it is decoration

| Game | What hangs off the clock | Tag, source |
|---|---|---|
| Pokemon G/S | encounters by time; weekday events; night tint and lit windows; "adds quite a bit of variety" | measured + review ([Wikipedia](https://en.wikipedia.org/wiki/Pok%C3%A9mon_Gold_and_Silver)) |
| Stardew | rain waters crops, some fish only in rain, lightning every 10 min in storms, villagers switch to "rain" schedules, the TV forecasts tomorrow | measured ([Stardew wiki: Weather](https://stardewvalleywiki.com/Weather)) |
| Minecraft | 20-minute day; hostiles at sunset; sleep to skip; "a natural sense of urgency" | measured ([CurseForge](https://blog.curseforge.com/how-long-is-a-minecraft-night/)) |
| Don't Starve | pigs go indoors; dark is lethal without light | measured ([wiki](https://dontstarve.wiki.gg/wiki/Guides/Advanced_Hound_Protection)) |
| Dying Light 1 | "the day is for humans, and the night is for infected ... the most valuable stuff ... hidden inside those dark places" | dev ([GamesBeat](https://gamesbeat.com/dying-light-developer-explains-how-to-roam-an-open-world-with-being-eaten-by-zombies-interview/)) |
| Dying Light 2 | softened night for casual players; fans objected; studio conceded it had "dialed back nighttime tension too far" and re-hardened it | dev ([PlayStation LifeStyle](https://www.playstationlifestyle.net/2023/07/01/dying-light-2-dev-dialed-back-nighttime-tension-too-far/)) |

Lowlands: `DAY_SECONDS 600`, `NIGHT_FRACTION 0.3` — three real minutes of night in every ten (`Config.lua:26-30`).
Today night is a tint plus "fire keeps wolves 3 tiles off" (`Config.lua:50-51`); the audit could not confirm that
anything hunts *more* at night. Dying Light 2's reversal is the best single piece of evidence against making night
safe for phones [opinion]. Make it bite and pay: wolves range further, plunderers move, a night-only thing is worth
more at the stall, villagers are indoors with lit windows. A fifth good touches the parked "goods' second axis"
question (`docs/design/open-questions.md:19-22`); the behaviour numbers alone touch nothing.

Cheap 2D implementation [opinion]: one multiply colour per hour lerped over the viewport (exists); rain as a 2-frame
scrolling overlay plus droplet tiles on water; lightning as a 1-frame white flash and a delayed sound; window-light
sprites swapped on at dusk, one variant per building.

## Calendar: a rhythm people can say out loud

- Stardew: 4×28-day year, 12 fixed-date festivals, a calendar posted on Pierre's wall [measured] ([Festivals](https://stardewvalleywiki.com/Festivals)).
- Animal Crossing: "the sense of unity that comes from time passing in sync with the real world" [dev, via snippet;
  Iwata Asks itself errored] ([Iwata Asks](https://iwataasks.nintendo.com/interviews/3ds/animalcrossing-newleaf/0/1)).
- Guild Wars 2 moved world bosses onto a fixed public timetable (hardcore bosses in a 3-hour window every 8 hours,
  standard ones hourly) so "everyone gets a chance to participate", and added guild-triggered bosses for people the
  times do not suit [dev] ([ArenaNet](https://www.guildwars2.com/en/news/the-megaserver-system-world-bosses-and-events/)).
- Grow a Garden: weekly drops with half-hour events between, at published ET slots [measured] ([allthings.how](https://allthings.how/grow-a-garden-events-schedule/)).

For Lowlands [opinion]: give each village a day (market day: stalls pay more and the caravan comes; hunt day: the
squad leaves at dawn) and put it on the gate sign and in villagers' mouths. One clock (`Calendar`, `WEEK_DAYS 7`)
makes this trivial to compute. It is village *behaviour*, so it is a later rung by the expansion's rule
(`world-expansion.md:46-47`). GW2's lesson for a shared world where not everyone is online at once: small recurring
events every 15–30 real minutes (a pack at a village, an ambush on a road) plus the big weekly one, rather than one
moment a week that most sessions miss.

## NPC routine: learnable beats rich

- Stardew schedules are ~5 timed entries a day (9:00, 10:30, 13:00, 16:30, 19:30), each a map, tile, facing and
  optional animation, with rain, weekday and friendship variants [measured] ([Stardew wiki: Schedule data](https://stardewvalleywiki.com/Modding:Schedule_data)).
- Aonuma cut Majora's Mask from a week to three days: "the townspeople do different things each day ... when the
  timespan becomes a week, that's just too much to remember" [dev] ([Iwata Asks MM3D](https://www.nintendo.com/en-gb/Iwata-Asks/Iwata-Asks-The-Legend-of-Zelda-Majora-s-Mask-3D/The-Legend-of-Zelda-Majora-s-Mask-3D/1-Make-it-in-a-Year/1-Make-it-in-a-Year-959667.html)).
- Piranha Bytes' appeal: "observe the NPCs, and then either play along or try to outsmart the AI" [dev] ([RPG Codex](https://rpgcodex.net/article.php?id=7745)).
- Practitioner rule (Skywind): "a few things to do and letting them sandbox or patrol between them", with early
  risers and night owls, and NPCs who share scenes meeting at some point in the day ([Skywind handbook](https://handbook.tesrskywind.com/dev/Scheduling)).

Lowlands today: villagers walk to plots by day and huts at night, run from wolves, and have families
(`docs/systems/population.md:3-21`). The minimum that reads as alive [opinion]: 3–5 waypoints a day (home → work
tile with a 2-frame work animation → a shared social tile where two NPCs face each other → home), offset ±1 hour per
NPC so the village does not move in lockstep, and *predictable* ("the smith is at the forge from 8 to 5") because a
persistent world cannot be replayed. Gossip can carry the schedule ("she's always at the well at noon"). One NPC
walking field→granary with a sack is the cheapest "the economy is real" signal.

## Buildings and interiors

Thin evidence. Stardew's NPCs warp into interiors as separate maps [measured]; Minecraft's villagers hide indoors at
the raid bell and raiders break doors, so interiors are shelter, not scenery [measured] ([Minecraft wiki: Raid](https://minecraft.wiki/w/Raid));
Dying Light puts the valuables in the dark interiors to make them worth entering [dev]. The cheap win for liveliness is
the *exterior* signalling the interior: lit windows, smoke when someone is home, a door that opens when an NPC passes,
sound through the door. That gives most of the "families live here" read with no interior map [opinion]. Roof-fade
(opacity on the roof layer when the player stands under it) is a render trick the scene format's `opacity` effect
could support and keeps the world seamless on phones. Interiors earn their cost when they are shelter during the
calamity or shops. The expansion defers interiors (`world-expansion.md:11-18`); this agrees.

## Marks of history

- Dwarf Fortress players keep a ruined fortress going because of engravings and memorials: "Even when ... I've lost
  eighty dwarves ... I'm driven to keep going in my fortress rather than start over" [opinion] ([Game Developer](https://gamedeveloper.com/design/dwarf-fortress-and-rimworld-tell-very-different-stories)).
- GW2: "if there are no players, the enemy will take over and you'll have to get it back" [dev] ([Engadget, Kerstein](https://www.engadget.com/2011-05-18-living-breathing-world-martin-kerstein-expounds-on-guild-war.html)).
- Minecraft: an abandoned raid keeps killing villagers and breaking doors; recovery "may take several in-game days or
  even weeks" [measured] ([Minecraft wiki: Raid](https://minecraft.wiki/w/Raid)).
- Procedural ruins should imply a history that can be told [academic] ([GDMC paper](https://arxiv.org/pdf/1803.09853)).

| Mark | After | Decay | Constraint |
|---|---|---|---|
| burnt-hut overlay | a plunder | days | toy #5's rule: a decaying overlay, never a map edit |
| bones | a kill, a wolf's deer | a day or two | project from the death record + day count |
| a named grave | a villager's death | none | `Families` already records deaths |
| a cairn | a player's death | a week | the bag stamp exists; this is its memorial |
| a notch on the gate board | a calamity survived | none | one counter per village |

ARCHITECTURE §9 says map writes are camp/bag stamps only (`docs/architecture/decisions.md:40-53`) and S1 says a
capped list is a memory, never a ledger. So: marks are *projections* of records the save already holds, with a
closed-form decay over a day count (learnings P2), not new map writes. Still trigger 3, and the expansion resets the
save anyway, so bundle it then. Naming them (DF's engravings) is what makes them owned.

## The calamity: telegraph, direction, scale, aftermath

| Game | Cadence | Telegraph | Tag, source |
|---|---|---|---|
| 7 Days to Die | every 7th day, 22:00–04:00; optional ±2-day jitter so veterans cannot clock it | 08:00 day counter turns red; 18:00 thunder, sky reddens; 21:00 very red; music | measured ([7DTD wiki](https://7daystodie.wiki.gg/wiki/Blood_Moon), [Freak Hosting](https://help.freakhosting.com/games/7-days-to-die/tuning-horde-night-difficulty)) |
| Don't Starve hounds | 6–13 days early, 3–8 late (escalates) | growl 120 s → 30 s ahead; hide before it ends and the first wave loses you | measured ([wiki: Hound](https://dontstarve.wiki.gg/wiki/Hound)) |
| Terraria | nightly/dawn dice gated on **progress** (Blood Moon needs >120 HP) | one chat line, with a **direction** for invasions | measured ([Terraria wiki: Events](https://terraria.wiki.gg/wiki/Events)) |
| Sea of Thieves | one world event per server, ~30 min | a sky marker visible from anywhere | measured ([SoT wiki](https://seaofthieves.wiki.gg/wiki/World_Events)) |
| Minecraft raid | waves; 40-min bar | horn per wave, a villager rings the bell; Hero of the Village discounts and fireworks after | measured ([Minecraft wiki](https://minecraft.wiki/w/Raid)) |
| Rain World | 6.5–13 min cycles | 30-s pips always on screen | measured ([Rain World wiki](https://rainworld.miraheze.org/wiki/Rain)) |

Lowlands today: one calamity for the whole world, two kinds, "from the north" hard-coded, warned the day before
(`docs/systems/time-and-calamities.md:46-51`, `Config.lua:54`). The precedents suggest [opinion]:

1. **Three stages** like 7DTD: at the week's start the HUD date or board shows the day; on the day it turns red and
   NPCs bark; a few game-hours before, the sky shifts and a sound plays; the last stretch is unmistakable. The
   warning spreading by people from day 5 is H12 Option B/C.
2. **A direction** (Terraria): "the flood comes from the north ford", so players can position and shelter choices
   mean something. The 16-village map gives directions to vary.
3. **Scale and gate**: Terraria never shows a Blood Moon to a weak character; Sea of Thieves runs one event per server
   with a marker. Spare very new players, or make only some villages targets each week.
4. **Resolve offline, leave a mark**: GW2's "the enemy will take over" and Minecraft's broken doors. A calamity nobody
   was online for must not silently no-op; the return card says what it did and what needs doing.
5. **Jitter and escalation**: 7DTD's ±range and Don't Starve's shrinking intervals as the server ages.
6. **Everyone who shows up gets paid, scaled, no stealing** (GW2's event rule, [Shacknews](https://www.shacknews.com/article/63774/guild-wars-2-dynamic-events));
   Minecraft's Hero of the Village is the model for the aftermath feeling good.

The Rain World warning applies: a dangerous world "that cares for itself" produced early no-win situations for a
streamer [dev]. `GRACE_DAYS 2` (`Config.lua:65`) is the current answer; the three-stage telegraph is the rest.

## Sound: the cheapest channel

Hyper Light Drifter mixes stems by proximity to hazards; Celeste's score was written as adaptive from greyboxing
[dev] ([GDC Vault HLD](https://gdcvault.com/play/1023778/The-Sound-of-Hyper-Light), [OSV, Lena Raine](https://originalsoundversion.com/interview-composer-lena-raine-talks-celeste-soundtrack-working-in-game-audio));
7DTD's thunder, Don't Starve's growl and Minecraft's horn are all audio-first telegraphs. One loop per tribe, a dusk
layer that fades in on the clock, a calamity stinger, biome ambience (birds by day, crickets and wolves by night):
Roblox `Sound` volume lerps are enough. Silence with ambience, broken by music at a village gate, makes villages
destinations [opinion].

## Ecology you can see on one screen

Tokuda built Monster Hunter World's fields as "herbivore → weak predator → stronger predator → apex" and let players
lure and orchestrate [dev] ([Inven Global](https://www.invenglobal.com/articles/6549/creating-a-dense-open-world-a-lecture-from-yuya-tokuda-the-director-for-monster-hunter-world));
Rain World began as three creatures (bat, slugcat, lizard) [dev]; Ultima Online's ecology was removed for CPU cost
("radial searches followed by pathfinding") and a closed-economy bug ("the central bank ran out of wool"), not because
players killed everything [dev] ([Koster](https://www.raphkoster.com/?p=46439)).

Lowlands has deer, boar and wolves and wolves visibly hunt deer. The audit notes a chase runs ~20 tiles off-screen
(deer 1.3 > wolf 1.25) and that every hit sweeps every entity (`docs/qa/rung3-part1-summary.md:41-44`,
`docs/systems/movement-and-combat.md:27-51`). Koster's two causes map straight onto this server: keep predator AI to
grid distance checks on a tick budget, and keep spawns a faucet from region counts (they already are) rather than a
closed pool. Then make the chain *legible*: route chases through visible places, let players lure prey onto bandits
(toy #1, "bait and lure"), and leave bones after.

## Gaps

- Stardew's "Critters" page, Bulbapedia's time page and the Grow a Garden wiki blocked fetching.
- No Fun Pimps statement on *why* seven days; no Klei post on hounds; no Rare GDC talk.
- No telemetry on how many players engage with night in any of these games; the Dying Light evidence is developer-
  reported sentiment.
- No source on roof-fade (Kynseed, Graveyard Keeper); that section is design reasoning only.
