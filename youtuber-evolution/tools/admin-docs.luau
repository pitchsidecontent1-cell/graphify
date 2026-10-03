-- Regenerates ADMIN.md from src/shared/Util/AdminCommands.luau:
--   lune run tools/admin-docs.luau
local fs = require("@lune/fs")
local A = require("../src/shared/Util/AdminCommands")

local out = {}
local function add(line: string)
	table.insert(out, line)
end

add("# Admin commands")
add("")
add("Every feature in the game can be tested with these. You're an admin automatically in **Roblox Studio**, in a game you")
add("own, or if your UserId is in `ReplicatedStorage.Shared.Config.Admin` (group games: rank `GroupMinRank` and up).")
add("")
add("## Four ways to run them")
add("")
add("| Where | How |")
add("|---|---|")
add("| **Admin panel** | Click the red 🛠️ **ADMIN** button (top right). Everything is a button, grouped in tabs. Use **TARGET** to apply it to someone else. |")
add("| **Command bar** | Press **;** (or **F2**). Type a command; it autocompletes. **Tab** fills in, **↑/↓** picks or scrolls history, **Esc** closes. |")
add("| **Chat** | `/clout 1m` (shows in the chat's / autocomplete) or `;clout 1m`. |")
add("| **Panel → COMMANDS tab** | Searchable list of everything below. **USE** opens the command bar with it filled in. |")
add("")
add("**Syntax:** `command <needed> [optional] [player]`")
add("")
add("- Numbers can be written as `1k`, `2.5m`, `3b`, `1t`, `1qa`, `1e12` or `1,000`.")
add("- `[player]` is optional and defaults to you. It can be `me`, `all`, `others`, or the start of someone's name (`clout 1m bob`).")
add("- Game passes given with `pass` last for the current session only. Rejoin, or use `unpass`, to go back.")
add("")
for _, category in A.Categories do
	add("## " .. category)
	add("")
	add("| Command | Also | What it does |")
	add("|---|---|---|")
	for _, c in A.List do
		if c.Category == category then
			local aliases = {}
			for _, alias in c.Aliases do
				table.insert(aliases, "`" .. alias .. "`")
			end
			local usage = string.gsub(A.Usage(c), "|", "\\|")
			add("| `" .. usage .. "` | " .. table.concat(aliases, " ") .. " | " .. c.Help .. " |")
		end
	end
	add("")
end
add("## Handy test recipes")
add("")
add("| Test | Commands |")
add("|---|---|")
add("| Gates + clout pads | `video 1`, then `addvideo 1` a few times and watch the gates open. Then `pad 3`. `video gates` opens every gate in your world |")
add("| Every evolution look | `evo 1`, then `evo next` again and again (NEXT EVO in the panel) |")
add("| Treadmills | `rebirths 14`, `pass vip`, `pass megatreadmill`, `goto treadmills` |")
add("| Rebirth flow | `video rebirth`, then press REBIRTH at the station (or force it with `rebirth`) |")
add("| Devices | `clout 1qa`, then buy them in the shop, or `devices` |")
add("| Eggs + pets | `clout 1qa`, `goto eggs` (real hatch animation), or `hatch starteregg 10` / `secretpet` |")
add("| Niche roll | `tickets 99`, `goto niche`, `pity 49` to test the pity system |")
add("| View War | `fight`, then play it, or `win` / `lose`. `resetrivals` to do it again from scratch |")
add("| Next worlds | `beat here`, then walk into the portal, or `world 3` |")
add("| Gifts + daily | `gifts`, `daily 7`, `resetcodes` |")
add("| Robux items | `pass all`, `product starterpack` (works before you've set real IDs) |")
add("| Fresh player | `reset confirm` |")
add("")
add("_This file is generated from `src/shared/Util/AdminCommands.luau` by `lune run tools/admin-docs.luau`._")
fs.writeFile("ADMIN.md", table.concat(out, "\n") .. "\n")
print("Wrote ADMIN.md (" .. #A.List .. " commands)")
