# 02 · Exploration and discovery: the honest scale check, density over size

Hub: [README](README.md). Sources: [07-sources](07-sources.md).
Tags: **[measured]** = read from game data or a study. **[dev]** = a developer saying what they did. **[opinion]** =
critic, essayist, or this report's inference.

## Takeaway

256×256 with 16 villages is not too big: it is Hoenn-density, and at Lowlands' walking speed the whole map edge is 44
seconds of walking. The risk is the opposite of what the fear says: not "too far to walk" but "too many empty
screens". The fix the evidence supports is to build the square as a road graph with 16 nodes, let forest, marsh and
hills eat most of the area, and fill *time* rather than tiles: one notice every screen or two, one bigger payoff per
village-to-village leg, roads 1–3 viewports wide with bends, one tall thing per village visible a screen early, and
secrets that always carry a tell. Density over size is argued, not proven by any controlled study; but every
designer statement found points the same way.

## The honest scale check

| World | Land tiles (approx.) | Towns | Tiles per town | Source |
|---|---|---|---|---|
| Kanto (Gen 1) | ~30–45k walkable (estimate from the 7200 px render and block sizes) | 11 incl. Indigo | ~3–4k | [pokered constants](https://raw.githubusercontent.com/pret/pokered/master/constants/map_constants.asm), [vjeux render](https://blog.vjeux.com/2023/project/pokemon-red-blue-map.html) |
| Hoenn (Gen 3) | ~80k land (towns ~23.7k + land routes ~57k; layout rectangles incl. tree borders) | 16 | ~5k | [pokeemerald layouts.json](https://raw.githubusercontent.com/pret/pokeemerald/master/data/layouts/layouts.json) |
| Koholint (Link's Awakening) | 256 screens | — | — | [Wikipedia](https://en.wikipedia.org/wiki/The_Legend_of_Zelda:_Link%27s_Awakening) |
| Lowlands today | 96² = 9,216 | 3 | 3,072 | `docs/systems/world-and-map.md:3-12` |
| Lowlands planned | 256² = 65,536 | 16 | 4,096 | `docs/plans/world-expansion.md:11-18` |

So the planned map sits between Kanto and Hoenn per town [measured sums, rough]. Masuda said Hoenn is "a bit bigger
than Gold & Silver's map, which included both the Kanto and Johto regions" [dev] ([Lava Cut Content](https://lavacutcontent.com/sugimori-masuda-gen-3-interview/)).

**Time, not tiles** [inference from `Config.lua:19`]: `MOVE_STEP` is 0.17 s per tile, about 5.9 tiles/s.

| Distance | Tiles | Seconds at speed 1 |
|---|---|---|
| Across one 16-column screen | 16 | 2.7 |
| Gen 1 Route 1 (town to town) | 36 steps | 6 |
| Longest Gen 1 route (Route 4) | 90 steps | 15 |
| Mean village spacing on a 4×4 grid | ~64 | ~11 |
| Whole 256 edge | 256 | 44 |

Pokemon's towns are 36–90 steps apart and that feels right because grass, trainers and ledges interrupt every few
steps, not because the walk is long. The Witcher 3's rule was "every forty seconds they should see something"; the
circulating measurements are Witcher 3 32 s, BotW 42 s, New Vegas 49 s [dev via secondary; the figures could not be
traced to their source] ([TweakTown](https://www.tweaktown.com/news/59420/witcher-3s-40-second-rule-kept-players-engaged/index.html),
[gamedev.net digest](https://gamedev.net/news/5308/)). At Lowlands' pace 40 s is 240 tiles, longer than the map. So the
rule has to be stated in steps: **one small notice every 60–100 steps (10–17 s), one bigger payoff every leg.**

Viewport parity [measured]: the GBA showed 15×10 steps; Lowlands shows 16–22×12. Gen 3 land routes are mostly 20 or
40 metatiles across, so **one to three viewports wide, never a featureless field**; Masuda says the wider GBA screen
changed where trainers could hide [dev] ([layouts.json](https://raw.githubusercontent.com/pret/pokeemerald/master/data/layouts/layouts.json),
[Lava Cut Content](https://lavacutcontent.com/sugimori-masuda-gen-3-interview/)). 256×256 at a 15×10 view is ~440
screens, about 1.7× Koholint: a large budget to fill with hand-placed tells [inference].

Sessions [measured]: Roblox median session 6.6 min, 75th percentile 14.5 ([GameAnalytics 2025 Roblox](https://www.gameanalytics.com/cn/reports/2025-roblox-report));
cross-genre mobile median 5–6 min ([GameAnalytics mobile 2025](https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks)).
One leg (walk + payoff + a village interaction) should fit in 3–5 minutes. At 11 s between villages that is trivially
true; the question is what fills the minutes.

## Density over size: the argument and its evidence

- Yakuza's Kamurocho can be crossed "in under three minutes" and held a reviewer 45 hours [opinion] ([Push Square](https://www.pushsquare.com/news/2021/03/soapbox_how_yakuza_proves_bigger_open_worlds_arent_always_better)).
- Koholint: "though small, contains a large number of secrets" [measured count, opinion on effect] ([Wikipedia](https://en.wikipedia.org/wiki/The_Legend_of_Zelda:_Link%27s_Awakening)).
- Outer Wilds: seven bodies, each a mystery chain; "learning new things is the only feedback the player gets" [dev] ([Wikipedia: Outer Wilds](https://en.wikipedia.org/wiki/Outer_Wilds)).
- Elden Ring's weakest-received content was repeated catacombs with low-value loot [opinion] ([Steam discussions](https://steamcommunity.com/app/1245620/discussions/0/3183486955461681051)).
- Masuda condensed real geography "to make everything closer together" [dev] ([Lava Cut Content](https://lavacutcontent.com/sugimori-masuda-gen-3-interview/)).
- "It's not a question of the world being too big or too small, it's the density of interesting things" [opinion] ([Wayline](https://www.wayline.io/blog/open-world-illusion-freedom-or-empty-space)).

No controlled study compares retention across map densities. Treat "density over size" as a strong consensus of
practitioners, not a measured law.

**Verdict for the expansion** [inference]: keep Danzo's 256 and 16. Plan it as a road tree with 16 nodes (already in
the plan, `world-expansion.md:21-31`), roads 1–3 screens wide with a bend every screen, and most of the square as
slow or impassable land. Hoenn's layouts are ~45% sea; Kanto is ringed by mountains. Consider opening the map in
thirds (one tribe's land at a time, by reputation or caravan access) so early players never see the empty far corners.

## Route anatomy: gates you can read at a glance

Pokemon's gates are all legible without UI: a one-way ledge, a tree or boulder needing an HM, a gate house, a
sleeping Snorlax, a trainer's line of sight [opinion/fan analysis; Bulbapedia was blocked]
([Fantendo analysis, snippet](https://fantendo.fandom.com/wiki/User_blog:Shadow_Inferno/A_short_analysis_of_the_first_Routes_in_Pokemon_Games_(Gen_I-IV)),
[Bulbapedia: Route Gate](https://bulbapedia.bulbagarden.net/wiki/Route_Gate)). Ledges create one-way loops that teach
backtracking. LttP channels movement through discrete regions with ridges, trees and riverbanks, and only 6 of 256
chunks are unreachable [analysis on a measured grid] ([Game Developer: Overworld Overload](https://www.gamedeveloper.com/disciplines/overworld-overload-an-analysis-of-link-to-the-past-s-light-world-part-2)).

Lowlands equivalents that need no new UI [inference]: a ford only a caravan crosses in flood; a one-way slide down a
riverbank that loops you back toward the village you came from; a tribe gate whose guard reads your standing; a
predator den at a pass that is a soft gate and a reason to ride with the squad; a fallen log cleared with a tool.
All of these are the existing systems (fords, standing, wildlife, goods) placed deliberately.

## Lures in a 15×10 window

BotW's field is a hierarchy of visible lures (towers → shrines → stables → small curiosities) behind occluding
"triangles" so there is always a reason to go a little further; shrines glow at night; distances were calibrated by
overlaying a map of Kyoto [dev via reports] ([80.lv](https://80.lv/articles/the-design-secrets-of-breath-of-the-wild/),
[Zelda Universe](https://zeldauniverse.net/2017/10/09/a-deep-dive-into-nintendos-development-of-breath-of-the-wild/),
[GoNintendo/The Verge](https://gonintendo.com/stories/275499-the-legend-of-zelda-breath-of-the-wild-s-map-was-inspired-by-kyo)).
Thatgamecompany's designer: landmarks ("weenies") orient from a distance; test navigability "without a HUD or a
mini-map" [dev via 80.lv] ([80.lv](https://80.lv/articles/thatgamecompany-s-designer-on-how-not-to-get-lost-in-game-using-cognitive-maps/)).

Nothing is visible from afar in 2D. The translation [inference]:

| 3D lure | 2D equivalent | Lowlands hook |
|---|---|---|
| Tower on the horizon | a 2–3 tile tall sprite poking into the top of the screen a full screen early | the expansion's halls, towers, totems (`world-expansion.md:40-44`) |
| Smoke, light | chimney smoke column; lit window or brazier at night | `DayCycle` tint; building art |
| Triangle (occluder with two ways round) | a diagonal cliff or forest edge across the road; each side pays out | WorldGen land types |
| Rectangle (hides completely) | a dense wood or walled compound holding the bigger secret | caves, strongholds |
| Moving landmark | a caravan's dust, a hunting squad on the road | `Bands` routes past roads players use |

A small measured study on A Short Hike and Sable found players describe navigation by **landmarks and by NPCs**, not
by paths or districts; "players used characters as reference points, directional guides, and information sources"
([Wellesley, Image of the Open World Game](https://cs.wellesley.edu/~pmwh/mvmap/papers/open_world_elements/open_world_elements.html)).
Lowlands' named NPCs with routines are this: a hunter who always stands at the north gate at dawn is a signpost.
Directions should be spoken in landmark language ("past the split oak, keep the river on your left").

## Secrets with tells, knowledge as reward

- LttP's bombable walls have an obvious and a subtle version and ring when struck [measured] ([Zelda Wiki](https://zeldawiki.wiki/wiki/Bomb_Wall)).
- Shouldice (Tunic): a good secret "integrates with all of the stuff you already knew. It's like discovering a
  bombable wall for the first time in Zelda"; "when your imagination is free to fill in the gaps, a world becomes
  larger" [dev] ([Time Extension](https://www.timeextension.com/news/2022/10/the-making-of-tunic-a-love-letter-to-the-secrets-of-retro-gaming)).
- Outer Wilds: "a set of smaller mysteries ... reward the player with new knowledge more often than fewer, larger
  mysteries would" [dev] ([Wikipedia](https://en.wikipedia.org/wiki/Outer_Wilds)).
- Hollow Knight withholds the map until you find Cornifer (signposted by paper and humming); the map fills only at
  benches; "the relief of acquiring a map washes over you" [dev + opinion] ([SuperJump](https://www.superjumpmagazine.com/getting-lost-by-design-in-hollow-knight/)).

Rules for Lowlands [inference]: every secret has a tell the renderer already supports (a recoloured grass tile, a
cracked boulder, a lone tree) and the same tell always means the same kind of secret. Gossip is already the
Outer-Wilds "knowledge currency": a rumour that points somewhere is a quest without a marker. Map as reward: a tribe's
cartographer sells the map of *their* land; camps reveal nearby chunks. Note the HUD has no minimap and "no line room"
for one (`docs/systems/client.md:50-51`), which makes the earned-map idea a Tab-screen page, not a HUD element.

## Fast travel: the caravan is already the right answer

Critics argue free fast travel "breaks pacing, degrades immersion ... encourages bland open worlds"; earned, limited,
diegetic travel (Stardew minecarts to four fixed points behind a bundle, Wind Waker, Dragon's Dogma) "paradoxically
encourages exploration" [opinion] ([Game Developer: Fast Travel Sucks](https://www.gamedeveloper.com/design/fast-travel-sucks),
[Fextralife](https://fextralife.com/fast-travel-is-a-plague/), [Stardew Community Center guide](https://www.exitlag.com/blog/stardew-valley-community-center/)).
Riding a caravan you have met is the only fast travel Lowlands needs, and it gives caravans a reason to exist. Keep
it that way.

## Villages as destinations: three palettes, sixteen hooks

Hoenn's 16 towns vary 4–16× in footprint (20×20 to 80×40) and each is tied to a gym or story beat [measured]
([layouts.json](https://raw.githubusercontent.com/pret/pokeemerald/master/data/layouts/layouts.json)). What players
remember is one strong idea per town: Lavender's seven-floor graveyard tower, Ballonlea's fairy forest [opinion, from
search digests; pages 404'd] ([TheGamer](https://www.thegamer.com/pokemon-city-kanto-ranked/)). Scarlet/Violet's towns
without enterable buildings were called boring [opinion, title only]. Barone says each villager is "a ton of work",
which is why Pelican Town stayed small [dev via summary] ([iMore](https://www.imore.com/stardew-valley-may-not-get-another-update-creator-already-thinking-about-his-next-game)).

For Lowlands [inference]: tribe = palette + roof shape + fence (one screen tells you whose land this is); village =
one hook that is a *place* (a hot spring, a flooded quarter, a kennel, a ferry, a shrine to the calamity) + one named
NPC + one local good. The plan's L/M/S tiers already imply 6–8 full villages and the rest hamlets and camps sharing
templates (`world-expansion.md:21-31`), which is the Barone-safe budget. Tie each village to one systemic role
(calamity shelter, caravan hub, hunting lodge, den, market) so it is remembered by function. No study fixes a "too
many towns" threshold; 16 is Hoenn's count with a full studio behind it.

## Wildlife as exploration content

Rain World's creatures hunt and shelter "for themselves" and "outside of your frame they're all still alive" [dev]
([Game Developer: Rain World](https://gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-));
Monster Hunter World's monsters "compete for survival" and turf wars can be used as strategy [dev via digests]
([Gamereactor](https://msn.gamereactor.eu/the-world-of-monster-hunter-interview-with-tsujimoto-and-fujioka/)); Gen 2
designed species for night and gave morning its Bug swarms [measured] ([Bulbapedia: Time of day](https://bulbapedia.bulbagarden.net/wiki/Time_of_day));
Stardew keys forage to map and season [measured] ([Stardew wiki: Artifact Spot](https://stardewvalleywiki.com/Artifact_Spot)).

Two axes are enough: **place and clock** [inference]. Give each biome a signature animal and each day-part a shift
in who is out, and a road walked at dusk is new content. Dan Cook's loops-and-arcs frame says why this matters more in
a shared world: ruins and one-off stories are arcs, consumed once per player; wildlife, forage, prices and calamity
are loops and must carry re-exploration ([Lost Garden](https://lostgarden.com/2012/04/30/loops-and-arcs)).

## Gaps

- No Game Freak statement of a route-length rule or "one new thing per route"; the measurable version is Masuda's
  "no old Pokemon until Route 103".
- Bulbapedia, GDC Vault and GMTK transcripts returned 403; the BotW triangle rule is second-hand reporting of slides.
- Walkable tile counts for Kanto and Hoenn are this report's sums of layout rectangles, not published figures.
- No mobile-specific or Roblox-specific evidence on exploration behaviour exists.
