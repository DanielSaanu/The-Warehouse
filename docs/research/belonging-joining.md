# Research: joining, belonging to and leaving NPC groups

For [`docs/RUNG3.md`](../RUNG3.md) part 4 (Belonging). Written 2026-10-05. Research only, not a decision:
anything below that would change DESIGN or ARCHITECTURE is escalation trigger 1.

Judged against: the rule above the others (participant, not customer; no permission checks, only standing;
*could an NPC do this under the same rules?*), DESIGN §7 (comparative standing, witnesses, grudge multiplier,
small grudge for harm done "as part of a group"), §8 (talking, role NPCs, the multiple-choice window), and
[`population.md`](../systems/population.md) / [`reputation-and-gossip.md`](../systems/reputation-and-gossip.md)
(groups are records with members and a route; holders keyed by village or group id).

Where a source is a wiki or a player thread, the claim is the community's reading of the mechanic, not a dev
statement. Marked "guess" where I am inferring.

---

## Cases

### 1. Mount & Blade: Warband — mercenary contract, vassalage
- **What.** A quest giver may offer a mercenary contract (3 months, then monthly). Vassalage is asked of the king
  once renown and relation are high enough (~150 renown, less 5 per relation point).
- **Mechanically.** Signing *sets* your relation with the faction's friends to 12 and its enemies to -40. Wages
  scale with your troops. Vassals lose wages, gain a village and can ask for captured fiefs.
- **Why it works.** You ask a named person, the answer depends on who you are to them, and joining a side
  instantly makes its enemies yours. Companions in your party have opinions, complain, and leave if you take heavy
  losses or side against them in quarrels.
- **Shortcomings.** The consequence is a number being overwritten, not something the world noticed: a farmer
  three provinces away hates you the instant you sign. Companion morale is gamed with tavern wine (+30, cooldown).
  Opinions are read "via the party menu", not in the world.
- **Steal:** asking gated by standing + renown. **Avoid:** instant, global, flat reputation changes on joining.

### 2. Mount & Blade II: Bannerlord — caravans, escort, leaving a kingdom
- **What.** Escort a merchant's caravan for three settlement visits; own caravans run by companions; serve and
  leave kingdoms.
- **Mechanically.** Escort pays relation "multiple times through the quest" and raiders spawn at a bait point.
  The player cannot lead a caravan; a companion must. Leaving a kingdom: give the fiefs back, about -15 relation
  and you are free; keep them, about -40 to -60 with every lord and the kingdom declares war. Mercenary contracts
  never expire; you ask the ruler to release you.
- **Why it works.** Leaving is graded by *how* you leave: clean departure is cheap, walking off with what they gave
  you is betrayal. Players read that as fair.
- **Shortcomings.** The scripted bait ambush is felt as a quest, not a road. The caravan "runs away often even
  from neutral parties". Caravans are disbanded "through the Clan menu".
- **Steal:** pay standing out at each stop, and grade departure by what you take with you. **Avoid:** scripted
  ambush points; a menu that ends a membership.

### 3. Kenshi — recruits, squads, factions
- **What.** Talk to a character in a bar, pick the recruit line; some are free, some name a price (80 to 100,000
  cats), some only join if freed from a cage or if you belong to a faction (Anti-Slavers).
- **Mechanically.** Faction relation moves by fighting its enemies, freeing its members, handing in bounties;
  joining some factions means wrecking relations with another. Paying the Shinobi Thieves 10k makes them allied.
- **Why it works.** Recruits are characters with a place and a history; the context of the meeting (a cage, guards
  nearby) is the requirement.
- **Shortcomings.** You never join an NPC squad: they join yours and become units you micromanage. Players say
  alliances bring "not really any benefits", reinforcements arrive days late, and allies sometimes stand by.
  Membership bought with coin is a shop.
- **Steal:** requirements that are situations, not stats. **Avoid:** followers as units; membership for cash.

### 4. Battle Brothers — company life
- **What.** You run a mercenary company; each brother has a background, traits and a mood.
- **Mechanically.** Brothers need pay and food on time; events react to backgrounds; mood falls with bad events
  and an angry brother deserts (a whipped "killer on the run" leaves within seconds unless a drink lifts his mood).
- **Why it works.** People leave *you*. The group is not owned; it stays while it is being treated well.
- **Shortcomings.** The player is the boss, never a member. Desertion can feel like an obscure timer when the
  mood rule is hidden; players trade workarounds.
- **Steal:** the group can end the membership too. **Avoid:** hidden, instant desertion with no warning line.

