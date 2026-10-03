# Balance

`lune run tools/simulate.luau build/base.rbxl` runs an idealised free player through the real Config. It skips pets, niches, passes and treadmills; pass a multiplier as the 2nd argument to include them.

| Milestone | Free player | With ~x8 from pets/niche/passes |
|---|---|---|
| First gates open | ~10 s | — |
| First rebirth | 3 min | ~1 min |
| Beat Lil Clickbait → World 2 | 7.5 min | 3 min |
| Beat Thumbnail Tony → World 3 | 28 min | 11 min |
| Beat Reaction Rex → World 4 | 80 min | 27 min |
| Beat THE ALGORITHM | 5.2 h | 1.2 h |

After the final boss, rebirths keep going forever (the requirement grows +5 Videos each time) for the global leaderboards.

## Knobs
- **Whole game slower/faster:** `Economy.Rebirth.VideoPerRebirth` (5). Raising it to 6 makes late game noticeably longer.
- **Early game:** `Economy.Video.Base/Growth` and the first gates in `Worlds[1].Gates`.
- **Clout vs. devices:** `Economy.Clout.Growth` against `Economy.Devices.CostGrowth`. Keep their ratio so each world's devices are affordable from that world's pads.
- **Gates per world:** edit the Video lists in `Worlds`. The map rebuilds from the list automatically (`Layout.GateZ`).
