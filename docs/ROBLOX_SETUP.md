# Roblox setup: from this repo to a running game

Two pipes connect this repo to Roblox Studio:

| What            | How it travels                                         | Tool                    |
| --------------- | ------------------------------------------------------ | ----------------------- |
| Lua code        | files in `roblox/src/` sync live into Studio            | Rojo 7.7.0              |
| Images          | uploaded once, referenced by asset id in `Sprites.lua`  | Open Cloud API (or manual) |

Roblox cannot load an image from a file or a URL. Every image must be uploaded to Roblox and gets an
**asset id**. The Warehouse packs all your sprites into one sheet, uploads it, and writes the id into
`roblox/src/shared/Sprites.lua`. Rojo syncs that file into Studio. That's the whole trick.

## 1. Install Node and the tool

```bash
# Node 20 or newer: https://nodejs.org
git clone <this repo>
cd The-Warehouse
npm install
npm start            # opens http://localhost:4242
```

`npx warehouse help` lists every command. On Windows use PowerShell or Git Bash, everything is plain Node.

## 2. Install Rojo 7.7.0

Release page: https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0

**Option A, Rokit (recommended, pins the version from `rokit.toml`):**

1. Install Rokit: https://github.com/rojo-rbx/rokit#installation
2. In the repo root run `rokit install`. That installs Rojo 7.7.0 for this folder.

**Option B, download the binary** from the release page for your OS and put it on your PATH.

Then, once:

```bash
rojo plugin install        # installs the Studio plugin
```

## 3. Connect Studio

1. Open Roblox Studio, create a new **Baseplate** place (or open your game). Save it to Roblox (File > Publish).
2. In the repo root run:
   ```bash
   rojo serve roblox/default.project.json
   ```
3. In Studio: **Plugins** tab > **Rojo** > **Connect** (default address `localhost:34872`).
4. Studio now mirrors `roblox/src/`. Edit a Lua file here, it updates in Studio instantly.

What the project puts where:

| Repo file                             | Studio location                                     |
| ------------------------------------- | --------------------------------------------------- |
| `roblox/src/shared/*.lua`             | `ReplicatedStorage.Shared`                          |
| `roblox/src/client/Client.client.lua` | `StarterPlayer.StarterPlayerScripts.Client`         |
| `roblox/src/server/Server.server.lua` | `ServerScriptService.Server`                        |
| (project file)                        | `ReplicatedStorage.RainState` (RemoteEvent)         |

Press **Play**. You should see a walled room, a slug you can move with WASD, and rain every 90 seconds.
If the tiles are blank, the sprite sheet has not been uploaded yet: continue below.

## 4. Make an Open Cloud API key (about two minutes)

1. Go to https://create.roblox.com/dashboard/credentials (Creator Hub > Open Cloud > API Keys).
2. Click **Create API Key**.
3. Name: `warehouse`.
4. Under **Access Permissions**, click **Select API System** and choose **Assets**.
   Tick both operations: **Read** and **Write**.
5. Under **Security**:
   - **Accepted IP Addresses**: add `0.0.0.0/0` while developing (any IP). Tighten later if you want.
   - **Expiration**: pick a date or "No Expiration".
6. Click **Save & Generate Key**, then **Copy Key To Clipboard**. You only see it once.
7. Find your **user id**: open your profile on roblox.com. The URL looks like
   `https://www.roblox.com/users/123456789/profile`. The number is your id.
   (If the game belongs to a group, use the group id from the group URL instead.)
8. In the repo root, copy `.env.example` to `.env` and fill in:
   ```
   ROBLOX_API_KEY=paste-the-key-here
   ROBLOX_CREATOR_USER_ID=123456789
   ```
   `.env` is ignored by git. Never commit it, never paste the key into chat.

## 5. Build and upload the sprite sheet

```bash
npx warehouse roblox build --upload
```

This renders every scene in `scenes/` (except ones with `"export": false` or excluded in
`roblox/sheet.json`), packs them into `exports/roblox/sheet_0.png`, uploads it as a Decal, waits for the
asset id, and rewrites `roblox/src/shared/Sprites.lua`. Rojo pushes the new module into Studio. Stop and
re-Play the game and the art is live.

Unchanged sheets are not re-uploaded (hash stored in `roblox/assets.lock.json`). Every changed sprite means a
new upload and a new id; that is normal.

After an upload, commit the two files that now carry the asset id so the repo (and Claude) know about it:

```bash
git add roblox/src/shared/Sprites.lua roblox/assets.lock.json
git commit -m "Record uploaded sprite sheet asset id"
git push
```

**Manual alternative** if you do not want an API key yet:

1. `npx warehouse roblox build` (no upload). It writes `exports/roblox/sheet_0.png`.
2. Upload that PNG at https://create.roblox.com/dashboard/creations > **Development Items** > **Decals** > **Upload Asset**.
3. Copy the id from the new decal's URL and run `npx warehouse roblox setid 0 <id>`.

## 6. Using sprites in Lua

```lua
local Sprites = require(ReplicatedStorage.Shared.Sprites)
local img = Sprites.New("slug_idle", someFrame)   -- new ImageLabel showing the sprite
Sprites.Apply(existingImageLabel, "wall_stone")    -- or repoint an existing one
```

Every sprite is a named entry: the scene file name in `scenes/` is the sprite name. `Grid.lua` builds the
screen-filling tile grid on top of that. Pixels stay crisp because `Apply` sets `ResampleMode = Pixelated`.

## Troubleshooting

- **Decal id vs image id (black play area, no errors, decal looks fine on Creator Hub).** An Open Cloud upload
  creates a *Decal*; the picture inside it is a separate *Image* asset with a different id, and `ImageLabel.Image`
  needs the image id. `roblox build --upload` looks it up automatically. If the terminal said it could not, get it
  by hand: in Studio insert a ScreenGui > ImageLabel, paste the decal id into its **Image** property, and Studio
  rewrites it to the image id. Then run `npx warehouse roblox setid 0 <image id>` and Play. Delete the test ScreenGui.

- **Images show as blank for a minute after upload**: Roblox moderates images. Wait, then re-Play.
- **`Roblox upload failed 401/403`**: wrong key, key expired, IP restriction, or the Assets API system is missing
  Write permission. Regenerate the key with step 4.
- **`403 ... creator`**: the creator id in `.env` is not you (or you are not a member of the group with asset permissions).
- **Sheet bigger than 1024**: Roblox caps images at 1024x1024. The packer automatically starts `sheet_1.png`.
- **Rojo says "no project file"**: run it from the repo root with the explicit path shown in step 3.
- **Studio DataStores later**: Game Settings > Security > **Enable Studio Access to API Services**.