### 5. Rain World — scavengers, no UI
- **What.** Scavenger tribes like or hate the slugcat, with no screen saying so (until late game).
- **Mechanically.** Three layers: each scavenger's own opinion, a regional one, and a global -100..100. Gifts
  raise it (a pearl about +25), theft and killing lower it, loss is multiplied by witness count, change is capped
  at ±50 a cycle, and negative standing drifts back toward zero. At ≥50 you can pass tolls at a cost, at ≥90
  freely. High standing makes groups *follow* you and defend you.
- **Why it works.** Standing is read as behaviour: calm, wary (spines vibrating, eyes widening), hostile,
  following. The witness multiplier makes the world feel like it saw you.
- **Shortcomings.** Players are lost: "how can i tell what my rep is", "will the tribe in Industrial think less of
  me?". Global rep means one massacre turns every region hostile, which feels like a flag, not gossip. Following
  scavengers throw bombs that hit you.
- **Steal:** behaviour as the display, witness-weighted loss, drift to neutral (we have it). **Avoid:** no words
  at all; Lowlands already answers this with §8 talk lines and a standing screen in words.

### 6. Dwarf Fortress adventure mode — companions through conversation
- **What.** Talk to an NPC and ask them to join; ask a lord to make you a hearthperson; ask a commander to join
  his squad.
- **Mechanically.** NPCs agree based on your fame and skills: "creatures with no military skills, or those with
  higher skills than you, are unlikely to agree". A squad commander wants a reputation as killer, hero or hunter;
  a lord accepts a hearthperson "if you have sufficient fame". Leaving: talk to them, ask about the journey, cancel.
  **"Joining you does not immediately mean they are loyal to you; if you turn around and start attacking their
  friends, they'll cancel the agreement."** Loyalty to you overwrites old loyalties "although it takes some time".
  Serving a lord makes his enemies yours and builds "the reputation of a loyal soldier".
- **Why it works.** Joining is an ask, the answer is the world's opinion, and members keep their own ties.
- **Shortcomings.** Spamming performances in front of an NPC eventually recruits anyone (a grind exploit).
  Companions follow you "until they die": a pet with a sword.
- **Steal:** loyalty inertia, the "what do you think of our journey" line as the exit, asking a squad leader. 
  **Avoid:** repeatable actions that grind an NPC into yes.

### 7. Red Dead Redemption 2 / Red Dead Online — the gang camp, posses
- **What.** The Van der Linde camp is a group you belong to; RDO posses are player groups.
- **Mechanically.** Camp needs (food, ammo, medicine) and a donation ledger; morale drops when you do not supply
  it. Rockstar: "the gang know when Arthur is in camp and when he's caused trouble out in the world", built with
  "better memories so that they would respond naturally". Honor changes how they talk to you. RDO posses are
  formed from a menu, up to seven players.
