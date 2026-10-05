# Research: guidance through people, not logs (for Part 4, Belonging)

Written 2026-10-05 for RUNG3 Part 4 ("Belonging") and the elder's "what now" (DESIGN §12 in
[`../design/long-arc.md`](../design/long-arc.md)). This is research, not a decision.

**The question.** When a player joins a group (caravan, hunt squad, band), Danzo wants it "made slightly obvious
what to do when they're there". How do other games point players through the world, NPCs and companions instead
of quest logs and markers?

**What we judge it against.** [PRINCIPLES](../PRINCIPLES.md) 1: the compass serves two moments, the **first
minute** (one direction, from a character, within ~30 s) and the **lost minute at hour twenty**. It points, it
does not choreograph (1.3), never scolds (1.2), and is answered by a person who can be wrong, biased or dead (1.6).
Our limits: 16x16 tile grid, phone-first Roblox, text notices and talk topics. No quest log, no arrows, no join
menu. Joining is a conversation ([RUNG3](../RUNG3.md) Part 4); talk runs through F and topics
([talk-and-trade](../systems/talk-and-trade.md)).

---

## Part 1: the cases

### Companions who show rather than tell

**The Last of Us: Ellie**
- What: a companion who stays at your side, comments on what she sees, and helps in fights.
- How: her movement keeps her near Joel. Some lines (her shock at a clicker) only fire when Joel is within about a
  metre, so you are there to hear them. In stealth, enemies cannot see her, so she can never give you away.
- Why it works: the rule was "you can never hate Ellie". She is useful (throws bottles, hands over health packs)
  but never a liability, and her lines arrive when you are looking.
- Shortcomings: invisible-to-enemies breaks realism (she runs in front of a guard and nothing happens). When she
  got a gun she was too good and had to be held back.
- For us: **a member must never make the player fail**, and a bark only counts if the player is near enough to
  see who said it.

**Half-Life 2: Alyx Vance**
- What: a companion who fights beside you and gives advice at key moments.
- How: Valve tuned her so she helps without making the player feel useless, and advises without sounding bossy.
  The Episode One commentary records playtest-driven changes to her behaviour (the turret scene).
- Why it works: she sees and reacts to the same things you do, so her advice reads as observation, not orders.
- Shortcomings: tightly scripted and linear. It works in a corridor and is expensive to author.
- For us: tone matters as much as content. "Wolves on the left" is an observation; "Go kill the wolves" is an order.

**Journey: the stranger**
- What: a second real player, no voice, no text, only a chirp and their body.
- How: a shared landmark (the mountain) means both players already know where they are going. A short chirp calls
  attention; a long one says "follow". You can engage or drift apart with no menu. Players who have seen everything
  (white robes) wait for newcomers, lead them to secrets, and chirp at them.
- Why it works: **the destination is never in doubt, so the companion only has to show the detail.** Guidance by
  someone walking ahead of you needs no words.
- Shortcomings: almost no bandwidth. It only works because the goal is one mountain visible from everywhere.
- For us: "walk ahead and look back" is the strongest signal there is, and it fits a tile grid exactly.

**Red Dead Redemption 2: gang rides**
- What: missions where you ride with gang members while they talk, then arrive at the action.
- How: the ride is filled with conversation, so the walk to the job is where the story and the gang's character
  live. You follow the leader's horse; there is a cinematic follow camera.
- Why it works: the dead time of travel becomes belonging. You learn who these people are by riding with them.
- Shortcomings: the most criticised part of the game. Missions fail you for leaving your horse early, waiting
  outside too long, or straying slightly off the path. The open world says "do anything"; the missions say "do
  this exactly". Players call it formulaic: ride, listen, shootout.
- For us: **take the ride, leave the fail states.** Lowlands' pillar 5 already says you may leave halfway.

### Open-world guidance

**Breath of the Wild: landmarks and the Great Plateau**
- What: no route; a world arranged so the next interesting thing is always visible.
- How: Nintendo first tried towers connected by roads. Playtests split into two groups: about 80% followed the
  route dutifully, 20% wandered randomly. They replaced it with many landmarks (shrines, stables, camps) and the
  "triangle rule": hills hide what is behind them and reveal it as you crest, so you see one new thing at a time.
  The Great Plateau is a fenced-in miniature of the whole game. One old man gives you a few loose goals; you learn
  cooking, climbing and cold by doing them.
