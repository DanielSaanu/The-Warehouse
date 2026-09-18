# Ideas inbox

This file is the shared scratchpad. Type here in the UI (bottom pane) or in any editor. Claude reads it 
the start of a session and works through it. Cross things out or delete them when done.

## The game (agreed so far)

- 2D, top down, tile grid. 16x16 pixel sprites. Play area is a COLS x ROWS grid that scales to any screen.
- "Rain World energy" without the impossible bits: creatures with their own lives, factions that remember
  you, a rain cycle that forces you to find shelter, a world that persists and is shared by everyone on the server.
- Scope ladder: (1) grid + movement + one room + rain cycle  ->  (2) two factions with behaviour + reputation
  ->  (3) persistence, regions, multiplayer memory  ->  (4) fancy stuff.

## Open questions

Answered 2026-09-17 and written up in `docs/DESIGN.md` (real time, 96x96 map with three villages, left click
attack, F interact, respawn at a friendly village, saved + caught-up world). Danzo's notes below stay as the flavour
reference. Remaining questions are at the bottom of the design doc.

BOSS(Danzo):
  - theme: i feel like should be simple for now so to make it easy well just have it set in a sort of grasslands featuring caves rivers forests uno the usual overworld stuff with different tribes like scavengers and the like aswell as general wild life like boars and deer and stuff were trying to create an ecosystem that works regardless of the player so tribes are hunter gatherers or theyre primitive farmers or theyre the kill and plunder type
  -(note) id like them to be able to trade:
      >plunder types kill and take from others they also sell and trade with each other/the player if they dont want to kill him on sight they also plunder other tribes caravns but they should be hesitant to attack big caravans unless they are a very big tribe  they are the weakest type of tribe using gurilla tactics theyre strength comes from theyre sudden and brutal nature
      >farmers are more peaceful and will tradee with anyone depending on theyre relationship including the plunder types they may offer tribute in exchange for protection either against other plunder type tribes or wildlife if the player is found out to be frequently harming people that negativeley effects trade farmer tribes will also trade with hunter gatherers at times they may even start caravans where they travel and trade goods before returning home with the goods caravans should only be for the strongest of the farmer tribes they should also have the most resources at theyree disposal for obvious reasons theyre strength lies in coordination and militarisation
      >hunter gatherer tribes should also do trade but they should have an even temperment willing to fight but not overly aggressive they should have a naturally antagonistsic relationship with the plunder types becuase they hunt in smaller groups which are often ambushed by the plunder types they are the strongest individually because hunters spend frequent time hunting with theyre squads intensley unlike the farmer types who though they have many mid level strength they are more defensivley focused and timid mainly focusing on getting the goods home and making a profit on the dangerous journey while hunters go out kill and return frequently on short journeys every week or two thyre strength lies in theyre individual battle prowess and tight team chemistry
  -(note) there are multiple tribes of each type separated into small mid size and large(if u have any more ideas push back or need clarification on anything ask me we can discuss)
      >pluder types scale causing more bandit groups thieves etc out and about in the world from theyre tribe large tribes will raid other tribes aswell as attack large caravan convoys they rule theyre territory and make tribes within they are not attacking pay tribute mid and small do the same but in lesser amounts mid tribes will rareley attack villages favoring caravans of mid size tribes but may attack large caravans when they think they can win or if the situation forces it or if they particularly hate the enemy while large tribes will attack villages more than caravans but they dont like to destroy villages near theyre territory completely favoring to collect tribute same with caravans they may not outright plunder chossing instead to extort and let go they dont want to turn all the big tribes against them
      >farmer types cause merchants and knights or something to keep the peace in theyre areas larger tribes more of those they also have farms and shit obviosly furthermore larger tribes larger caravans small tribes wont have them at all only the strongest mid tribes send out large processions and large tribes they heavily fortify themselves big walls more civilized than the otehr two types again more civiliced they get is based on the size of the tribe farmer tribes are also the largest more villages than tribes they also collect tax from smaller vilages in theyre territory they seek to expand they have many mouths to feed
      >hunter gather types dont collect tax or tribute but they cause hunters to appear in the world they also go out in squads of 4-5 they also cause adventurers and adventurer groups to go out into the world they may be hired by merchants and merchant caravans stronger groups/individuals come from stronger tribes larg tribes may send out hunting partys that are multiple squads and they will gather to deal with strong wildlife or to attack plunder villages if they have bad enough relationships with them
-wild life it should be abundant there should be a variety of herbavoires omnivores and carnivores they should form an eco system  that runs in realtime in the background if the player murders a whole pillar of the ecosystem it should show if they burn down the forest or desroy local herbavoires it show in the ratio and types of wildlife
      >
-player: for now just a guy we can even have it start off in a village that has been plundered by a pluderer tribe and then we can make it so that the player can live anywhere in any village depending on his relationship with them and theyre tribe side note the in game charachters can share info about the player so if i make someone who is a part of a large farmer tribe my enemy it would do damage to my reputation with his friends and family and the charachters have to actually meet to exchange info weather a caravan spreads it or a lone bandit tells his bandit friends or  hunter squads tell caravans theyre protecting or other squads they run into along theyre journey etc etc etc

-name: idk yet        
    

## Asset wishlist

