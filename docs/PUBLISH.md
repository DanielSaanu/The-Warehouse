# Publishing Lowlands

DESIGN.md §16 says to publish free well before rung 3 ships, because real players find what we cannot. Everything
in the repo is ready for that; the last steps are Danzo's, because it is his Roblox account.

**Do not charge for anything yet.** Until rung 3's save + catch-up lands, the world regenerates every time a
server shuts down, so anything sold evaporates. Free now, money later (DESIGN.md §16).

## The two clicks

1. **Studio → File → Publish to Roblox.** The place is "working on it" (placeId 129013181321886); rename it to
   **Lowlands** on the Creator Dashboard if it still shows the old name.
2. **Creator Dashboard → the place → Settings → Playability → Public.** Nothing else makes it joinable. Without
   this step the game is published but nobody can get in.

Rojo is a dev-time cable only. Nothing in `roblox/src/` talks to a dev machine — no HttpService, no localhost — so
once the place is published Roblox hosts it and this Mac can be off. Code changes need a re-publish, and servers
already running keep the old build until they shut down.

## The page

**Name:** Lowlands

**Short description (for the store page):**

> A living world of farmers, hunters and raiders. They remember what you do.

**Long description:**

> You wake in your own village the morning after it was plundered. One survivor is still there, and they will tell
> you where to go.
>
> Lowlands is a small top-down world that runs whether you are watching or not. Three tribes trade, hunt, farm and
> raid on their own schedule. Deer, boar and wolves breed and starve by region, so a forest you empty stays empty.
> Once a week something comes — a flood, or a beast tide — and you had better be inside walls or beside a fire
> when it does.
>
> Everything you do is remembered. Trade honestly and prices soften. Kill someone who never touched you and their
> village hears about it. Beat someone and let them live, and that is remembered too.
>
> WASD or a d-pad to walk. Click or tap to swing. F or the act button for everything else: talk, read a sign,
> trade, eat, give a gift, sleep.

**Genre:** Adventure. **Device:** Computer and Phone (both are supported; landscape is the intended orientation).

## Credits the game owes

`library/index.json` is the licence record for every borrowed asset. Anything CC-BY has to be credited wherever
the game is described. Today that is:

- Game icons by **lorc** — https://game-icons.net/ — CC-BY-3.0

Every sprite actually in the sheet is drawn in this repo, so this is the only outstanding attribution. Re-check
`library/index.json` before each publish; if it has grown, the new CC-BY entries go on the page too.

## After any sprite change

The image id is hard-coded in `Sprites.lua` (DESIGN.md §16), so a new sprite means a new upload, and a new upload
means a new id. The loop, every time:

```
npx warehouse roblox build --upload
```

Take the decal id it prints, then in the Studio command bar:

```lua
local d = game:GetObjects("rbxassetid://<decal id>")[1] print(d.Texture)
```

then:

```
npx warehouse roblox setid 0 <the number that printed>
```

and commit `roblox/src/shared/Sprites.lua` and `roblox/assets.lock.json` together. Skipping this does not show
blank tiles — it shows the *wrong* tiles, because every sprite's rectangle in the sheet shifts when one is added.

Newly uploaded images can render blank for about a minute while Roblox moderates them. Wait, then stop and restart
Play before suspecting anything else.

## What to watch once strangers are in

The bar part 4 set: **a new player knows what to do in the first minute without being told by a human.** The
things most likely to fail with real players on real phones:

- Do they find the survivor? There is a bobbing arrow over them and the banner says "Someone is calling you".
- Do they follow the goal line under the clock, or ignore it?
- Do fat fingers hit the d-pad and the four verb buttons, or miss between them?
- Does anyone get stuck in a panel? Every panel has an `x`, but that is the newest code here.
- Where do they stop playing, and was it boredom or confusion? Part 4 fixed confusion. Boredom is rung 3's job.
