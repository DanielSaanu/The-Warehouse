# The box

Design principles that are **not about Lowlands**. Things that turn out to be true about a kind of game, worth
keeping past this project and carrying into the next one. Lowlands-specific decisions live in `docs/DESIGN.md`;
this file is portable, so copy it into whatever comes after.

One rule for what gets in: it has to be a principle a builder can *apply* at the moment of a decision, not a
description of a game someone liked. If it does not tell you what to do when you are standing at the fork, it is
a note, and notes go in `ideas/INBOX.md`.

---

## 1. The main story is the compass, not the spine

*(Danzo, 2026-09-18, from a video about Palworld. For open-world games generally.)*

**A player should be able to get from the start of the game to the end of it by only ever doing the things that
interest them. The main story exists for the moments when nothing does.**

That is the whole principle. It sounds small and it changes the shape of everything.

### The two ways open worlds fail

Both failures come from the same mistake — treating the main quest as a load-bearing wall instead of a signpost.

- **The corridor with a field around it.** The main quest is the real game; everything else is "side content".
  The world is huge and none of it counts. The player feels the pull of the spine the entire time they are
  wandering, and wandering starts to feel like procrastinating. The punishment for exploring is irrelevance.
- **The formless sandbox.** No main quest at all, just systems, on the theory that freedom is enough. It is not.
  A new player opens it, finds no reason to walk in any particular direction, does something arbitrary, dies,
  and leaves. Every playtest of an unguided open world produces the same sentence: *"it's kind of boring, I
  don't know what to do."* Freedom with no first step is not freedom, it is a blank page.

The compass version is neither. The story is always there, one glance away, and it never expires, never blocks,
and never makes the wanderer feel like they were doing it wrong.

### What it has to satisfy to actually be a compass

1. **The story never gates a system.** Anything you can do at the end, you can attempt at the start. The world
   answers with consequences, not with locks. A locked door that the main quest is the only key to has turned
   the story back into a spine.
2. **It never expires and never scolds.** Ignore it for twenty hours and it is waiting, caught up to what you
   actually did in the meantime. No step ever says "you were supposed to do this first."
3. **It points, it does not choreograph.** A step names a place and a reason to go there. It does not script the
   middle. How you get there, who you kill or befriend on the way, and what you do instead when you arrive is
   the game.
4. **Every destination it leads to has at least two roads.** If the story is the only way to reach the throne,
   the guild, the ending — it is the spine again, wearing a hat. Whatever it leads to must also be reachable by
   a player who never opened it, by playing.
5. **The world can complete a step without being asked.** If the step was "make peace with the hunters" and you
   already did that three hours ago for your own reasons, it is done, and the game says so. **A step completed
   by accident is the strongest proof the story is guidance** — it means the story was describing the world
   rather than driving it.
6. **It is answered by a character, not a log.** The compass wants a face: someone you ask "what now" and who
   answers in terms of what they know and where you stand with them. A quest log is a menu that tells you the
   truth from nowhere; a person is the same information, in the world, and can be wrong, biased or dead.

### The test

Two players finish the game. One followed the story from start to end; the other never once looked at it and
just chased what caught their eye. **Both finished, and neither felt they had played the lesser version.** If the
story-follower had the better time, the world is under-built. If the wanderer had the better time, the story is
wasted work. If the wanderer never finished at all, there was no compass.

A second, sharper test: **the fastest route through the game should not be the most fun one.** When it is, the
story has quietly become the spine, because now optimising and enjoying point the same way and wandering is
strictly a cost.

### The two moments it actually exists for

Everything above is in service of two specific minutes, and it is worth naming them because they are the only
times a compass gets read:

- **The first minute.** Someone who does not yet know what kind of game this is needs one direction, in the
  world, from a character, within about thirty seconds. Not a tutorial: a destination.
- **The lost minute, at hour twenty.** A player who has just finished a thing — sold the haul, won the fight,
  built the hut — and is standing still. This is where open worlds lose people, and it is nearly always
  invisible in testing because it never happens in a thirty-minute playtest.

Build the compass for those two and it will be right everywhere else. Build it for the middle and it becomes a
spine.
