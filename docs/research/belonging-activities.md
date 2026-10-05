# Belonging: what you do once you are in a group

Research for [RUNG3 part 4](../RUNG3.md) (ride with a caravan, hunt with a squad, ride with a band). Question:
once a player is a member, what jobs, roles and shared activities make group life fun minute to minute? Written
2026-10-05. **Not decisions**: candidates, judged against [PRINCIPLES](../PRINCIPLES.md) (systems not content;
judge a thing by how many systems it touches) and the controls (move, left click attack, F interact, phone-first).

## What exists today (the base to build on)

From [`Bands.lua`](../../roblox/src/server/Bands.lua), [population](../systems/population.md),
[combat](../systems/movement-and-combat.md), [talk](../systems/talk-and-trade.md),
[gossip](../systems/reputation-and-gossip.md):

- A group is a record: `members` (named people), `from`/`to` route, `pos`, `dir`, `pauses`, `carry`,
  `retreatUntil`. Bodies only near a player. The leader walks the route; others keep within 2 tiles.
- Caravan = master + 2 guards (farmers to hunters). Squad = 4 hunters (village to the best forest region).
  Band = 4 bandits waiting part way down the farm road, moving further down after `GRACE_DAYS`.
- A kill by a member goes into `g.carry`; at `SQUAD_LOAD` (8) the squad turns home; home, `carry` goes into the
  village stock. A fed hunter stops hunting for `FED_HUNTER`.
- A band breaks at more than half lost and runs for home for `BAND_RETREAT`.
- Witnesses take sides; every kill or escape becomes a rumour carried by groups; `Grudge.GROUP = 0.25` is
  already the share of a grudge for harm done while riding along.
- F talks to the caravan master; F places a camp and picks up a bag (bags are private to the owner for half a day).

Danzo's tribe notes (`ideas/INBOX.md`): farmers = coordination, defensive, timid, "get the goods home"; hunters =
strongest individually, tight team chemistry, short trips every week or two; plunderers = weakest, guerrilla,
"sudden and brutal", wary of big caravans, large bands extort rather than destroy.

---

## Cases

### Mount & Blade II: Bannerlord (caravan escort, raids)
- **What.** A town merchant hires you to escort a caravan through three settlements; "at least one fight between
  each". Bandits and the player can attack caravans or villagers, or force them to hand over part of their goods.
  Raiding a village transfers its stock to you over time.
- **Why fun.** The caravan moves on its own route; your only job is to stay close, so the ambush finds *you*. Pay
  drops if the caravan takes damage, so being near is the skill. Ambush spots are geography: bandits catch
  caravans at narrow passes. Extortion ("hand it over") is a third option between fighting and leaving.
- **Shortcomings.** Escort is mostly waiting; players say "let bandits hit it first, then ride in" (a degenerate
  best play). Raiding wrecks relations so hard that bandit play is a dead end for anyone who wants a fief.

### Kenshi (caravans, hauling)
- **What.** Trader caravans walk between towns with guards; bandit factions (Dust Bandits, Starving Bandits) hit
  them. Carrying is physical: backpacks, encumbrance, trader packs that stack goods, carrying a downed squadmate.
- **Why fun.** You can just walk next to a caravan and its guards fight for you ("like free mercs"). Weight
  makes a hauler a real role: a laden character is slow and fights worse, so someone else has to guard them.
- **Shortcomings.** Hauling is busywork when it is only inventory tetris; the fun comes from the risk while laden.

### Battle Brothers (contracts, ambush)
- **What.** Escort-caravan contracts; the company walks with the wagons and fights whatever comes. Fights start
  with formations; an ambush puts you in the worst one.
- **Why fun.** The ambush is the whole drama: who saw it first decides the first turn.
- **Shortcomings.** Escorts are "fairly easy and often have no fights at all", or a chain of waves with no rest.
  Players call bandit play "gimmicky" because the world stops serving you.

