# 05 · Progression and goals without a quest log: the dead-air diagnosis and the first fifteen minutes

Hub: [README](README.md). Sources: [07-sources](07-sources.md).
Tags: **[measured]** = data, counts, documented mechanics. **[dev]** = a designer saying why. **[opinion]** = a
commentator or this report's inference.

## Takeaway

The theory converges: fun is the feeling of learning a pattern and boredom is the signal that no pattern is being
learned (Koster); keep several half-learned skills live at once and prefer loops over one-shot arcs (Cook);
enjoyment and continued play follow from felt competence, autonomy (a *choice* of goals, not an absence of them) and,
in multiplayer, relatedness (SDT, measured). Lowlands' first week fails this at stage 5: 25–70 minutes of "be inside
by day 7" with no new pattern to learn, which is four to ten median Roblox sessions. The shipped games that refuse a
quest log still hand out goals: Stardew by mail and the mayor, Terraria by who moves into town, Minecraft by an
optional tree of discoveries, Animal Crossing by hiding the total. All of them are compatible with "the compass is a
person, not a log". The missing pieces here are a first interesting moment inside two minutes, one untried thing at a
time, a diegetic "what now" fallback, named rungs on the standing ladder, and loss that becomes the next ask.

## The dead-air diagnosis

| Frame | What it says | Lowlands today |
|---|---|---|
| Koster | "Games grow boring when they fail to unfold new niceties ... boredom is always the signal to let you know you have failed" [dev, via secondary] ([Theory of Fun quotes](https://p4tgiants.notion.site/Theory-of-Fun-18383a0a11a54fa19d9bc1308c0fb470)) | stage 5 unfolds nothing until day 7 |
| Cook, skill atoms | burnout when a player exhausts an atom's uses; keep "several partially-learned atoms active" [dev] ([Chemistry of Game Design](https://lostgarden.com/2007/07/19/the-chemistry-of-game-design/)) | by minute 25 the player has learned walk, stab, sell; nothing new is offered |
| Cook, loops and arcs | arcs "burn out ... rarely desiring to experience them more than once"; "Invent dynamic loops. Build a hobby." [dev] ([Loops and Arcs](https://lostgarden.com/2012/04/30/loops-and-arcs)) | the week is an arc; the hobby (hunt→sell→buy better gear) has nothing to buy (`Items.lua:9-21`: knife only) |
| SDT | autonomy = "meaningful choices regarding goals and strategies"; competence from clear feedback; all three predict continued play [measured] ([PENS](https://selfdeterminationtheory.org/player-experience-of-needs-satisfaction-pens/), [Ryan, Rigby & Przybylski](https://acuresearchbank.acu.edu.au/item/8q128/the-motivational-pull-of-video-games-a-self-determination-theory-approach)) | one forced chain, then none |
| Zeigarnik | unfinished tasks hold attention; MMOs keep the list never done [measured/opinion] ([Psychology of Games](https://psychologyofgames.com/2013/03/the-zeigarnik-effect-and-quest-logs)) | nothing visibly unfinished after "sell a hide" |
| Roblox sessions | P50 6.6 min; D1 climbs with session length to ~19–24 min [measured] ([GameAnalytics 2025 Roblox](https://www.gameanalytics.com/cn/reports/2025-roblox-report)) | the 25–70 min lull spans several whole sessions |

Danzo's own words name it: "a gap between starting and being told to join a caravan and after where im just told
to be inside for 7 days later which is boring" (`docs/plans/first-week-and-toys.md:6-9`). The little brother's verdict
was "kind of boring, I don't know what to do" (`ideas/INBOX.md:149-154`). The hour-twenty version is already recorded:
"Nothing replaces the goal line when it retires" (`docs/RUNG3.md:598-599`).

Quantic Foundry's age data adds a wrinkle: for 13–25s the leading motivation is Competition "with the rest
significantly behind"; Completion and Fantasy lead only at 36+ [measured, relayed via secondary; the blog itself was
403] ([WN Hub](https://wnhub.io/news/analytics/item-11980), [PC Gamer](https://pcgamer.com/study-analyses-gaming-tastes-as-we-age)).
Roblox's largest band is 13–17. Completion goals (a bestiary) will not carry the first week alone; short
competition-flavoured ones (who hunted most this week in Kenstow, who rode furthest) are worth a look even though
they sit oddly with the pillars [opinion].

## A first fifteen minutes that refuses a quest log

Measured: a cliff inside the first fifteen minutes "almost always points to a specific UI failure, a confusing
mechanic introduction, or a difficulty spike" ([VGM](https://vgm.co/blog/what-your-day-30-drop-off-is-actually-telling-you-about-your-game-s-first-hour));
one studio moved the first fun moment 4 minutes earlier and gained 14 points of D7 [single case]
([Bugnet, time to first fun](https://bugnet.io/blog/how-to-measure-player-time-to-first-fun)); Roblox ranks on a <60 s
bounce ([Creator Hub: Discovery](https://create.roblox.com/docs/discovery)). Stardew's first week is six one-verb asks
delivered by mail and Mayor Lewis, with a Help Wanted board of 2-day requests from day 2 [measured] ([Stardew wiki: Quests](https://stardewvalleywiki.com/Quests)).
Nintendo's four-beat structure teaches, develops, twists and drops a mechanic "in about five minutes flat" [dev theory]
([MCV on GMTK](https://www.mcvuk.com/development/video-nintendos-level-design-secrets-in-four-steps)). Klei let Don't
Starve players die and learn rather than tutorialise [dev] ([Game Wisdom](https://game-wisdom.com/?p=3185)).

| Minute | What the player meets | Uses | Status |
|---|---|---|---|
| 0–0:30 | arrow, banner, the survivor calling | built; 30-s test passed (`docs/handoffs.md:52-53`) | done |
| 0:30–2 | **one interesting thing within a screen**: a hare to chase, a dropped bag from the plunder, a wolf at the tree line | `Ecology` spawn weights near Glenworth; bag stamps | new, S |
| 2–10 | the survivor names **three doors** (east road, the hunters, the river); one ask at a time from a person, the next when the last resolves or expires | `Talk.lua:97-107`, `Goals.lua`; H12 Option B (`first-week-and-toys.md:43-97`) | proposed, awaiting Danzo |
| 10–15 | **three loops visible at once**: a short one you can repeat (hunt→sell), a medium one with a visible unfinished state (a ride you were offered, an untried thing), a long one on the horizon (the hall roof of the next village; "Flood in 5 days") | `Ride`, goal line, HUD clock | partial |
| idle 60–90 s | a diegetic "what now": a passing villager's line or the well's talk, generated from real state ("the road east has been quiet since the wolves came") | `Talk` pools, `Barks`, `Gossip`; the guard's `whatnow` topic | new |
| day 2–7 | the calamity warning spreads by people from day 5, not only the day before | H12 B/C | proposed |

Every row keeps P6 (the compass is a person) and PRINCIPLES 1.1–1.6. None adds a log, an arrow or a marker. H12 is
parked for the expansion (`docs/plans/world-expansion.md:97-100`); it touches no WorldGen, so it is the first thing
after, or alongside if Danzo unparks it.

## Cadences: always something near completion

Stardew's trick is structural: ~5 tracks on different clocks so one is always close [inference from measured
structure]: a board quest with a 2-day timer, the next mine elevator 1–4 floors away (120 floors, elevator every 5),
a bundle missing one seasonal item (30 bundles, each room's reward *changes the town*: a bridge, minecarts, the
bus), a festival within ~10 days (12 a year), a villager one gift from a heart ([Bundles](https://stardewvalleywiki.com/Bundles),
[The Mines](https://stardewvalleywiki.com/The_Mines), [Festivals](https://stardewvalleywiki.com/Festivals)). Barone's
intent is a "relaxed pace" that leaves players "invigorated" and he believes "a game can have too much content" [dev]
([WGBH/NPR](https://www.wgbh.org/culture/2025-01-24/the-legacy-and-future-of-the-farming-game-stardew-valley)).

| Clock | Stardew | Lowlands equivalent (existing or cheap) |
|---|---|---|
| Minutes | a board quest | hunt a hide, sell it; a ride leg (7 coin seen) |
| Days | mine floors | the calamity countdown; a village's market or hunt day (06) |
| Week | festivals | the calamity itself; "Floods survived: 3" on the board |
| Month | bundles | standing fades toward neutral every 30 days (`Config.lua:72-76`); a title earned |
| Year | the Community Center | grudges halve per 364 days; a family's child grows up |

The long clocks already run. Nothing shows them. That is the legibility problem of 03 again.

## Progression you can see: people move in

Terraria's 26 town NPCs each arrive when a milestone is hit (50 silver → Merchant; any boss → Dryad; 10% of the
bestiary → Zoologist), several are *rescued* in the world, and happiness sets prices 75–150% and gates fast-travel
pylons [measured] ([Terraria wiki: NPCs](https://terraria.wiki.gg/wiki/NPCs)). This is the strongest match for Lowlands:
**named people moving into a village because of what players did** is progression visible to everyone on the
server, needs no XP, and each arrival opens a loop (a tanner, a ferryman, a bard who repeats gossip) [inference].
It is village *behaviour*, so it waits for a later rung (`world-expansion.md:46-47`), and village growth "by births,
not respawning" is a recorded rule (`docs/design/persistence-and-names.md:39-41`) — an arrival would have to be a
*move*, not a spawn.

Valheim's two reusable ideas [measured] ([AllThings.how progression](https://allthings.how/valheim-progression-guide-every-biome-boss-and-key-drop/),
[Steam raid thread](https://steamcommunity.com/app/892970/discussions/0/3805027459321867430)): a drop that is a *key*
(the reward for a hard thing is permission to do the next), and *progress provokes the world* (raids unlock from what
you have killed). For Lowlands: the calamity's kind or strength keyed to what the server's players have done; the
long goal visible from spawn (Valheim's altar at the world's centre; a great hall or standing stones at the 256 map's
heart that NPCs talk about) [inference].

## Collection, with care

Collection pairs Zeigarnik tension with ownership and works "even with nearly useless rewards such as a digital badge"
[measured/psych] ([Coglode](https://coglode.com/cookbook/pairings/trigger-the-craving-for-completion-by-releasing-something-to-collect));
Palworld opens its 204-entry Paldeck on minute one ([Palworld wiki](https://palworld.wiki.gg/wiki/Paldeck)); Sea of
Thieves builds a whole progression from five-grade cumulative commendations and cosmetics with no stats ([SoT wiki](https://seaofthieves.fandom.com/wiki/Commendations)).
Animal Crossing's designers refused to publish the furniture count so players feel done "when you've collected what
you feel was enough" [dev] ([Nintendo World Report](https://nintendoworldreport.com/feature/42993)).

For Lowlands a bestiary of *where and when* seen (biome, night, calamity) turns the map into a checklist without a
quest, and Terraria's rule makes it social (N entries → the hunters let you ride). Two cautions: PRINCIPLES 2.6 says
you must not be able to answer "what should I be doing", so show what you *have*, never a bar of what you lack
(Nintendo's choice); and `Hud.lua` has no line room, so it is a Tab page after the expansion [opinion].

## A ladder without XP

Bannerlord's clan renown gates six tiers with one concrete permission each (mercenary at 50, vassal at 150, your own
kingdom at 900) [measured] ([Gamer Empire](https://gamerempire.net/mount-blade-2-bannerlord-how-to-increase-clan-tier/));
Rare: "Becoming a Pirate Legend is the core objective ... titles, ranks, and cosmetic items used to represent
themselves to friends and foes" [dev] ([GamesBeat](https://gamesbeat.com/sea-of-thieves-developer-rare-explains-how-the-game-and-its-progression-works/)).
Lowlands already has the rungs (hostile, wary, neutral, welcome, family, `Reputation.lua:16-21`) and already has
permissions on them (caravan bar 15, squad bar 15). What is missing is that nobody *says* the word and other players
cannot see it. Spoken titles in barks and a name-tag suffix make it social progression. P4 ("You get better, your
numbers don't") is untouched.

Kenshi's counter-argument is worth keeping: "too many games let their players succeed"; good stories need obstacles
that cannot be overcome at once [dev] ([Mein-MMO](https://mein-mmo.de/entwickler-verraet-erfolgsrezept-laesst-spieler-leiden/)).

## Death and loss

Valheim: lose the carried, keep the built and the known; six penalty levels added after launch data, not up front
[measured] ([gamever.io](https://gamever.io/knowledge-base/what-death-actually-costs-in-valheim-all-six-death-penalty-settings));
corpse runs are "one of the most reliable sources of shared drama" [opinion] ([Guild Order](https://guildorder.com/games/valheim/wiki/death-recovery-and-group-play)).
Lowlands' rule (wake where you rested, lose carried goods and some standing; the bag is private 5 min and gone in 10,
`Config.lua:40-41`) already matches. The improvement is to make the loss *social* so it becomes the next ask: the
bandit who took your bag carries it visibly; a witness tells you who; the squad offers to ride with you to get it back
[inference]. "Being killed costs nothing" to reputation stays (`docs/design/reputation-and-talk.md:13-22`). No measured
data exists on a Roblox-age audience's tolerance for item loss.

## Homestead

Terraria's room-as-invitation (a walled, lit room with a table and chair brings an NPC) and Grow a Garden's offline
growth are the two cheap transplants; housing-drives-retention claims (SWG, FFXIV) have no published numbers behind
them [opinion] ([Terraria wiki](https://terraria.wiki.gg/wiki/NPCs), [Cinemablend](https://cinemablend.com/games/5-Best-Player-Housing-Systems-Ever-79317.html)).
For Lowlands this is toy #6 ("your camp becomes a place", a save question, `first-week-and-toys.md:108-117`): a camp
with a fence, a fire and a bed that NPCs recognise, visit and trade at; a planted patch that ripens on the world
clock and is reported on return. Later; it is persisted structure (trigger 3).

## Gaps

- Quantic Foundry's own posts were 403; cohort percentages are second-hand and none cover under-13s or Roblox.
- No Barone talk on first-season pacing; "always three things to do" is community language.
- Valheim wikis timed out; raid roll intervals are unverified.
- No Re-Logic statement on why NPC arrivals were chosen as the reward.
- The "73% leave in 24 h / 20% quit in 2 minutes" figures appeared only in search snippets; not citable.