- Why it works: after the change, players followed curiosity, and "almost all players eventually got to the key
  locations". This is principle 1's "build the reasons first" proven at scale.
- Shortcomings: it needs a lot of distinct, visible content; and a scripted route was what 80% of players took
  when offered one. Most people will follow a line if you draw one.
- For us: a **moving group is itself a landmark** that draws a line without being a route.

**Outer Wilds: curiosity with no missions**
- What: no objectives at all; progress is knowledge.
- How: the design goal was motivating exploration through diegetic, player-chosen direction, not missions. The ship
  log records rumours as a web of question marks: "there is more to explore here", never "go here next".
- Why it works: it records what you heard, not what you must do. That keeps the mystery while curing forgetting.
- Shortcomings: some players bounce off hard with no direction; the log is still a menu.
- For us: the elder can do in speech what the rumour log does on paper: **repeat what you have heard and not
  followed up**, from the village's knowledge bank.

**Elden Ring: grace and NPC hints**
- What: sites of grace show a faint beam toward the next major boss; NPCs and player messages hint the rest.
- How: guidance is a suggestion; NPCs are part-lore, part-direction, and some lie (Varre).
- Why it works: lying, biased guides make the advice part of the world, exactly like our elder.
- Shortcomings: players report the beam pointing somewhere confusing or already done. Melina only appears after
  three graces, so newcomers missed levelling and called it unfair. **A guide that arrives late is no guide for the
  first minute.**
- For us: a wrong elder is a feature only if the first minute is already safe.

**Ghost of Tsushima: the guiding wind.** No minimap; a swipe calls wind that bends grass toward your target, and
golden birds and foxes lead to side places. The pointer lives in the world and appears only when asked, but it is
still a marker in costume (the target is picked on a map). For us: the thing that leads should be a person.

### The over- and under-guided ends

**Ocarina of Time: Navi (too much)**
- What: a fairy who interrupts with "Hey! Listen!" and advice.
- How: limited time meant simple advice, so she repeats it and points out the obvious, often pausing play.
- Why it fails: repetition, interruption, and no memory of what you know. Miyamoto called the Navi advice system
  "the biggest weakpoint" of the game, but kept her because returning players would be lost without her.
- For us: **every bark needs memory** (do not say it twice in a row, stop saying it once learned) and **must never
  pause play**.

**Rain World (too little)**
- What: almost no teaching; the rules, the progression and the point are left unexplained.
- How: the only guide is an overseer that projects symbols (shelter, food, "go this way") when near, and **appears
  less and less over time**.
- Why it fails for many: brutal difficulty on top of opaque rules. Critics call it a game that hides its
  mechanics too much; many players never find the point.
- For us: the fade-out is right; the starting dose was too low. Start clear, then fade.

### 2D and top-down

**Stardew Valley.** Two named people (mayor, carpenter) greet you, letters arrive, and the broken community centre
sits in town with its bundle board in a building, not a menu. Every goal has a face and a place, and the town's
routine shows how the world works. Shortcoming: it still leans on a quest board and journal.

**Hyper Light Drifter.** No text at all: NPCs "speak" in short picture panels, ruins and bodies tell what happened.
Teaching mechanics without words is hard and many players miss systems. For us: a tiny picture beats a sentence on
a phone; a 16x16 emote above a head ("!", a deer, a coin) is ours.