### Monster Hunter (hunts)
- **What.** Prepare (eat a meal for buffs, bring traps), **track** (footprints and gashes; scoutflies learn a
  monster and need fewer tracks next time), fight, then **capture or kill**, then **carve**. Support Palicos
  (the NPC buddy) have explicit jobs: Assist sets traps, Gathering picks up extra materials, Healer heals,
  Fight fights.
- **Rewards and blame.** Three faints per party, shared. Any cart cuts *everyone's* money; the third fails the
  quest. Loot is per player: carving on your screen never takes from mine.
- **Why fun.** Tracking turns the walk out into a game. Shared faints make the group cautious without talk, and
  a wipe gets "a laugh and a plan", not blame. Personal loot removes the race to the corpse.
- **Shortcomings.** The carry who dies is a cost to all, which can turn sour with strangers. Tracking is repeated
  each hunt and becomes routine once a monster is "known".

### Sea of Thieves (crew)
- **What.** Helm, sails, map below deck, lookout, cannons, repair and bail. **No class system**: roles exist
  because the helm cannot see forward and the map is below deck. "More jobs than people."
- **Rewards and blame.** Treasure sold by anyone pays every crew member in full. The brig vote locks a
  troublemaker up, but the jailed player is still paid.
- **Why fun.** Information is split across positions, so talking is the mechanic. Roles are picked, swapped
  and abandoned freely.
- **Shortcomings.** The brig was abused by three friends locking up the random fourth. Sitting at the helm is
  boring when nothing happens.

### Deep Rock Galactic (division of labour, few buttons)
- **What.** Four classes, each with one tool that fixes another's problem: the Scout lights caves and reaches high
  ore, the Engineer builds platforms, the Driller cuts shortcuts, the Gunner gives ziplines and cover. Everyone has
  a pickaxe and a gun. **Molly the M.U.L.E.** is a walking team stash: anyone deposits, everyone is paid.
- **Why fun.** Each role is one button that visibly helps someone else. Nothing is locked if a class is missing;
  it is just slower. The shared mule removes "who carries the loot".
- **Shortcomings.** Ghost Ship say they do not balance classes like a PvP game; some missions favour a class.

### Valheim / Don't Starve Together (group trips)
- **Valheim.** Ore cannot go through portals, so a trip for metal needs a boat or a cart: one player sails while
  the others portal ahead and dig. A forward camp turns many trips into one.
- **DST.** Characters lean into jobs (Wigfrid fights and eats meat; Wickerbottom farms fast); the experienced
  player keeps base. Shortcoming: on public servers griefers burn the shared base and Klei treats it as a
  playstyle, so the only fixes are vote-kick, rollback or friends-only.
- **Lesson.** A carrying constraint creates roles for free; a shared, burnable store invites griefing.

### Roblox: Jailbreak, Bloxburg, Tradelands, Deepwoken
- **Jailbreak.** Two sides with opposed jobs (police arrest for cash, criminals rob). Few tools, each one verb
  (cuffs, taser, spike strip). Fun because the jobs collide in real time. Criticised as stagnant over years.
- **Bloxburg jobs.** Solo minigames (pizza delivery, fishing) for money, levelled by repetition. Called "boring and
  tiresome"; the best-paying job dominated. Flattening all job pay caused a public protest: players want effort and
  skill to show in pay.
- **Tradelands.** Merchant, pirate, navy on one sea: prices differ per port, pirates hunt trade routes, navy
  protects. The closest Roblox match to our three tribes; the crew mostly works the guns and sails together.
- **Deepwoken.** Guilds give benefits without painting a target on each member; war mode is guild against guild.
  Little on party loot rules (sources thin; treat as weak evidence).

---

## What the cases agree on

1. **The group moves on its own; the player's job is to be useful near it** (Bannerlord, Kenshi, Battle Brothers).
   We already have this: the route runs without the player.
