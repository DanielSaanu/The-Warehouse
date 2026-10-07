# 01 · Moment-to-moment feel: juice, the knife, movement, touch

Hub: [README](README.md). Sources: [07-sources](07-sources.md).
Tags: **[measured]** = a study or published game data (frame data, shipped code). **[dev]** = the developer's own
talk, code or interview. **[opinion]** = a tutorial, blog, or this report's inference.

## Takeaway

The canon on game feel agrees on one recipe, and every part of it is a sprite swap, an offset or a timer: make the
input-to-response gap feel instant, stack many small redundant cues on every hit (sound, white frame, shove, tiny
shake, a 10–100 ms freeze, something that stays on the ground), scale each cue to how hard the hit was, and fudge
timing windows a few frames in the player's favour. The exact numbers are developer-tuned, not lab-derived, but
several are published verbatim. Lowlands already has the skeleton (knockback, hit flash, telegraph, cooldowns);
what it lacks is the stacking, the scaling and the sound. On touch, the measured literature and shipping practice
both say the same thing: remove an input (auto-face the nearest hostile) and let the stick float.

## What the game does today (repo audit)

| Thing | Value | Where |
|---|---|---|
| Swing | cooldown 0.4 s, hit invuln 0.6 s, telegraph 0.5 s, knife atk 2 | `Config.lua:33-36`, `Items.lua:12` |
| Hit feedback | melee swing, knockback, hit flash, telegraph exist | `docs/systems/movement-and-combat.md:3-12` |
| Movement | tile steps, 0.17 s per tile (~5.9 tiles/s); river wade 0.35, ford 0.6 | `Config.lua:19`, `ideas/INBOX.md:179-180` |
| Touch | fixed d-pad bottom-left feeding the same `held` list as keys; Bag/Standing/Attack buttons at 44/44/48 px; tap-to-move with a routed path | `Hud.lua:346-388`, `Client.client.lua:239-280` |
| Touch testing | never verified on real glass, nor multi-touch | `docs/qa/rung2-part5-summary.md:73-81` |
| Dodge, shield, bows | parked in rung 3 part 7 | `docs/RUNG3.md:547` |
| Sound, haptics | none found in the audit | — |

## The recipe (what the talks actually say)

