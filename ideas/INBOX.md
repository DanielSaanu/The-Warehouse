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


## Playtest 2026-09-17: Danzo's little brother, first ever session (rung 2 part 2 + part 3)

Verdict: "kind of boring, I don't know what to do. Go in, punch some guy, get killed, lose my stuff, don't want to
play any more." Found the survivor only when told the key. Liked the tutorial lines once he read them, liked the
idea of the weekly calamity. The bar to clear next: a new player must know what to do in the first minute without
being told by a human.

Quick fixes (HUD, hours):
- [ ] Hearts top-left are very thin (bug: RelativeYY with a 0.16 width scale squashes them). Draw them square.
- [ ] Trade window text is too small and too grey to read. Bigger, white.
- [ ] Show the keybinds on screen: F next to the prompt is there, but nothing says "F" until you are adjacent, and
      nothing ever says Tab, Space, X. A small always-on key legend, or the hint line staying up longer.

Onboarding (the real problem, a day):
- [ ] Make the survivor unmissable: a marker or arrow over the only person with a prompt, and a first line on
      screen like "Someone is calling you" before the hint. He walked past them.
- [ ] Signs. Wooden sign objects you can F-read, placed by the road and the gate: "Kenstow, east", "Wolves at
      night", "The stall buys hides". A line at the top on first spawn: "Read the signs."
- [ ] A visible first job, not a quest log: the survivor's last line should become a persistent one-line goal under
      the clock ("Go east to Kenstow and find the hunters") until you enter Kenstow, then the next one.
- [ ] Dying early is the wall: the band ambushes a new player on the north road while they have a knife and no
      idea. Either move the ambush spot further from the start village for the first day, or have the survivor
      warn "do not go north yet" and mark the safe road east.

Controls and inventory (a day):
- [ ] Inventory key (E) opening a proper panel, and number keys / Q and E for the hot bar selection.
- [ ] Eat food to heal (F on a food slot, or a key). Right now food does nothing and there is no heal outside a bed.
- [ ] Gifts: F on a villager with a good selected should offer it (DESIGN.md §7 already lists gifts as a rep event).
- [ ] Swimming: rivers walkable but slow (a "wade" speed, maybe 0.4), so the map does not funnel to three fords.
      Keep deep lake water impassable.

Art:
- [ ] The food icon reads as a sponge. Make it a turkey leg or a loaf with a crust.
- [ ] Rivers look like a blue carpet: animate the water tile (two or three frames, like the campfire) and add
      shore edge tiles.
- [ ] He offered to draw sprites. Sprite files are plain text in `sprites/` (one character per pixel); the UI at
      `npm start` edits them live. Any of his get used.