2. **Roles come from a constraint, not a class menu** (Sea of Thieves sight lines, Valheim ore, Kenshi weight). A
   role you choose by standing somewhere is phone-friendly: no new button.
3. **One verb per role, aimed at a teammate's problem** (DRG, Palicos, Jailbreak).
4. **Share failure collectively, loot personally or as one pot** (MH faints, MH carving, Sea of Thieves gold, DRG
   mule). Racing for drops is the main griefing source in co-op.
5. **Escort is waiting unless something can be spotted** (Bannerlord, Battle Brothers). The fix is an early
   warning that someone has to earn.
6. **The world must keep serving the bad side** (Bannerlord raiding, Battle Brothers bandits). A band rider needs
   somewhere that still trades with them.
7. **Pay that ignores effort is resented** (Bloxburg). Shares should read what you did.

---

## Synthesis for Lowlands

Two tags: **[exists]** = the current systems can do it (maybe a Talk line or a Config number);
**[new]** = needs new machinery. "NPC does it" is what a member already does or could do, so the player copies it.

### Shared rules for all three groups

- **Joining and leaving** stays a conversation (RUNG3 part 4). The player becomes one more entry in `members`
  with `person = nil` and a player ref. **[new]**: a member that is a player, and the group must stay materialised
  while a member player is in it.
- **Roles are where you stand, not a menu.** Ahead of the leader = scout/lookout; beside the master or packer =
  guard; carrying = packer. The server reads distance to the leader. No button. **[new]** (small: a role tag from
  position, read at payout).
- **Pay is a pot, split at the end of the route.** `carry` already is the pot. At `deposit`, members present get a
  share of its value (coin) and the village gets the rest of the stock. Players who left halfway get nothing and
  the master remembers. **[new]** (split at `deposit`; coin to players). This is the DRG mule / Sea of Thieves model,
  so nobody races for a corpse.
- **Blame is shared like Monster Hunter's faints.** Each member lost on the trip cuts everyone's share (a third
  each, say). Running away from a fight is the one personal mark: four witnesses carry it home. **[exists]** for
  the rumour (witnesses, gossip); **[new]** for the share cut.
- **The grudge spreads**: harm done while riding along puts `Grudge.GROUP` (0.25) on you. **[exists]**.
- **Griefing guard.** No member can hurt another member (same `group` = friendly). Loot from a kill goes to the
  pot, never to the fastest picker. Do not add a shared stash anyone can empty (DST). **[new]** for the
  friendly-fire rule if combat does not already skip same-group; check.

### Caravan (farmers: coordination, "get the goods home")

| Role or activity | How it plays | NPC does it | Tag |
|---|---|---|---|
| **Guard** | Walk beside the master; fight anything that targets a caravan member. Pay cut per member lost, like Bannerlord. | The two `caravan_guard`s already fight back. | **[exists]** (fighting) + **[new]** (share) |
| **Scout / outrider** | Walk a few tiles ahead. When you are the first to see the band (within range of a band body), the caravan gets a warning line and **halts and bunches** before the hit. Turns escort-waiting into watching. | A guard could walk ahead on the road; today they keep 2 tiles from the leader. | **[new]** (warning + halt; `pauseUntil` already halts) |
| **Packer** | Carry goods for the master: F at the master takes a pack into your 10 slots, and it is paid at the far end. Laden = a target: the band goes for whoever carries. | Master carries `g.carry` today. | **[new]** |
| **Haggling at the far end** | On arrival the master sells; a player with good standing at that village gets a better price for the pot (`priceMult`). Your reputation becomes a group asset. | Master sells at the endpoint today via `deposit`. | **[exists]** (`Reputation.priceMult`) + **[new]** (apply it to the pot) |
| **Make camp** | At a pause, F places a camp that keeps wolves off the caravan (`CAMPFIRE_RADIUS`). | Nobody camps yet. | **[exists]** (camps) |

