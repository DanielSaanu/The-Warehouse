# 03 · Emergent stories and legibility: why invisible simulation is worthless

Hub: [README](README.md). Sources: [07-sources](07-sources.md).
Tags: **[measured]** = documented mechanics or a study. **[dev]** = the designer's own words. **[opinion]** = critic,
academic, or this report's inference.

## Takeaway

Lowlands has the raw material the best story generators say matters: named people, families, life and death, trade
and poverty, memory that travels. The problem is the one Tynan Sylvester names: the simulation is running but not
copying into the player's head. Every system the audit lists as "built but silent" (families, farms, ecology counts,
the gossip ring, grudges, mercy, the band's respect, the caravan's missing cargo) is a story that happened and nobody
told. The fix is a *surfacing layer*, not more simulation: faces, lines, marks, a few anchored rivals and friends,
and a sifter that lets only the events that matter speak. That layer has to land inside a Roblox session, where half
of all sessions end before minute seven.

## The core claim

"The whole value of a game is in the mental model of itself it projects into the player's mind ... The Game Model is
irrelevant. Players can't perceive it directly ... anything in the Game Model that doesn't copy into the Player Model
is worthless" [dev] ([Sylvester, The Simulation Dream](https://tynansylvester.com/2013/06/the-simulation-dream/)). His
prescriptions: borrow archetypes (saves exposition), enable projection (a name on a sprite is enough), stakes on
primal values (life/death, alone/together, wealth/poverty), and "the game is a co-author, not an author. It just need
to hint at what is going on – the player's apophenia will fill in details." Flavour that affects nothing ("hair
complexity": nicknames, scars, a one-line past) is cheap and welcome as long as it is *shown*.