- **Why it works.** Belonging is felt as people talking about what you did, and about who pulls their weight
  (players still argue about Micah's ledger record).
- **Shortcomings.** The camp is scripted story; you cannot leave it. The posse menu is pure party UI.
- **Steal:** members comment on your contribution, out loud, in the camp. **Avoid:** the posse menu.

### 8. Fallout: New Vegas — reputation and disguise (added; best fit for "guards treat you as one of them")
- **What.** Per-faction Fame and Infamy shown as words (Accepted, Liked, Shunned, Vilified...).
- **Mechanically.** Wearing a faction's armour sets common members to neutral and makes that faction's enemies
  hostile; officers and dogs see through it; what you do in disguise still lands on your real reputation.
- **Why it works.** Association is visible: what you are seen as is what you wear and who you stand with.
- **Shortcomings.** Disguise is an item toggle; the world forgets the moment you change clothes.
- **Steal:** being seen with a group makes the group's enemies yours *in that moment*, and people who know your
  face are not fooled. **Avoid:** association that ends when you take it off.

### 9. Roblox: Arcane Odyssey — crews, factions
- **What.** Join a crew by talking to its leader or quartermaster and asking; crews capture islands for Infamy.
  Reputation (neutral is -159..159) decides how the Arcane Government treats you and whether you can hunt bounties.
- **Shortcomings.** In practice crews recruit through Discord and global announcements; the in-world ask is a
  formality over an out-of-game process.
- **Lesson:** a Roblox audience *will* use a talk-to-the-leader join. Make the NPC's answer matter or it becomes a
  vending machine.

### 10. Roblox: Blox Fruits — Pirates and Marines
- **What.** A Marine Recruiter NPC switches you to the Marines; you can switch every time you join a server.
- **Mechanically.** Pirates earn Bounty, Marines Honor; they do not stack. Marines cannot hit each other.
- **Shortcomings.** Joining has no memory: switch sides, switch back, nobody remembers. It is a team toggle
  with an NPC skin.
- **Lesson:** the exact trap. An NPC as the join button is not a conversation unless the NPC remembers.

### 11. Roblox: Deepwoken — factions and the Divers
- **What.** Join the Divers by finding Akira in the Celtor Wastes, staying alive while you talk to him, and
  returning to him at Castle Light. Children of Navae standing rises by rescuing hostages for a camp master.
- **Why it works.** Joining is a test you have to survive and a person you have to find; standing comes from
  doing what the group cares about.
- **Shortcomings.** Mostly fixed quest chains, not a living group's opinion.
- **Lesson:** "prove it first" is a fine answer from an NPC, if it is a thing the group already does.

---

## Patterns worth stealing

1. **Ask a person; the answer is their opinion** (DF, Warband, Arcane Odyssey). The yes/no reads standing and
   renown. Never coin.
2. **The refusal gives a reason in the world** (DF fame, Kenshi context). "I heard what you did at Kenstow" is
   both a no and a gossip readout.
3. **Situations, not stats, as requirements** (Kenshi cages, Deepwoken Akira). "Ride with us to the ford and
   we'll see" is a trial run of the group's own job.
4. **Loyalty inertia** (DF). A new member is trusted a little; trust grows with days on the road. Hurting the
   group's friends ends it.
5. **Grade the leaving** (Bannerlord -15 vs -40). Clean exit is cheap; leaving with their goods is betrayal.
6. **Pay standing at each stop** (Bannerlord escort). Arrival at each village is a payout and a gossip event.
7. **The group can end it too** (Battle Brothers, Warband companions). With a warning line first.
8. **Behaviour is the display** (Rain World, FNV). Being seen walking with the band is the membership badge.
9. **Members talk about you** (RDR2). Contribution and cowardice become lines people say.

## Traps to avoid

1. **Followers as pets or units** (Kenshi, DF, Rain World followers, Bannerlord companions). In Lowlands the
   player follows the group's route; the player never commands the leader.
2. **Instant, global consequence** (Warband sets enemies to -40; Rain World global rep). Ours must travel by
   witness and gossip.
3. **Membership with no memory** (Blox Fruits). If switching sides costs nothing, it is a team toggle.
4. **A menu at either end** (RDO posse, Bannerlord clan menu disband). Joining and leaving are both people.
5. **Grindable yes** (DF performance spam, Warband wine). One ask per day per person, guess at the number.
6. **Hidden rules nobody can read** (Rain World "how can i tell", Battle Brothers silent desertion). Every
   change gets a spoken line.
7. **Scripted bait ambushes** (Bannerlord). Ambushes must be the real band on the real road.
8. **Joining bought for cash** (Kenshi, Shinobi 10k). Already ruled out by RUNG3.

---

## Implications for Lowlands part 4

### How asking works
- "Can I ride with you?" is **one more topic** in the role NPC's §8 window (caravan master, hunter squad leader,
  band leader). No new UI: phone-first, a few big buttons, which the window already is.
- Asked only of the **leader**, in person, while the group is materialised and not fighting.
- Answers, in the leader's voice: **yes**; **yes, but** (a trial: "walk with us to Kenstow, no share this time");
  **no, with the reason** (the worst recent rumour they hold about you); **no, full** (crew at its tier size).
- One ask per player per leader per in-game day (guess) so it cannot be spammed into a yes.

### What the group checks
- **Its own holder standing** with you (group id), then **its home village's** standing, comparatively, the way
  §7 picks sides: the worse of the two weighs more (guess; a design call).
- **What gossip it holds** about you (`knows`): a killing of its own tribe is a no regardless of the number.
- **Grudge**: any grudge with this group or its tribe is a no until amends.
- **Flavour by kind**: the caravan wants "welcome" or better at its home village; the squad wants hunters'
  trust; the band takes anyone the settled tribes hate, and is wary of anyone the settled tribes love
  (plunderer standing is the mirror).
- Every check is data an NPC could hold too: *could an NPC ask to join under the same rules?* Yes.

### What membership changes
- **You are in `members`.** The group's route is your route; the leader does not wait for you beyond a short
  grace, and you cannot steer it.
- **Who attacks you.** Anyone who would attack the group attacks you, and witnesses pick sides as if you were one
  of them (§7 comparative rule). Guards who *see* you with the band treat you as band, on sight, locally; that
  is FNV disguise done as behaviour. Guards who already know your face judge you by your own standing.