**Start with:** guard + the pot split at arrival (the RUNG3 "done when" already needs it), then the **scout
warning** (one rule, turns the dull middle of the walk into a job).

### Squad (hunters: individual skill, team chemistry, short trips)

| Role or activity | How it plays | NPC does it | Tag |
|---|---|---|---|
| **Tracker** | The squad walks to a forest region; a tracker who finds deer/boar first (comes within range of an animal body) turns the squad toward it. Like MH tracks, but the clue is real animals from `Ecology` counts. | Hunters already go for animals in range (`Sides.preysOn`). | **[exists]** (hunting) + **[new]** (squad follows the tracker) |
| **Beater** | Drive game toward the others: deer flee from you into the hunters' range. Needs animals to flee from players along a direction. | None. | **[new]** (flee direction); skip at first |
| **Fighter** | Hit what the squad hits. Kills already go into `carry`. | All four hunters. | **[exists]** |
| **Carrying the kill** | At `SQUAD_LOAD` the squad turns home. A player can take part of the load (more trips, a bigger haul) and is slower or a target while laden. | `carry` is abstract today. | **[exists]** (turn home) + **[new]** (a player carrying) |
| **Wolf duty** | Wolves go for a laden squad on the way home; someone guards the carriers. | Everyone armed wants a wolf dead already. | **[exists]** |
| **Not running** | Running from a fight is seen by four hunters who are home tonight (RUNG3). | Witnesses. | **[exists]** |

**Start with:** fighter + the pot split at home (hides and meat to the village, a coin share to you), plus the
"ran away" rumour that already works. Second: **tracker** as "the squad follows whoever finds game first" (one
rule on the leader's target).

### Band (plunderers: weakest, guerrilla, sudden and brutal)

| Role or activity | How it plays | NPC does it | Tag |
|---|---|---|---|
| **Lookout** | Stand off the road ahead of the band's waiting spot. When a caravan or a player comes within range of you, the band is told and gets set (bodies out of sight, then all charge at once). A guerrilla ambush is a timing game. | The band waits at `alongRoad` and paces today. | **[new]** (warning to the band) |
| **Ambusher** | Hide off-road (forest tile), charge when the lookout calls. The first strike lands before the caravan can bunch, the mirror of the caravan scout. | Bandits target players in range. | **[exists]** (charging) + **[new]** (hide spot) |
| **Extortion** | Instead of fighting, F the caravan master with the band behind you: he hands over part of `carry` and walks on. Danzo's "extort and let go" for large bands; no deaths, smaller grudge. | None yet; RUNG3 part 5. | **[new]** (part 5 overlaps) |
| **Split of the loot** | Loot from the hit goes into the band's `carry` and is split at the camp, not grabbed at the scene. A bandit who grabs first breaks the band's code: the band's standing for you drops. | Band kills go to `carry` already. | **[exists]** (carry) + **[new]** (split, the "grab" penalty) |
| **The break and run** | At half lost the band runs (`BAND_RETREAT`); the player can run with them or stay. Staying is brave and remembered. | All bandits. | **[exists]** |

**Start with:** ambusher (ride with the band, it charges what you charge) + loot into `carry` split at the band's
village. Then the **lookout warning**, which is the same rule as the caravan scout seen from the other side: build
one "first to spot it warns the group" rule and both get it.

---

## Most for least (the recommendation)

1. **The pot and the split at the route end, with a shared penalty per member lost.** One rule in `deposit`
   serves all three groups, kills loot racing, and is the RUNG3 "done when". (MH, DRG, Sea of Thieves.)
2. **"First to spot it warns the group"**: a member within range of a hostile group's body triggers a halt and a
   line. It is the caravan scout, the band lookout, and (pointed at animals) the squad tracker. One rule, three
   roles, no new button, chosen by where you walk. (Sea of Thieves, Bannerlord passes.)

Everything else (packer, beater, extortion, haggling bonus) waits until those two are fun in Studio.

## Open questions for Danzo

- Does a player member get coin, goods, or both from the split? (Coin is simpler; goods touch the 10 slots.)
- Can a player lead a group, or only join? (Long-arc §"raise groups" implies yes, later.)
- Should a band rider who grabs loot at the scene lose band standing? It is the plunderer "code"; a guess.
- Is the caravan really the farmers' only group, or do mid tribes also run small ones (INBOX says only the
  strongest)? Affects how often a player can ride along.

