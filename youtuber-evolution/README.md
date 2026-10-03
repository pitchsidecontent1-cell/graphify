# +1 YouTuber Evolution

A complete Roblox "+1 per step" simulator. Every step you take gives you **+1 View** (× your multipliers). Here's the loop:

1. Views level up your **Video** bar.
2. Videos open the **gates** down the road.
3. Gold **clout pads** behind each gate pay **Clout**.
4. Clout buys **devices**, **upgrades** and **pets**.
5. **Rebirth** for x2 views, then do it all again faster.
6. As you level up, your character **evolves**. You grow bigger and get a phone, headset, ring light, drones, a cape and wings.
7. Beat each world's **rival creator** in a **VIEW WAR** to unlock the next world.

Everything is already built: 4 themed worlds, 60 gates, 84 devices, 40 pets, 20 evolutions, niche rolls, treadmills, rewards, a Robux shop, leaderboards, an admin panel and a sticker-style UI. No meshes or images are needed.

---

## 1. Open it in Roblox Studio (2 minutes)

1. Download **`YoutuberEvolution.rbxl`** from this folder.
2. Double-click it, or in Studio use **File → Open from File…**. The whole map is already there.
3. Press **Play** (F5). Walk around: your views go up, gates open, and you can claim clout.
4. In Studio you're an admin, so a 🛠️ button appears top-right. It can give you Videos, clout and tickets, unlock worlds, and test every Robux item.

### Make saving work
DataStores only work in a published game:
1. **File → Publish to Roblox** (create a new game).
2. **Home → Game Settings → Security** and turn on **Enable Studio Access to API Services**.
3. Play again. The "Studio test mode" warning disappears and progress saves.

### Add your Robux items
1. On the [Creator Hub](https://create.roblox.com), open your game → **Monetization**, then create the **Passes** and **Developer Products**.
2. Paste each ID into **`ReplicatedStorage.Shared.Config.Products`** (the `Id = 0` fields).

Items left at `Id = 0` show "Coming soon" in game.

---

## 2. Where things are

| You want to change… | Edit this (in Studio: ReplicatedStorage › Shared › Config) |
|---|---|
| Gate requirements, world names, rivals, colours, lighting | `Worlds` |
| Devices (names, colours) | `Devices` (values/prices come from `Economy.Devices`) |
| Speed of the whole game (videos, rebirth, clout) | `Economy` |
| Evolution titles + gear | `Evolutions` |
| Treadmills (x1…x100) | `Treadmills` |
| Eggs + pets | `Pets` |
| Niches + odds | `Niches` |
| Gifts, daily rewards, codes | `Rewards` |
| Game passes + products | `Products` |
| Icons / sounds / music | `Assets` (see ASSETS_TODO.md) |
| UI colours + fonts | `Theme` |
| Extra admins | `Admin` |

The **map** lives in `Workspace.Map`, and you can move or decorate anything there. Gameplay only finds pieces by their **tags + attributes** (e.g. a part tagged `GateBarrier` with `World`, `Gate` and `Video` attributes). So if you duplicate a gate, keep its tag and attributes and it will just work. If you delete `Workspace.Map`, the server rebuilds the original map at startup.

---

## 3. Project layout (for coders / Claude Code)

```
src/shared   → ReplicatedStorage.Shared      config, formulas (Util/Stats), model builders
src/server   → ServerScriptService.Server    Main + Services/* (+ Map/ builders)
src/client   → StarterPlayerScripts.Client   Main + Controllers/* + UI/* (UIKit, HUD, Panels)
tools/       bake (map → place), simulate (economy), preview renders
```

Server services: Data (session-locked saving), Map, Progress, Character (gear/size/nametag), Movement (steps, treadmills, gates, pads, portals), Shop, Rebirth, Reward, Monetization, Pet, Niche, Rival (VIEW WAR), Leaderboard, Admin, Boost.

### Rebuilding the place file from source
You only need this if you edit the `.luau` files outside Studio. It requires [Rokit](https://github.com/rojo-rbx/rokit) (`rokit install` installs Rojo, Lune, StyLua and luau-lsp).
```
./build.sh        # rojo build + bake the map → YoutuberEvolution.rbxl
./check.sh        # strict type-check against the Roblox API + formatting
lune run tools/simulate.luau build/base.rbxl   # check game pacing
```
For live editing, run `rojo serve` and connect the Rojo Studio plugin.

---

## 4. Before you publish
- Add your UserId to `Config/Admin` (or rely on the owner check) so only you get the admin panel.
- Upload a few icons and sounds (ASSETS_TODO.md) for extra polish. The emoji icons work fine in the meantime.
- Set real gamepass/product IDs.
- Optional: set `Products.GroupId` for the +10% group bonus.
