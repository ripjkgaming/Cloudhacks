# Fossil Dig — a Roblox digging game

Dig up fossils, sell them at the Museum, buy better pickaxes and bigger backpacks, unlock new dig zones, and complete quests.
Everything (map, UI, effects, animation) is generated in Luau code, so there are **no external assets to import**.

## Run it

You need [Roblox Studio](https://create.roblox.com/) and [Rojo](https://rojo.space/docs/v7/getting-started/installation/) 7.4+.

```bash
aftman install          # or: install rojo 7.4.4 manually
rojo build -o FossilDig.rbxl   # then open FossilDig.rbxl in Studio
# — or live-sync —
rojo serve              # then click "Connect" in the Rojo plugin inside an empty baseplate
```

Press **Play**. To test saving in Studio enable *Game Settings → Security → Enable Studio Access to API Services*
(without it the game still runs; progress just isn't persisted).

### Roblox Studio MCP

This repo was authored in a cloud sandbox with no desktop Studio, so it could not drive Studio over MCP directly.
To have an AI assistant work with the live place, install Roblox's official Studio MCP server on your machine
(Studio → Assistant / MCP settings, or the `Roblox/studio-rust-mcp-server` project) and point your client at it, then use
`rojo serve` so file edits and Studio stay in sync.

## How it plays

| Action | How |
|---|---|
| Walk to the first zone | Bridge south of the hub (sign points the way) |
| Dig | Hold **Click**, **F**, gamepad **R2**, or the on-screen ⛏ button near a dirt mound with a bone sticking out |
| Sell | Walk to the Fossil Museum counter, press **E** |
| Shop / Quests / Collection / Map | **B** / **Q** / **C** / **M** or the right-hand buttons |

* **Mounds** shrink with each hit and pop back after a respawn timer. Higher pickaxe *Power* breaks them in fewer hits.
* **Luck** on pickaxes shifts loot odds toward rarer fossils (Common → Mythic). Legendary+ finds are announced server-wide.
* **Backpack** has a capacity; sell before it fills.
* **5 zones** (Dusty Quarry → Fern Hollow → Amber Dunes → Frostbite Tundra → Magma Depths), each with its own props, weather, lighting and loot table.
* **22 quests** driven purely off player stats (finds, coins earned, species discovered, upgrades, rarity finds, zones) with claim rewards.
* **30 fossils** in a discoverable collection log.

## Polish

* Procedural pickaxe swing (wind-up → strike → recover) by tweening R15 shoulder/waist joints; nearby players see each other's swings.
* Squash-and-stretch mounds, dust bursts, fossil reveal fly-out with rarity-coloured beams / shock rings, screen flash and FOV pulse for Epic+.
* Per-zone lighting, atmosphere and colour grading cross-fade as you travel, with a zone title banner.
* Animated UI: count-up coins, pop-in panels, button hover/press feedback, toast stack, find popup with NEW! badge, phone scaling.

## Performance choices

* All world parts are `Anchored`; decorations are non-colliding / non-queryable / non-shadow-casting. No meshes, unions or per-part scripts.
* Mound shrinking, fading and effects are **client-side tweens** driven by two replicated attributes (`Hp`, `Depleted`) — no per-hit server property writes.
* One weather emitter per zone; dust emitters are created lazily and reused; hit/swing effects are only sent to players within 150 studs.
* Server validates every swing (distance, cooldown, zone unlock, backpack space); all rolls and purchases are server-side.

## Layout

```
default.project.json
src/shared/Config.luau       all design data: fossils, zones, pickaxes, backpacks, quests, sounds
src/shared/Remotes.luau      remote events/functions
src/server/                  DataService, DigService, ShopService, QuestService, PickaxeVisual, WorldBuilder, Main
src/client/                  UI, DigController, Swing, Effects, SpotVisuals, ZoneAtmosphere, Audio, State, Main
```

Tuning the game is mostly editing `Config.luau`. Sound ids there are Roblox built-in placeholders — swap in your own
asset ids for better audio.

## Known limitations

* Written without access to a running Studio: it parses, builds with Rojo and its config/economy logic is unit-checked,
  but visuals (pickaxe grip angle, prop placement) are untested in-engine and may need small tweaks.
* Swing animation and pickaxe visual require **R15** avatars (R6 players can still dig, without the animation).
* Saving uses a simple `UpdateAsync` per player without session locking.