Nijman's Nuclear Throne pistol, in order: sound first; shell ejected; bullet with 0–4° spread; camera kicks back 6 px;
"add 4 to the screenshake" (a max-jitter value that "degenerates quickly"); weapon kick 2; a round flash on the
bullet's first frame; the enemy gains 3 px/frame in the bullet's direction; hit animation is **one white frame, then
two reaction frames**; and a **10–20 ms freeze on impact** [dev] ([Nijman via infovore](https://infovore.org/?p=5275)).
The talk's full step list (animation, lower time-to-kill, impact effect, hit reaction, knockback, permanence, camera
lerp, shake, hit pause, recoil) survives only in a fan recreation and a blog summary; the video itself was not
fetched ([DK Liao recreation](https://dkliao.itch.io/the-art-of-screenshake-recreation/devlog), [RPG Playground](https://rpgplayground.com/research-making-a-juicy-game/)).

Jonasson and Purho's "Juice it or lose it" adds tweening on everything, squash and stretch on impact, particles,
screen flash and "eyes on everything" [dev via summary] ([RPG Playground](https://rpgplayground.com/research-making-a-juicy-game/)).

Hit-stop is the one part with measured frame data: Street Fighter 2 froze both fighters ~10 frames; Smash scales the
freeze with damage (a 15% hit = 8–15 frames) and shakes the victim; Dark Souls 2's lack of it "makes it harder to tell
a hit occurred" [measured] ([Critpoints](https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/),
[SSBWiki Hitlag](https://www.ssbwiki.com/Hitlag)). Practical rule: freeze only attacker and target, keep UI and audio
running, tune per hit strength [opinion] ([bugnet.io](https://bugnet.io/blog/how-to-fix-hitstop-or-freeze-frame-feeling-off)).

Celeste's method matters more than its numbers: "everything is fudged a tiny bit in the player's favor" — coyote time
0.1 s, 4 px corner correction, a hurtbox (8×9) smaller than the hitbox (8×11) [dev, published code]
([Celeste & Forgiveness](https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html),
[Player.cs](https://raw.githubusercontent.com/NoelFB/Celeste/master/Source/Player/Player.cs)).

## A knife loop for Lowlands

Minit carried a whole game on "a stab in the direction of movement" ([Wikipedia: Minit](https://en.wikipedia.org/wiki/Minit)).
The structure Gungeon, Hyper Light Drifter and Tunic share is: enemy **telegraph → strike → recovery** (free hits),
answered by a dodge whose first half is invulnerable (Gungeon: 0.7 s roll, i-frames in the first ~0.35 s) [measured]
([Gungeon wiki](https://enterthegungeon.wiki.gg/wiki/Dodge_Roll_(Move)), [PC Gamer HLD](https://www.pcgamer.com/hyper-light-drifter-preview/),
[Pure Xbox Tunic](https://www.purexbox.com/features/interview-tunic-creator-talks-zelda-dark-souls-and-the-influences-that-shaped-his-game)).

For the knife, in order of cost [opinion, every value traceable above]:

1. **On hit**: 1 white frame on the target (the pipeline's `recolor`/`tint` does this with no new art), 2–3 frames
   (~50 ms) of freeze on both bodies, the existing knockback over 3 frames, a 2–4 px shake that decays fast, a blood
   or dust sprite that stays. Sound before any of it.
2. **On kill or being bitten**: a longer pause (5–6 frames), 6–8 px shake, the body stays (permanence), a stronger
   haptic.
3. **Input**: buffer the attack ~0.1 s so a press during cooldown fires on the next free frame; let a swing cancel
   into a step. Give the player's hurtbox a 1–2 px inset.
4. **Enemy telegraph**: the 0.5 s already exists; make it *visible*: a crouch frame plus a tint toward red or yellow
   for 2–3 frames. Rain World's own designer says creatures built to "care for themselves" become "super difficult and
   frustrating" when their intent is unreadable [dev] ([Game Developer: Rain World](https://gamedeveloper.com/design/crafting-the-complex-chaotic-ecosystem-of-i-rain-world-i-)).
5. **Later (rung 3 part 7)**: a dodge step of ~0.4–0.7 s with i-frames in the first half. Dash is already parked
   there; the Gungeon numbers are the starting point.

Caution [measured, secondhand]: a juiciness study found high juice **lowered** players' sense of competence, while
success-linked feedback raised enjoyment and playtime ([Hicks et al. via summary](https://psych.substack.com/p/the-juicy-factor-the-science-of-making)).
Fire the big effects only when the hit lands. Confetti on every swing makes players feel worse, not better.

## Movement on a tile grid

No controlled study compares grid and free movement; everything here is developer practice [opinion].

- Grid movement is "predictable and easy to reason about" and pairs with one-tap input, but reads as sluggish unless
  you add three things: a mid-tile reversal that snaps back immediately, a buffered next step so a held key never
  stutters at tile edges, and turn-in-place only on a tap, never on a hold ([NerdyTeachers](https://nerdyteachers.com/PICO-8/game_design/111),
  [love2d forum](https://love2d.org/forums/viewtopic.php?p=64654)).
- Corner assist is "the single biggest 'my character is stupid' fix": Link to the Past slides you round a diagonal
  edge while you hold the direction; Celeste probes ±4 px ([gamedev.stackexchange, snippet only](https://gamedev.stackexchange.com/a/11206),
  [Player.cs](https://raw.githubusercontent.com/NoelFB/Celeste/master/Source/Player/Player.cs)). On a tile grid: when
  blocked on one axis, try the neighbouring tile on the other axis and slide.
- Camera: lerp toward the player, never hard-lock, never snap on a tile change [dev] ([Keren, Scroll Back](https://www.gamedeveloper.com/design/scroll-back-the-theory-and-practice-of-cameras-in-side-scrollers)).
- Every cited exploration/combat top-down game uses free 8-way movement. If Lowlands keeps tile-locked data (it
  should: the server is authoritative and the tick is pure), animate position between tiles and apply the three
  fixes above. That is the difference between "Pokemon tight" and "sluggish" [opinion].

## Touch

Measured:

- Direct touch wins for two-handed tasks, an indirect joystick for one-handed ones (n=81) ([Seo & Kang 2019](https://oasis.library.unlv.edu/art_fac_articles/25)).
- Virtual joysticks: "without visual confirmation, users have difficulty reliably perceiving the joystick's center
  position", producing unintended inputs ([Tsukuba, CHI PLAY 2025](https://www.iplab.cs.tsukuba.ac.jp/~thonda/paper/3764687.3769934.pdf)); on-screen
  pads "encourage drifting and unintended operations" ([AIT](https://publications.ait.ac.at/de/publications/investigating-on-screen-gamepad-designs-for-smartphone-controlled/)).
- Tap-to-move as the only scheme confuses players when taps also hit UI or objectives (Assassin's Creed Identity
  playtest) ([PlaytestCloud](https://blog.playtestcloud.com/first-look-playtesting-the-soft-launched-assassin-s-creed-identity/)).

Shipping practice (not studies): Stardew mobile defaults to tap-to-move plus **auto-attack** (the farmer turns to face
the enemy and swings) and offers an "Invisible Joystick" that centres where the thumb lands ([Stardew wiki: Mobile Controls](https://stardewvalleywiki.com/Mobile_Controls));
Brawl Stars' tap on the attack stick is quick-fire at the nearest target ([AndroidAyuda](https://en.androidayuda.com/games/Tutorials/brawl-stars-how-to-play-android/));
Archero removes an input entirely (stand still to shoot) ([WeAreSync](https://www.wearesync.co.uk/latest-news/archero-iphone-game/)).

Roblox gives this for free: `DevTouchMovementMode.DynamicThumbstick` (stick appears where the thumb lands),
`Scriptable` (no default controls, which Lowlands needs because it draws its own viewport), `ContextActionService`
auto-created touch buttons, and `HapticEffect` presets such as `GameplayCollision` and `UIClick` on most phones
([DevTouchMovementMode](https://create.roblox.com/docs/en-us/reference/engine/enums/DevTouchMovementMode.md),
[ContextActionService](https://create.roblox.com/docs/reference/engine/classes/ContextActionService),
[HapticEffect](https://create.roblox.com/docs/reference/engine/classes/HapticEffect)). `HapticService` is deprecated.

What this means for Lowlands [opinion]:

| Change | Why | Cost | Note |
|---|---|---|---|
| Floating stick on the left half instead of the fixed d-pad | the measured "lost centre" problem | S | reopens the recorded layout decision, `docs/design/open-questions.md:9-17` |
| Attack button auto-faces the nearest hostile within ~1.5 tiles, then hits the faced tile | Stardew/Brawl Stars practice; one thumb | S | keeps "attack hits the faced tile" |
| Keep tap-to-move, but as an option, and never let a tap on an NPC or button also move you | AC Identity playtest | S | the prompt is already a button, `Hud.lua:423` |
| `HapticEffect` on hits, bites, kills, UI taps only | Waterloo haptics study; competence warning | S | scale with event weight |
| **Test on a real phone first** | the touch path has never run on glass | — | the single biggest unknown in this whole report |

## Readability at 16×16

Craft opinion, not measured, but consistent across sources: silhouette first; 5–6 colours per 16 px sprite; three hard
value steps; selective outline (dark pixel only where shadow falls) because black outlines vanish on dark ground; a
soft shadow blob under top-down sprites anchors them to the tile ([sprite-ai 16×16 guide](https://www.sprite-ai.art/guides/how-to-create-16x16-pixel-art),
[Wayline](https://www.wayline.io/learn/pixel-art/4), [Steam thread](https://steamcommunity.com/app/431730/discussions/0/3828666283444696316)).
Saint11 has dedicated top-down walk, run and attack tutorials but they are GIFs the researchers could not read; only
the titles are confirmed ([saint11.art](https://saint11.art/blog/pixel-art-tutorials/)). Hades' art direction reserves
red for threat cues and keeps silhouettes distinct through particle noise [secondary] ([GeekChamp](https://geekchamp.com/the-art-of-hades-showcases-the-talent-that-went-into-this-beautifully-vibrant-game/)).
Damage numbers: no evidence either way; at 16×16 a flash plus a shove likely carries more information per pixel.

## Sound and haptics

- Juicy audio raised presence and immersion in a controlled comparison [measured] ([Smets & van der Spek 2021](https://research.tue.nl/en/publications/that-sounds-juicy-exploring-juicy-audio-effects-in-video-games/)).
- Juicy phone haptics raised enjoyment, aesthetics, immersion and "meaning" in two studies [measured] ([Waterloo thesis](https://uwspace.uwaterloo.ca/items/739bca60-4670-4ea7-bc4d-c1ddd2242b26/full)).
- Sound is the **first** item in Nijman's routine, before any visual [dev] ([infovore](https://infovore.org/?p=5275)).
- A per-surface footstep set (grass, dirt, road, water) is supported practice, not proven by any study.

## Tuning sheet (starting values, every one traceable above; re-tune by looking at it at 8× scale)

| Parameter | Start | Source tag |
|---|---|---|
| Input to visible response | ≤ 100 ms | Swink via secondary; the Gamasutra article itself does not state it |
| Attack buffer, grace | 0.1 s | Celeste code |
| Hit-stop light / heavy | 2–3 / 5–6 frames, attacker + victim only | SF2, Smash, bugnet |
| Hit flash | 1 white frame | Nijman |
| Knockback | 3 px/frame for 3 frames (existing) | Nijman |
| Shake | 2–4 px decaying; 6–8 px on kills | Nijman, eastondev [opinion] |
| Enemy telegraph | 0.3–0.5 s wind-up with a visible pose (0.5 exists) | inference from Gungeon/HLD frame data |
| Dodge (later) | 0.4–0.7 s, i-frames in the first half | Gungeon |
| Corner assist | 3–4 px or one tile edge | Celeste, LttP |
| Haptics | hits and UI only, scaled to success | Hicks, Waterloo |

## Gaps the researchers could not close

- Neither 2012/2013 talk video was fetched; technique lists come from a recreation devlog and a summary.
- No primary Supergiant source on Hades hit-stop or telegraph timing.
- No controlled study of grid vs free movement, auto-aim vs manual aim, or damage numbers vs none.
- The Tsukuba and AIT papers' numeric results could not be extracted.
- Every number above comes from other games' pixel scales and frame rates; nothing substitutes for looking at it.