- [ ] 4 to 6 floor variants (moss, stone, water edge, mud)
- [ ] wall variants + a shelter door tile
- [ ] rain overlay (done: rain_tile) and a "lightning flash" overlay
- [ ] 2 more creature types per faction, 2 frame idle animations
- [ ] items: food, a glowing thing to carry, a key
- [ ] HUD: heart icons, hunger bar, faction reputation icons
- [ ] a title logo (text scene with Press Start 2P + outline)

## Random thoughts (drop them here)

instead of it just being a rain cycle every 60 seconds we could first off make it farther apart like once every in game week there is a flood or a beast tide or a blizzard or a drought 

### 2026-09-18, Danzo, mid-Palworld-video (raw; the agreed parts moved to DESIGN.md)

- Palworld is fun because of the sheer amount of freedom. By the end you are in a Gundam firing lasers with
  exploding birds at villages of cute animals to capture them and put them in a sweatshop. That is the vibe.
  Anything you can think to do, you probably could do. -> now **pillar 5** in `docs/DESIGN.md` §1.
- The endgame is a kingdom: NPCs who work for you, a caravan you own, tax collected from the little places
  around you. Get there by quest-ish means — enough affinity with whoever holds the king/chief role — or by
  murdering the king. The family tree makes "who is the king" and "who is next" trivial to answer. -> written up
  as **§13 Chiefs, heirs, and taking a tribe**. One thing pushed back on: killing a chief ending the tribe makes
  the world emptier the more you play, so instead it names an heir, drops a tier, or splinters.
- "We can make trees for anything, what the fuck is an extra array." Mostly true — the cost depends on what you
  hang it on, so §4 now has a **data budget**: free per tribe/village/region/role, careful per person.
- "We have to go into that third dimension a little bit." Open question at the bottom of DESIGN.md: fake height
  is cheap and could land any week, real elevation is rung 4.
- **The main story should be the guidance, not the game.** You should be able to go start to finish just messing
  with whatever interests you; the main story is what you fall back on when you actually need direction. That is
  what Palworld does. This is the answer to the little brother's playtest above ("I don't know what to do") —
  the problem was never too little freedom, it was no compass. -> **pillar 6** in `docs/DESIGN.md`, and the
  portable version is **principle 1 in `docs/PRINCIPLES.md`**, which is the box: design principles that are not
  about Lowlands and are meant to be carried to the next project. Concrete here: the elder answers "what now"
  (§12), because the first job retires at the first calamity and nothing replaces it.
- The other game he likes (unreleased): everything procedurally generated, characters are just parts you bolt
  together — thrusters, attractors, magnets — and the movement is procedural too, so whatever you build moves.
  He said it can't be done in Roblox. It can, actually: Roblox is a physics engine, and constraints + Motor6D +
  procedural IK is exactly that toy. It is just a **different game**, not Lowlands, and it would want to start
  from an empty baseplate. Parked here so it is not lost.


## Playtest 2026-09-17: Danzo's little brother, first ever session (rung 2 part 2 + part 3)

Verdict: "kind of boring, I don't know what to do. Go in, punch some guy, get killed, lose my stuff, don't want to
play any more." Found the survivor only when told the key. Liked the tutorial lines once he read them, liked the
idea of the weekly calamity. The bar to clear next: a new player must know what to do in the first minute without
being told by a human.

All of this is done on `rung2-part4` except where noted. Goals file: `docs/qa/rung2-part4.md`.

Quick fixes (HUD, hours):
- [x] Hearts top-left are very thin (bug: RelativeYY with a 0.16 width scale squashes them). Draw them square.
- [x] Trade window text is too small and too grey to read. Bigger, white. (The cause was `TextWrapped = false`,
      which quietly turns `TextScaled` off: every column was pinned at 14px whatever the screen size. 13px -> 30px.)
- [x] Show the keybinds on screen: F next to the prompt is there, but nothing says "F" until you are adjacent, and
      nothing ever says Tab, Space, X. A small always-on key legend, or the hint line staying up longer.

Onboarding (the real problem, a day):
- [x] Make the survivor unmissable: a bobbing arrow over them until you have talked to them, and the banner's
      second line reads "Someone is calling you".
- [x] Signs. Wooden sign objects you can F-read, one at every village gate or road exit and every ford, with text
      built from the map ("Kenstow, east. Hunters."). First spawn says "Read the signs."
- [x] A visible first job, not a quest log: one line under the clock, five steps, retired for good at the first
      calamity. Stored on the player record so rung 3 saves it.
- [x] Dying early is the wall: for the first two days the band patrols near its own village, the survivor says
      "do not go <that way> yet" and names the safe road, and bandits never chase anyone inside a village.

Controls and inventory (a day):
- [x] Inventory key (E) opening a proper panel, and 1-9 for the hot bar selection (again to put the slot away).
- [x] Eat food to heal: with food in hand, F on nothing in front of you eats one for +3 hp.
- [x] Gifts: with a good in hand, F on a villager, guard or merchant gives it. Their stock rises, +2 standing.
- [x] Swimming: the river is its own ground tile, waded at 0.35 speed. Lakes stay impassable, fords keep 0.6, and
      a flood puts the whole river under so the crossing closes.

Art:
- [x] The food icon reads as a sponge. Make it a turkey leg or a loaf with a crust. (Turkey leg.)
- [x] Rivers look like a blue carpet: water and river now have two frames each and animate like the campfire.
      Shore edge tiles were left out of part 4 on purpose; they are still worth doing.
- [ ] He offered to draw sprites. Sprite files are plain text in `sprites/` (one character per pixel); the UI at
      `npm start` edits them live. Any of his get used.