- **Standing at both ends.** Paid out at **each arrival**, not only the last: caravan arrival gives standing at
  the destination and back home through the next gossip hop. Riding with a band moves settled standing down and
  plunderer up **only when someone saw you** or the band boasts on arrival; it is gossip, never an instant flag.
- **The group carries news of you constantly**: it is the best witness you have. Fighting well in an ambush is a
  rumour the caravan takes to both villages; running is one too (four hunters, home tonight).
- **A share** of the profit or kill on arrival, as goods or coin, given by the leader with a line.

### How leaving and betrayal are remembered
Graded, all by the leader and whoever saw it, all carried by gossip:
1. **At an endpoint, after the share**: clean. A small plus ("ride with us again").
2. **Midway, on a quiet road**: you walk beyond range; the leader says one line; a small minus with the group
   only ("left us at the ford").
3. **During a fight**: desertion. Every member is a witness; minus with the group and its home village.
4. **Turning on them**: you attack people who trusted you. §7's full kill penalty, and the grudge is the
   **alone** size, not the small group-spread one, because the harm is to the group, not done as part of it.
5. **The group asks you to go**: when its standing of you falls below a threshold mid-route (you hit a member,
   you robbed the caravan's friends), the leader warns once, then tells you to leave.

Riding with a band and then harming *for* it is §7's "part of a group: small" grudge, already written.

### Open questions for Danzo (trigger 1, not decided here)
- **Disconnects.** Roblox sessions are short and phones drop. A logout mid-route should probably be "stepped
  away", no penalty, no share; never desertion. Does the membership persist across a rejoin?
- **Two players in one group.** Allowed? If one betrays, does the other's standing with that group suffer?
- **Weighting group vs village standing** in the ask (worse-of-two, or average).
- **Save data.** A player in `members` touches the group record and therefore the save (trigger 3).

---

## Sources

- Warband factions and mercenary contracts: https://strategywiki.org/wiki/Mount&Blade/Factions ,
  https://strategywiki.org/wiki/Mount&Blade/Faction_quests
- Warband companions leaving, wine: https://steamcommunity.com/app/48700/discussions/0/523890681406729997
- Bannerlord escort caravan: https://gamerguides.com/mount-and-blade-ii-bannerlord/guide/campaign/quests/escort-merchant-caravan
- Bannerlord caravans: https://steamcommunity.com/app/261550/discussions/0/3198117849824422808
- Bannerlord leaving a kingdom: https://primagames.com/?p=313351 ,
  https://steamcommunity.com/app/261550/discussions/0/4036978233552460618
- Kenshi recruits: https://pindrop.gg/kenshi/recruits
- Kenshi factions: https://kenshi.fandom.com/wiki/Faction ,
  https://steamcommunity.com/app/233860/discussions/0/1728711392728908947
- Battle Brothers desertion: https://steamcommunity.com/app/365360/discussions/2/135511294068177022
- Battle Brothers mood system: https://www.gamebanshee.com/k9dcu
- Rain World scavengers: https://rainworld.miraheze.org/wiki/Scavenger
- Rain World players on reputation: https://steamcommunity.com/app/312520/discussions/0/1646544348825359066
- DF companions: https://dwarffortresswiki.org/index.php/Adventurer_mode_gameplay
- DF hearthpersons and squads: https://dwarffortresswiki.org/index.php/Hearthperson
- RDR2 gang memory (Rockstar, Imran Sarwar):
  https://gamingbolt.com/red-dead-redemption-2s-npc-interactions-are-a-huge-leap-forward-says-rockstar
- RDR2 camp: https://www.gamerevolution.com/guides/450813-red-dead-redemption-2-camp-needs-and-morale
- Red Dead Online posses: https://en.wikipedia.org/wiki/Red_Dead_Online
- Fallout: New Vegas reputations and disguises: https://fallout-archive.fandom.com/wiki/Fallout:_New_Vegas_reputations
- Arcane Odyssey crews and reputation: https://bloxinformer.com/wikis/arcane-odyssey/clans/ ,
  https://itemlevel.net/arcane-odyssey-crew-infamy-guide/
- Blox Fruits factions: https://blox-fruits.fandom.com/wiki/Marine_Recruiter ,
  https://blox-fruits.fandom.com/wiki/Bounty_and_Honor_System
- Deepwoken factions: https://deepwoken.fandom.com/wiki/Factions_%26_Groups ,
  https://deepwoken.fandom.com/wiki/The_Divers