Academics agree: raw simulation output "will almost always lack story structure" and the difference between good and
bad emergent narrative is "whether anyone is sufficiently interested to bother curating the output" [academic]
([Emily Short on James Ryan](https://emshort.blog/2019/05/21/curating-simulated-storyworlds-james-ryan/)); 10,000
procedurally unique bowls are still oatmeal if the player cannot tell them apart ([Short on Compton](https://emshort.blog/2016/09/21/bowls-of-oatmeal-and-text-generation/)).

Dwarf Fortress is the proof by counter-example: a dwarf "had depths I would never see"; the famous stories came from
players curating logs [academic/critic] ([if50](https://if50.substack.com/p/2006-dwarf-fortress)). A Roblox audience
will not read logs. Lowlands has to do the curation itself.

## Lowlands' silent systems (from the repo audit)

| System | What it computes | What the player can see today | What would make it a story |
|---|---|---|---|
| Families | parents, children, surnames, succession | pregnant/baby sprites, an occasional "family news" line, headlines on return | "You killed my father" is a lookup the design promises (`docs/design/persistence-and-names.md:27-29`) and nothing speaks it |
| Farms | growth, harvest into stock | prices move | a villager carrying a sack; "good harvest this year" |
| Ecology counts | real per-region animal numbers | the animals you happen to meet | a hunter saying "the deer are gone from the east wood" |
| Gossip ring | rumours with hops and fade | guard's "me" topic, standing notices, join-refusal reason | any villager referencing the newest rumour about you by name |
| Grudge | holder grudges, `AMEND_GIFT` | nothing | an NPC naming the grudge and what would settle it |
| Witness / Sides | who saw, who turned out | one line per fight | an eye over the witness; the line spoken by a named person |
| Mercy +3, band respect +2 | real reputation rules | nothing (`docs/design/reputation-and-talk.md:17-23`) | "He let me go. Tell the others." |
| Caravan | walks Glenworth↔Kenstow | a merchant walking | sacks on the road; a village short because it was robbed |

Lowlands' own research lists "hidden rules" among the joining traps (`docs/research/belonging-joining.md:157-169`).
Mercy and respect are hidden rules today.

## The surfaces that work in shipped games

| Surface | Example | Tag |
|---|---|---|
| A visible witness | RDR2 marks the NPC who saw a crime with an eye icon, white or red depending on whether they can identify you | measured ([RDR2.org](https://www.rdr2.org/wiki/wanted-system/)) |
| Memory in greetings and prices | RDR2: "even after the bounty disappears, people will still hold it against you"; Fable villagers praise or flee by renown | measured ([Gry-Online](https://www.gry-online.pl/opinie/niesamowite-detale-red-dead-redemption-2-gra-dopracowana-jak-zadn/zywy-zachod/zc6cc), [Fable wiki](https://breezewiki.discard.no/fable/wiki/Renown)) |
| A few anchored rivals with marks | Nemesis: "find the peak kind of anchors for people to latch on to"; scars on faces; a line naming what you did | dev ([GamesBeat, de Plater](https://gamesbeat.com/shadow-of-mordors-nemesis-system-draws-from-burnout-football-and-an-architecture-book/)) |
| Face + traits + one meter + a choice | CK3 wants players to "perceive and remember stories – their own stories" | dev ([CK3 Dev Diary 0](https://forum.paradoxplaza.com/forum/threads/ck3-dev-diary-0-the-vision.1265472/)) |
| The game draws the retelling | Wildermyth tells each beat as a comic panel; legacy heroes return | dev ([Wikipedia: Wildermyth](https://en.wikipedia.org/wiki/Wildermyth)) |
| A notebook of people | Majora's Mask 3D rebuilt the Bombers' Notebook because Miyamoto found players finished without noticing the town's events | dev, reported ([Zelda Dungeon](https://www.zeldadungeon.net/aonumas-what-in-the-world-list-guided-majoras-mask-3ds-development/)) |
| A visible countdown | Rain World's rain pips, 30 s each, bottom-left | measured ([Rain World wiki](https://rainworld.miraheze.org/wiki/Rain)) |
| Threat you can hear | Rain World scales threat music in ~10 steps per level and de-ramps when you escape | dev ([Kill Screen](https://killscreen.com/the-threat-music-and-animal-sounds-of-rain-world)) |

The Nemesis postmortem is also the warning: the system grew into factions, morale bars and a hierarchy "like a
Christmas tree" and had to shrink back to "personal villains" [dev] ([GameBanshee postmortem](https://www.gamebanshee.com/k3axd)).
Lowlands' witnesses and gossip are the un-anchored middle. Elect a few: when a plunderer survives you, or your knife
kills someone's brother, that one NPC becomes a named rival with a mark and a line.

On the Nemesis patent (not legal advice): US 10,926,179 claims a chain where an interaction with NPC A changes NPC B's
parameters in a hierarchy, then displays them; the examiner first rejected it as obvious over Crusader Kings II and
Arkham ([Patent Arcade](https://www.patentarcade.com/video-game-patent/US10926179/nemesis-characters-nemesis-forts-social-vendettas-and-followers-in-computer-games)).
"An NPC remembers you and says so" is prior art. Keep Lowlands' shape as it is: your act marks the NPC you acted on,
and gossip (already existing) spreads it. No promotion ladder.

## A sifter, not a firehose

Kreminski, Wardrip-Fruin and Mateas propose *story sifters*: score simulation output by what makes a compelling
narrative and surface only that [academic] ([arXiv](https://arxiv.org/pdf/2304.08293)). Lowlands' gossip ring already
*is* a transport; it lacks the scoring and the mouth. Proposal [inference]:

- Score each world event by stakes (death > theft > gift) and by proximity to the player (their village, a name they
  know, a group they rode with).
- Only the top few per session surface: a spoken line from a named person, a one-line notice, or the return card.
- Everything else stays as hair. The ring of 64 and S1 ("a capped list can be a memory, but never a ledger",
  `docs/learnings.md:52-55`) are the right constraints; the sifter decides what gets a voice, not what gets stored.

Skyrim's Radiant Story is the counterweight: 30 systemic reactions worked as *texture*, but "players expected us to
use our creativity to create content they want to experience. If we pass the buck to a system, it's not the same"
[dev] ([GamesBeat, Nesmith](https://gamesbeat.com/bethesdas-nesmith-reflects-on-the-difficult-birth-of-skyrims-radiant-story-system/)).
Shadow of Mordor hired a novelist for the orcs' lines because procedural variation alone read as "gimmicky" to a
critic ([Wikipedia: Shadow of Mordor](https://en.wikipedia.org/wiki/Middle-earth:_Shadow_of_Mordor)). Budget hand-written
lines for the ten most common surfaced events. The audit already flags that talk is canned per tribe type and will
read as such at two dozen villages (`docs/systems/talk-and-trade.md:45-47`).

Watch Dogs Legion is the warning for 16 villages of generated people: "each of these characters may sport an
in-depth bio ... none of that will translate over to how these characters act" [opinion] ([Push Square](https://pushsquare.com/reviews/ps4/watch_dogs_legion)).
A people page is not a personality. NPCs need to *act* differently (the coward flees at the first blow, which Lowlands
already does for villagers; the braggart should say so).

## Pacing: the storyteller and the lull

RimWorld's storytellers pick events from "colony wealth ... if a colonist has died ... and how long it has been since
the last major event"; Cassandra "will push you with dangerous events, then give breathing room, then come back"
[measured mechanics] ([RimWorld wiki: AI Storytellers](https://rimworldwiki.com/wiki/AI_Storytellers)). Sylvester:
"making the events last a long time helps [interaction] happen as often as possible" [dev] ([Game Developer](https://gamedeveloper.com/design/how-i-rimworld-i-fleshes-out-the-i-dwarf-fortress-i-formula)).

Lowlands' weekly calamity is a Phoebe-style beat (long breaks). The gap is between beats. A lull-breaker that tracks
time-since-anything-happened per player and nudges an existing group or pack toward the road they are on is the
RimWorld transplant [inference]. **It bends P1** ("The world does not need you", `docs/design/pillars.md:8`) and
brushes the avoid-list's "scripted ambush points" (`docs/plans/rung3-part4-belonging.md:115-116`). It is defensible
only as *routing* of things that already move, never as spawning for the player, and it needs a ruling (trigger 1).

Rain World's failure mode is the cost of not pacing: "the RNG wasn't with her ... a bunch of no-win situations ...
really early on" [dev] ([Game Developer: Rain World](https://gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-)).
A first-week player hunted while still learning is that streamer.

## Reputation: hidden number, visible world

Dishonored's binary chaos "often trapped players in binaries"; the sequel weighted people individually [dev]
([Wccftech](https://wccftech.com/dishonored-2s-chaos-system-implications-explained-game-director/amp/)). Lowlands'
per-holder standing with three tribes judging the same act differently is already better than one bar. RDR2 shows
its meter and nobody minds; Lowlands' five words (hostile → family, `Reputation.lua:16-21`) can stay the display as
long as NPCs *speak* them and other players can see them (a Sea of Thieves title "to represent themselves to friends
and foes", [GamesBeat, Rare](https://gamesbeat.com/sea-of-thieves-developer-rare-explains-how-the-game-and-its-progression-works/)).
Kenshi's world-state system reacts to deaths of notable people by spawning places or changing who holds a town
[measured] ([Wikipedia: Kenshi](https://en.wikipedia.org/wiki/Kenshi_(video_game))) — the ancestor of Lowlands'
"killing the chief does not end the tribe" rule (`docs/design/long-arc.md:79-87`).

## Multiplayer stories without PvP damage

EVE's founders: "for value to exist, you must have scarcity and effort; and for a community to be truly meaningful,
it mustn't be fragmented" [dev, reported] ([PCGamesInsider](https://www.pcgamesinsider.biz/industry-icon/65949/the-making-of-eve-online/));
Rare's motto is "tools, not rules" [dev] ([MCV](https://mcvuk.com/development-news/when-we-made-sea-of-thieves/));
Valheim caps servers at 10 and its magic is "shared memories" [opinion] ([KeenGamer](https://www.keengamer.com/articles/features/opinion-pieces/21-best-cooperative-survival-games-like-valheim/)).
With no PvP damage, the scarcity lever is usable in PvE form: a caravan's cargo, a village's food, a squad's catch
are shared stakes that make other players' acts visible ("someone robbed the Kenstow caravan last night"). Route
hostility through the simulation (plunderers, witnesses, tribe standing) so it is legible and has a cost.

## The session window

Roblox 2025 session percentiles: P25 2.4 min, **P50 6.6**, P75 14.5, P90 26.4; median D1 climbs from 4.3% for 0–3
minute sessions to 11.5% at 19–24 minutes [measured] ([GameAnalytics 2025 Roblox](https://www.gameanalytics.com/cn/reports/2025-roblox-report)).
Compressing drama into that window, from the sources above [inference]: one beat per ~5 minutes for a player with
nothing happening; an always-visible countdown to the next big event; a login card that says what the world did while
you were gone; a few anchored faces so the story resumes with a person; a one-panel "chronicle" entry the player can
screenshot (Wildermyth's idea, cheap in a pixel pipeline). The cheapest session extender is a visible "the caravan
leaves in 4 minutes".

## Gaps

- Tynan's GDC 2017 slides, the Nemesis GDC talks and the Kreminski retellings PDF were only reachable as summaries.
- No quantitative study of how many simulated events players notice.
- No developer source on Gothic-style NPC reactions or Skyrim's rumour lines specifically.
- Nothing found on how emergent-narrative games perform with under-13 players.