## Sources

- Bannerlord escort quest: https://gamerguides.com/mount-and-blade-ii-bannerlord/guide/campaign/quests/escort-merchant-caravan
- Bannerlord ambush passes and tactics: https://steamcommunity.com/app/261550/discussions/0/2144217924381912701
- Bannerlord raiding and relations: https://steamcommunity.com/app/261550/discussions/0/5696507684097033060 ;
  dev blog on actions and consequences: https://gamebanshee.com/khpcr
- Kenshi caravans as escorts: https://steamcommunity.com/app/233860/discussions/0/3162083441797108070
- Kenshi backpacks and encumbrance: https://kenshi.fandom.com/wiki/Thieves_Backpack
- Battle Brothers contracts dev blog: https://www.moddb.com/news/dev-blog-26-contracts-and-greenlight-update
- Battle Brothers escort discussion: https://steamcommunity.com/app/365360/discussions/0/5296777170374972855 ;
  https://steamcommunity.com/app/365360/discussions/0/4706830261921426030
- Monster Hunter shared faints: https://hostedgg.com/blog/monster-hunter-carting-culture ;
  https://game.capcom.com/manual/MH4U/en/page-46.html
- Monster Hunter loot and carving: https://mp1st.com/features/multiplayer-games-you-might-have-missed-week-4-monster-hunter
- Monster Hunter scoutflies: https://monsterhunterworld.wiki.fextralife.com/Scoutflies
- Monster Hunter capture vs kill: https://www.gamerevolution.com/guides/365207-monster-hunter-world-capture-vs-kill-rewards-get
- Palico support types: https://gamerjournalist.com/palico-support-types-in-monster-hunter-rise/
- Sea of Thieves roles: https://www.roadtovr.com/7-lessons-sea-of-thieves-can-teach-us-about-great-vr-game-design/2 ;
  https://www.thesixthaxis.com/2017/08/31/sea-of-thieves-or-learning-that-a-lack-of-communication-can-get-you-killed/
- Sea of Thieves gold and brig: https://seaofthieves.wiki.gg/wiki/Player_Pirates
- Deep Rock Galactic classes: https://www.ggrecon.com/guides/best-deep-rock-galactic-classes/ ;
  https://gamingbolt.com/deep-rock-galactic-interview-heigh-ho-off-to-plunder-we-go/amp
- Deep Rock Galactic M.U.L.E.: https://deeprockgalactic.wiki.gg/wiki/M.U.L.E.
- Valheim ore and portals: https://www.pcgamesn.com/valheim/ore-portal
- Don't Starve Together characters: https://dontstarve.wiki.gg/wiki/Characters/DST
- DST griefing on public servers: https://forums.kleientertainment.com/forums/topic/142087-what-are-your-thoughts-on-the-griefing-playstyle-on-klei-pub-servers/
- Jailbreak: https://roblox.fandom.com/wiki/Badimo/Jailbreak ; https://www.pcgamer.com/roblox-jailbreak-guide/
- Bloxburg jobs: https://progameguides.com/roblox/best-paying-jobs-in-roblox-welcome-to-bloxburg/ ;
  review: https://forum.arcaneodyssey.dev/t/an-honest-review-of-roblox-games-part-one-bloxburg/67400 ;
  pay protest: https://www.404media.co/roblox-community-protests-communism-update
- Deepwoken guilds and war mode: https://deepwoken.fandom.com/wiki/War_Mode
- Tradelands (secondary, thin source): https://ec.farotech.com/?p=20758
