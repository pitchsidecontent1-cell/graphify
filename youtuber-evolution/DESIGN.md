# Game design

## Core loop
| Stat | What it does |
|---|---|
| **Views** | +1 × multipliers for every 3 studs walked (server-measured, so it can't be faked). Treadmills give views per second while you stand on them. |
| **Video level** | Views needed per level grow ×1.25 (`Economy.Video`). Views are never spent; your level is just how far your views reach. |
| **Gates** | 15 per world, each needing a Video level. They open locally for you (no waiting for others), and the server pushes back anyone who sneaks past. |
| **Clout pads** | Gold pads behind every gate. Claiming one pays clout (deeper gate = way more) and sends you back to spawn, so you walk again for more views. |
| **Devices** | 21 per world (cameras → phones → laptops → studio setups), bought in order with clout and kept forever. Your equipped device is your base views per step and is held in your hand. |
| **Evolution** | 20 tiers from Video level. Each adds gear (phone, headset, ring light, plaques, drones, cape, crown, wings, auras, orbiting planets) and makes you up to 1.6× bigger. |
| **Rebirth** | Needs Video 20 + 5 per rebirth. Resets Views/Videos for x2 views forever, +10% clout and +1 Niche Ticket. |
| **View War** | Each world's road ends at a rival creator. It's a 15-second tug-of-war, simulated on the server. Your views vs. theirs sets the base push, and tapping, trend bubbles and dodging their upload surges decide close fights. Winning unlocks the next world. |

## Side systems
- **Treadmills:** x1 / x2 / x3 / x4 / x5 (rebirth-locked), x25 (VIP pass), x100 (MEGA pass). You jog in place on the belt.
- **Pets:** 2 eggs per world, 5 pets each, with a Secret 0.1% pet in the final egg. Pets follow you, and their bonuses add up.
- **Niches:** 10 niches from x1.1 to x50, with visible odds, a pity counter (Epic+ every 50 rolls) and a lucky pass.
- **Upgrades:** walk speed, clout bonus, treadmill power.
- **Rewards:** 12 playtime gifts per session, a 7-day streak and codes. Most rewards scale with your progress ("Pads" = claims of your best pad).
- **Social:** friends +10% each (up to +50%), Premium +10%, group +10%, server-wide shout-outs for rare hatches/rolls/rival wins, global leaderboards and a live "top creator" board.

## Worlds
| # | World | Devices | Gates (Video) | Rival |
|---|---|---|---|---|
| 1 | Sunny Park | Cameras | 2 → 27 | Lil Clickbait (30) |
| 2 | Neon City | Phones | 32 → 74 | Thumbnail Tony (78) |
| 3 | Frosty Servers | Laptops | 82 → 138 | Reaction Rex (142) |
| 4 | Galaxy Studio | Studio setups | 146 → 202 | THE ALGORITHM (206, final boss) |

## Visual identity ("Creator Pop")
- **Sticker UI:** thick ink outlines, an inner white band, a glossy top half, and a drop shadow under every button.
- **Panels:** a film-strip sprocket band and a tilted title sticker on every panel.
- **Map:** stud plates, film-strip curbs and paths, a giant Creator Plaque monument, and gates that go wood → bronze → silver → gold → diamond.
