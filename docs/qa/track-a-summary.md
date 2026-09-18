# Track A — QA summary: one round, 9/10

Goals: `docs/qa/track-a.md`. Builder: Fable. Reviewer: one Opus subagent with the Studio MCP. Target 8.0, hit in
round 1, so the loop ended there. Verbatim report: `docs/qa/archive/track-a-round1.md`.

| Round | Score | Main finding |
| --- | --- | --- |
| 1 | 9.0 | All seven goals met. The worst bug was in a test command: `savetest` left the server saving into memory while logging success |

## Fixed (round 1)

- `savetest` is Studio-only and puts back everything it touches (store, mode, reason, the player's `noSave`).
- `Map.walkable` called an undefined global after the `World`→`Map` rename; deleted (unused). **`npm run lint:luau`
  now fails on any unknown global that is not one of Roblox's own**, which is the class of bug, not the instance.
- `Restore.apply` tells already-connected clients the restored calamity state, so a Debug `reload` no longer leaves
  water on the client that the server has lifted.
- `Calendar.advance` (unused) deleted; `[Restore]` logs the living, not an id counter; a test comment no longer
  over-claims.

## Preserved

- `Save.check` + encode-by-named-field (nothing is saved by accident; the pure round trip means something).
- Exactly one constructor per boot (`Restore.apply` XOR generate): 39 people, 39 bodies, after any number of reloads.
- `Tick.catchUp` second-by-second, with the test that it equals live ticking.
- Never write a key you failed to read, with the fast exit when Studio has no API access.

## Deferred

- A `restart` debug command (stop/start Play does it).

## Not verifiable by the loop — Danzo's checklist

The reviewer could not reach a real DataStore (Studio API access is off), so these are yours:

1. Studio → Game Settings → Security → **Enable Studio Access to API Services**. Press Play. Output should read
   `[Persistence] no saved world: starting one` then `[Server] world generated (new)`.
2. Walk out of the village (south gate), put the camper set in hand (4), press F on open ground. Buy or sell
   something so your coin changes. Note a villager's name and the day.
3. Stop Play (Output: `[Persistence] world saved: day N, ~9300 bytes`). Wait a minute. Press Play again.
4. Output should read `[Persistence] loaded the world: saved ~60 s ago`, `[Restore] day N, 39 living (39 bodies)…`,
   `[Server] world restored (loaded)`. **You should be standing where you stopped, with the same coin; the camp is
   where you put it; the same named people are in the village; the calendar did not reset to Day 1.**
5. Leave it stopped for ten minutes and start again: the day counter should have moved on by one (a day is 600 s),
   and the campfire should be cold.
6. If anything in Output starts with `[Persistence] NO-SAVE mode`, read the reason on that line: that server will
   never write, on purpose.
