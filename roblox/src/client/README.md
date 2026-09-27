# client/ — syncs to `StarterPlayer.StarterPlayerScripts.Client`

Nothing here runs outside Studio. The whole system is described in [`docs/systems/client.md`](../../../docs/systems/client.md).

| File | Instance | What | Required by / returns | Lines |
| --- | --- | --- | --- | --- |
| `Client.client.lua` | `Client` (LocalScript) | remotes, input, prediction, camera, `promptFor` | nobody (entry point) | 659 / ceiling 660 |
| `Viewport.lua` | `Viewport` (ModuleScript) | the scrolling tile window, a ring buffer of ImageLabels | `Client` / the `Viewport` class (`new`) | 429 / 430 |
| `Hud.lua` | `Hud` (ModuleScript) | hearts, coin, bag, prompt, notices, dialogue, trade, standing, death | `Client` / the `Hud` class (`new`) | 1022 / 1025 |

All three sit 1–3 lines under their `test/structure.test.js` ceilings, which may only shrink (→ T4): any new line
must be paid for by removing one.
