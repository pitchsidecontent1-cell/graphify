# Admin commands

Every feature in the game can be tested with these. You're an admin automatically in **Roblox Studio**, in a game you
own, or if your UserId is in `ReplicatedStorage.Shared.Config.Admin` (group games: rank `GroupMinRank` and up).

## Four ways to run them

| Where | How |
|---|---|
| **Admin panel** | Click the red 🛠️ **ADMIN** button (top right). Everything is a button, grouped in tabs. Use **TARGET** to apply it to someone else. |
| **Command bar** | Press **;** (or **F2**). Type a command; it autocompletes. **Tab** fills in, **↑/↓** picks or scrolls history, **Esc** closes. |
| **Chat** | `/clout 1m` (shows in the chat's / autocomplete) or `;clout 1m`. |
| **Panel → COMMANDS tab** | Searchable list of everything below. **USE** opens the command bar with it filled in. |

**Syntax:** `command <needed> [optional] [player]`

- Numbers can be written as `1k`, `2.5m`, `3b`, `1t`, `1qa`, `1e12` or `1,000`.
- `[player]` is optional and defaults to you. It can be `me`, `all`, `others`, or the start of someone's name (`clout 1m bob`).
- Game passes given with `pass` last for the current session only. Rejoin, or use `unpass`, to go back.

## Progress

| Command | Also | What it does |
|---|---|---|
| `video <level\|rebirth\|gates> [player]` | `setvideo` `vid` | Set the Video level (1-400). rebirth / gates = just enough to rebirth / open every gate here |
| `addvideo <amount> [player]` | `av` | Add (or remove, with -) Video levels |
| `views <amount> [player]` | `addviews` | Add views (1k, 2.5m, 1e9...) |
| `evo <tier\|next\|prev> [player]` | `evolve` `tier` | Jump to an Evolution tier (1-20), or the next / previous one |
| `clout <amount> [player]` | `setclout` | Set your clout |
| `addclout <amount> [player]` | `ac` | Add clout |
| `tickets <amount> [player]` | `tix` | Set your Niche Tickets |
| `rebirths <count> [player]` | `setrebirths` | Set the rebirth count, 0-77 (keeps views) |
| `rebirth [player]` | `rb` | Rebirth right now (no Video needed) |
| `upgrade <speed\|clout\|treadmill\|all> [level\|max] [player]` | `upg` | Set an upgrade level (default max) |
| `max [player]` | `maxall` | Max everything: worlds, rivals, devices, upgrades, video, clout, passes |
| `reset <confirm> [player]` | `wipe` | Wipe a save back to a new player |

## World

| Command | Also | What it does |
|---|---|---|
| `world <1-4> [player]` | `tpworld` | Unlock + teleport to a world |
| `unlockworlds [player]` | `worlds` | Unlock every world |
| `gate <1-15> [player]` | `tpgate` | Teleport in front of a gate in your world |
| `pad <1-15> [player]` | `tppad` | Teleport onto a clout pad (claims it if open) |
| `goto <place\|player> [player]` | `tp` `to` | Teleport to spawn, arena, treadmills, devices, upgrades, rebirth, niche, eggs, portal - or to a player |
| `bring <player>` |  | Bring players to you |
| `spawn [player]` | `home` | Back to your world's spawn |
| `speed [speed] [player]` | `ws` | Walk speed override (no number = normal) |
| `fly [player]` |  | Toggle flying (WASD + camera, Space/E up, Q/Ctrl down) |
| `noclip [player]` | `ghost` | Toggle walking through walls and locked gates |
| `respawn [player]` | `re` `refresh` | Respawn your character |

## Items

| Command | Also | What it does |
|---|---|---|
| `devices [player]` | `alldevices` | Own every device + equip the best |
| `device <number\|id\|name> [player]` | `givedevice` | Give + equip one device |
| `cleardevices [player]` |  | Back to just the starter device |
| `niche <name\|none> [player]` | `setniche` | Set your niche |
| `pity <count> [player]` |  | Set the niche pity counter (50 = next roll Epic+) |
| `potion <views\|clout\|all> [minutes] [player]` | `boost` | Give an x2 potion (0 minutes clears it) |
| `friends <count> [player]` |  | Fake the friends-in-server boost (0-10) |
| `premium [player]` |  | Toggle the Premium boost |
| `group [player]` |  | Toggle the group boost |

## Pets

| Command | Also | What it does |
|---|---|---|
| `pet <name\|id> [count] [player]` | `givepet` | Give a pet (names without spaces: galaxydragon) |
| `allpets [player]` |  | One of every pet (equips the best) |
| `secretpet [player]` | `algopet` | Give The Algo Pet (Secret) |
| `clearpets [player]` |  | Delete every pet |
| `hatch <egg> [count] [player]` |  | Free hatch with the real odds |

## Rewards

| Command | Also | What it does |
|---|---|---|
| `gifts [player]` | `readygifts` | Make every playtime gift claimable now |
| `resetgifts [player]` |  | Lock the gifts again + restart the timer |
| `daily [day 1-7] [player]` |  | Make the daily reward claimable now |
| `resetcodes [player]` | `codes` | Let codes be redeemed again |
| `tutorial [player]` |  | Replay the tutorial |

## Rivals

| Command | Also | What it does |
|---|---|---|
| `fight [player]` | `battle` `war` | Start this world's View War now (no requirements) |
| `win [player]` |  | Instantly win the current View War |
| `lose [player]` |  | Instantly lose the current View War |
| `beat [world\|all\|here] [player]` |  | Mark a rival beaten + unlock the next world (default: this world) |
| `resetrivals [player]` |  | Un-beat every rival and lock worlds 2-4 |
| `nocooldown [player]` | `nocd` | Clear rival rematch cooldowns |

## Robux

| Command | Also | What it does |
|---|---|---|
| `pass <pass\|all> [player]` | `givepass` | Give a game pass (this session only) |
| `unpass <pass\|all> [player]` | `revokepass` | Remove a game pass (this session) |
| `product <product> [player]` | `buy` | Test a dev product without paying |

## Server

| Command | Also | What it does |
|---|---|---|
| `announce <message>` | `say` `m` | Message everyone in the server |
| `fx <video\|evolve\|rebirth\|claim\|world\|reward\|purchase> [player]` | `effect` | Play a celebration effect |
| `stats [player]` | `info` | Show stats + multipliers |
| `save [player]` |  | Save now |
| `lb` | `leaderboards` | Refresh the global leaderboards now |
| `cmds` | `commands` `help` `?` | List every command |

## Handy test recipes

| Test | Commands |
|---|---|
| Gates + clout pads | `video 1`, then `addvideo 1` a few times and watch the gates open. Then `pad 3`. `video gates` opens every gate in your world |
| Every evolution look | `evo 1`, then `evo next` again and again (NEXT EVO in the panel) |
| Treadmills | `rebirths 14`, `pass vip`, `pass megatreadmill`, `goto treadmills` |
| Rebirth flow | `video rebirth`, then press REBIRTH at the station (or force it with `rebirth`) |
| Devices | `clout 1qa`, then buy them in the shop, or `devices` |
| Eggs + pets | `clout 1qa`, `goto eggs` (real hatch animation), or `hatch starteregg 10` / `secretpet` |
| Niche roll | `tickets 99`, `goto niche`, `pity 49` to test the pity system |
| View War | `fight`, then play it, or `win` / `lose`. `resetrivals` to do it again from scratch |
| Next worlds | `beat here`, then walk into the portal, or `world 3` |
| Gifts + daily | `gifts`, `daily 7`, `resetcodes` |
| Robux items | `pass all`, `product starterpack` (works before you've set real IDs) |
| Fresh player | `reset confirm` |

_This file is generated from `src/shared/Util/AdminCommands.luau` by `lune run tools/admin-docs.luau`._