**Don't Starve**
- What: Maxwell says one line ("Say pal, you don't look so good. You better find something to eat before night
  comes!") and vanishes. After that, **your own character tells you things**: at dusk Wilson says "It's getting
  late. It will be dark soon."; examining anything gives a one-line quip that doubles as a hint.
- Why it works: one destination in the first seconds (food before night), then warnings in a character's voice at
  the exact moment they matter.
- Shortcomings: famously harsh; most learning still comes from dying or a wiki.
- For us: timed, short, in-voice warnings are the Navi job done right.

### Groups and teams

**Sea of Thieves**
- What: a crew game that teaches very little; a short solo Maiden Voyage, then the sea.
- Why it matters: **the crew is the tutorial.** A crew willing to teach decides whether a new player stays; a few
  minutes of being shown removes most of the confusion. Alone, a new player spends hours lost. Rare later added a
  Pirate Academy because crews were not reliable teachers.
- For us: NPC members are teachers we control. Unlike human crews, they are always patient.

**Apex Legends: pings.** One button marks an enemy, item or place and your character speaks a fitting line;
Respawn playtested a month with voice chat banned so it would work for strangers. Context picks the line, so one
input says many things. For us, reversed: members ping for you, in short contextual lines.

**Left 4 Dead: barks from rules**
- What: survivors comment on the world constantly and feel aware.
- How: Valve matches hundreds of world facts against thousands of lines; the **most specific** matching rule wins,
  looser ones are fallbacks; lines break off sensibly under attack.
- Why it works: cheap to author, feels like the characters are watching what you watch.
- For us: this is how `shared/Talk.lua` should pick barks: facts in, most-specific line out.

**Mount & Blade: following a lord's army (a trap).** As a mercenary you follow a lord while he patrols and sieges.
Players call it monotonous (chase bandits, get beaten, walk back); it pays in relation, but the walk is empty.
For us: **a ride-along with nothing on the road is a chore.** RDR2 filled it with talk; we must too.

### Roblox and phones

- Roblox's own onboarding guide: teach the essentials, get to the fun quickly, leave them wanting more; teach in
  context, when the player needs it; small early wins. Its metric is Day 1 retention and the first-session
  retention chart (who is still playing X minutes after joining).
- Phones dominate: Roblox's 2024 annual report put mobile at about 80% of users. Sessions are short.
- Text tutorials get skipped by exactly the players who need them; players read a fraction of on-screen words.
  Keep text short, staggered, and playable rather than read.

---

## Part 2: what fits a GROUP

The patterns that survive our constraints, roughly in order of value.

1. **The group's movement is the instruction.** Joining means walking with them. The leader walks a few tiles
   ahead, stops, and faces you if you fall behind (Journey's white robes, Ellie's distance rule). The route is the
   arrow; no arrow is drawn. Distance does the nagging, not text.
2. **The role in one line, at the moment of joining.** The yes is the tutorial: who we are, where we are going,
   what you do, what you get. "Walk with us to Kenstow. Keep bandits off the carts. Your share's paid when we
   arrive." That is the first-30-seconds rule applied to the group (PRINCIPLES 1, first minute).
3. **Copy the members in your role.** Hunters close on a deer and strike; guards turn to face bandits; the band
   loots a cart. The player sees the verb done by someone like them before they need it (Sea of Thieves, Stardew's
   town routine). It costs only the NPC behaviour the group already has.
4. **Short barks from named members at the moment it matters.** "Wolves, east!" "Deer by the trees." "Kenstow's
   gates. Nearly there." Picked by rule, most specific first (Left 4 Dead), only when the player is close enough to
   see the speaker (Ellie), never pausing play (not Navi).
5. **Fill the road with talk.** Members chat on the walk: about the endpoint, the last ambush, what they think of
   you. RDR2's best idea, and the cure for Mount & Blade's empty march.
6. **Cues fade as you learn.** A teaching bark ("Hit it while it runs!") fires for the first few times, then
   drops to the plain callout, then to nothing (Rain World's overseer, without its low start).
7. **Ask anyone in the group "what now".** A topic on every member, answered from their role and the moment: the
   leader says the plan, a member says what they know. Same machinery as the elder, one person closer.
8. **No fail state, only memory.** Wander off and the group goes on without you; the leader remembers. Never
   RDR2's "you left the horse, mission failed" (pillar 5; PRINCIPLES 1.2).
9. **Arrival is the reward moment.** The share paid, standing moved, a line from the leader. Roblox's "end with a
   moment of joy"; it also hands the player straight to the next lost minute, so the leader can point onward
   ("Kenstow's buying hides. Talk to their merchant.").

### The elder answering from where the player stands

- The elder is the compass for a player **outside** a group. Inside one, the leader is the nearest elder: "what
  now" asked of any elder while you ride with a caravan can reasonably say "Your master knows the road better
  than I do."
- Answer like the rumour log, in speech: what you have heard and not followed, what you have and lack, who
  trusts you. One step, a place and a reason (1.3), never a sequence.
- Distance and bias are content, but only once the first minute is safe (Elden Ring's late Melina is the warning).
  A far elder should still say *something* useful and true at low detail, rather than nothing.
- Say "you've done that already" happily (1.5). It is the cheapest proof the compass is guidance.
- When the elder is dead, someone must answer (an heir, a neighbour, a member of your group): "Old Bera would
  have known. I'd ask in Glenworth." Absent, not silent.

### What works on a phone-sized 2D screen

- **Bodies over words.** A leader stepping away and looking back reads at 16x16 on a phone; a paragraph does not.
- **Speaker-anchored, short text.** A bark should be under about six words and visibly tied to a sprite (a bubble
  or a name prefix). A notice with no visible speaker is a quest log in disguise.
- **One emote above a head** ("!", "?", an item icon) for the thing to look at. Pictures carry where text fails
  (Hyper Light Drifter), and costs one sprite each through the existing loop.
- **Never modal.** No bark pauses the game or needs a tap to dismiss. Talk topics stay on F / tap, player-pulled.
- **One cue at a time.** Phones show little; stack barks and the player reads none. Newest wins, others drop.

### The traps

- **Nagging.** Repeated lines, obvious lines, lines that pause (Navi). Fix: memory per line, fade, never modal.
- **Hand-holding.** Fail states for straying, choreographed middles (RDR2 missions). Fix: point, do not script.
- **Opacity.** No first step, no reason, rules hidden (Rain World). Fix: the joining line and the walking leader.
- **The empty march.** Following with nothing on the road (Mount & Blade). Fix: talk, an encounter, arrival.
- **The disguised marker.** A bark from no one is a waypoint. Fix: every line has a face on screen.
- **The 80% route.** Offer a clear line and most players will take it only (BotW playtests). Fine inside a group,
  which *is* a line; outside it, the elder points at one step, never a chain.

---

## Part 3: concrete implications for Lowlands

Ideas, not decisions. Anything that changes a shared module or save data is an escalation trigger (CLAUDE.md
triggers 2 and 3); flagged below.

1. **The joining reply carries the role.** The leader's yes names destination, job, and pay in one line, built in
   `shared/Talk.lua` from the group record (route endpoint, kind). Trigger 2 (shared/).
2. **Leader pacing.** A materialised group waits when the player member falls more than a few tiles behind, and
   the leader faces the player. The group record already has a position along its route; waiting is holding it.
   Danger: one AFK player stalls a caravan; cap the wait, then go on and remember it.
3. **Bark table by role and fact.** Facts: enemy seen (wolves, bandits, guards), prey seen, endpoint near, player
   lagging, player hurt, arrived. Most-specific-first pick, one line per event, only to players within view of the
   speaker, as a speaker-tagged notice. Uses the existing `Notice` RemoteEvent; no new remote name.
4. **Fade without a save change.** Count how often each teaching bark has fired per player **in session memory
   only**; the first session teaches, a returning player gets the short form. Keeping it across sessions would
   touch the player save: trigger 3, so not by default.
5. **"What now" on every group member**, answered by role, same topic as the elder's §12 one. Builds the elder
   topic for free; the elder can defer to the leader while the player is in a group.
6. **Road talk.** A few lines per group kind about the endpoints and the player's standing there, spaced out on
   the walk. Content, not code; the per-tribe-type canned-line warning in talk-and-trade applies.
7. **Leaving is a line, not a failure.** Walk away: the leader says one line ("Suit yourself.") and remembers. No
   notice of failure.
8. **Arrival hands off.** At the endpoint: the share, the standing change, and one onward pointer from the leader
   (what this village buys or fears). That line is the hour-twenty compass at the exact minute it is needed.
9. **Test it as the first minute.** A playtester who joins a caravan should, within 30 s and without asking, know
   where they are going and what they are guarding. If they ask "what do I do", the joining line failed.

---

## Sources

- Ellie's buddy AI, GDC 2014: https://www.gamedeveloper.com/design/ellie-s-buddy-ai-in-i-the-last-of-us-i-explained-at-gdc-2014 ·
  https://gdcvault.com/play/1020364/Ellie-Buddy-AI-in-The · https://www.killscreen.com/how-ellies-pathfinding-made-you-love-her/
- Alyx Vance: https://en.wikipedia.org/wiki/Alyx_Vance · https://en.wikipedia.org/wiki/Half-Life_2:_Episode_One ·
  https://waxy.org/2006/09/half_life_2s_de
- Journey: https://www.gamedeveloper.com/game-platforms/in-depth-hunicke-and-chen-talk-tgc-s-intriguing-new-i-journey-i- ·
  https://journey.fandom.com/wiki/Companions · https://media.gdcvault.com/gdc2016/GameNarrativeReview/Gordon_Game%20Narrative%20Review.pdf
- RDR2 mission criticism (player discussions): https://steamcommunity.com/app/1174180/discussions/0/601894733441147830 ·
  https://steamcommunity.com/app/1174180/discussions/0/601895327555926951
- Breath of the Wild: https://gmtk.substack.com/p/how-nintendo-solved-zeldas-open-world ·
  https://80.lv/articles/the-design-secrets-of-breath-of-the-wild/ · https://en.wikipedia.org/wiki/Great_Plateau
- Outer Wilds: https://gdcvault.com/play/1027008/Independent-Games-Summit-Sparking-Curiosity ·
  https://gdconf.com/article/attend-gdc-and-learn-how-outer-wilds-nailed-curiosity-driven-game-design/
- Elden Ring grace: https://eldenring.wiki.gg/wiki/Grace · https://steamcommunity.com/app/1245620/discussions/0/3279193518778445429
- Ghost of Tsushima: https://www.tokyoweekender.com/2020/07/what-sets-ghost-of-tsushima-apart-from-the-rest/
- Navi: https://en.wikipedia.org/wiki/Navi_(The_Legend_of_Zelda) ·
  https://www.nintendolife.com/news/2022/01/even-miyamoto-doesnt-like-stupid-navi-in-zelda-ocarina-of-time
- Rain World: https://game-wisdom.com/?p=19630 · https://rainworld.miraheze.org/wiki/Overseer · https://en.wikipedia.org/wiki/Rain_World
- Stardew Valley: https://stardewvalleywiki.com/Lewis · Hyper Light Drifter: https://killscreen.com/building-wordless-world-hyper-light-drifter
- Don't Starve: https://dontstarve.wiki.gg/wiki/Maxwell/Quotes · https://dontstarve.wiki.gg/wiki/Dusk
- Sea of Thieves: https://guildorder.com/games/sea_of_thieves/wiki/new-crew-onboarding ·
  https://www.purexbox.com/news/2020/06/sea_of_thieves_unveils_free_new_player_guide_for_budding_pirates
- Apex pings: https://www.pcgamer.com/au/apex-legends-ping-system-is-a-tiny-miracle-for-fps-teamwork-and-communication/ ·
  https://wnhub.io/news/other/item-15272
- Left 4 Dead dynamic dialog: https://www.gdcvault.com/play/1015528/AI-driven-Dynamic-Dialog-through ·
  https://www.blog.radiator.debacle.us/2012/07/rule-databases-for-contextual-narrative.html ·
  https://emshort.blog/2012/03/16/gdc-2012-talk-on-dynamic-dialogue/
- Mount & Blade armies (player discussions): https://forums.sorcererking.com/412103/is-mount-and-blade-worth-it ·
  https://steamcommunity.com/app/261550/discussions/0/2144217924385661155
- Roblox onboarding: https://create.roblox.com/docs/production/game-design/onboarding
- Roblox mobile share: https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue/
- Text tutorials: https://gdevelop.io/blog/improve-game-tutorials · https://www.blog.udonis.co/mobile-marketing/mobile-games/mobile-game-tutorial

Caveats: RDR2 and Mount & Blade rest on player discussions; Sea of Thieves on a community wiki; Alyx on secondary
summaries of Valve's commentary, not the commentary itself.
