# Architecture

Galaxies is a single-package [Odin](https://odin-lang.org) program (`package main`, all files in
`src/`) using `vendor:raylib` for window, input, 2D lines/text and audio. There are no other
dependencies and no assets besides the embedded JetBrains Mono font. About 2,600 lines in total.

## Overview

One global `Game` struct (`g`, in `game.odin`) holds all mutable state. Each frame `main` calls
`update(dt)` and then one `draw_*` proc chosen by `g.state`. There is no scene graph or ECS:
entities live in a flat `[dynamic]Entity` and procs operate on the globals directly.

```text
main.odin  ── window, scale, main loop
   │  update(dt)                         draw_*()
   ▼                                        ▲
game.odin ── state machine, flight sim, combat, AI ──► render.odin ── 3D wireframe + HUD
   │  │                                                     ▲
   │  └─► ui.odin ── docked screens, chart, buy/sell        │ models
   │          │                                         ships.odin ── vertex/edge/face data
   ▼          ▼
galaxy.odin   market.odin    save.odin    audio.odin    math3d.odin    platform.odin
(systems)     (prices)       (JSON)       (synth SFX)   (Basis)        (input shims)
```

## Files

| File | Responsibility |
| ---- | -------------- |
| `main.odin` | Window setup, UI scale detection (`GALAXIES_UI_SCALE` override), F11 fullscreen, the frame loop, `free_all(context.temp_allocator)` per frame. |
| `game.odin` | `Game`, `Player`, `Entity` types; the global `g`; `new_game`, `launch`, `do_dock`, hyperspace jumps; flight update, combat (lasers, missiles, damage), enemy AI and spawning; top-level `update`. |
| `ui.odin` | Docked-mode input and drawing: status, market (buy/sell), equipment, and the galactic chart (shared with flight via F3). |
| `render.odin` | Projection, hidden-line wireframe model drawing, starfield, planet, HUD, font/text helpers, and `draw_flight/hyper/dead`. |
| `ships.odin` | `ShipId`/`ShipDef` table (NPC hull stats: hp, speed, turn, fire damage, bounty; add a ship by adding a row) plus the `ModelId` enum and the static mesh data (Cobra, Sidewinder, Viper, Krait, Freighter, Cutter, Missile, Canister, Asteroid, Shard, Station); `init_models` precomputes face normals and edge-to-face masks. |
| `galaxy.odin` | Deterministic procedural galaxy: 3×16-bit "twist" seed → 8 galaxies × 256 systems (`System`: position, government, economy, tech, name). |
| `market.odin` | 17 commodities, `make_market` (price and quantity from system economy plus a hash-based fluctuation), money/cargo helpers, `rank_name`. |
| `save.odin` | `SaveData` ↔ JSON, atomic write, validating load. |
| `audio.odin` | Sound effects synthesized at startup into `rl.Sound`s (no audio files). |
| `math3d.odin` | `Vec3`, `Basis` (orthonormal right/up/forward axes) with `pitch/yaw/roll`, `to_local/to_world`. |
| `platform.odin` | Thin wrappers for key/mouse input that are inert stubs under `ODIN_TEST`. |
| `*_test.odin` | Tests (see below). |

## State machine

`g.state` (`State`) drives both update and draw:

```text
         launch()                     H / G
 Docked ─────────► Flight ───────────────────► Hyper
   ▲  ▲              │  │                         │ timer ends: finish_jump()
   │  └── do_dock() ─┘  │ hull <= 0               ▼
   │                    ▼                      arrive_by_jump() ─► Flight
   └──── Enter ──────  Dead   (reload last save, or new_game())
```

`g.screen` (`Status`, `Market`, `Chart`, `Equip`) selects the sub-screen. Docked uses all four;
Flight uses only `Status` (the 3D view) and `Chart` (F3).

## Game world

- **Coordinates.** The station sits at the origin; the planet is placed relative to it
  (`make_planet`, size and line pattern derived from the system). The player is just a position
  plus a `Basis`; the camera is the player.
- **Entities.** `Entity` is one struct for every object, discriminated by `Kind` (Pirate, Trader,
  Police, Asteroid, Canister, Missile, Debris). `flight_update` switches on `kind` per frame.
  The station is a separate `g.station` entity.
- **Deferred spawn/removal.** `spawn` appends to `g.pending`; `flush_pending` merges it into
  `g.ents` at the end of the frame, so spawning never invalidates pointers mid-iteration. Dead
  entities (`alive = false`) are removed with `unordered_remove` at frame end. Entities reference
  each other by `id` (`find_ent`), never by pointer.
- **Each jump = new system.** `arrive_by_jump` rebuilds the world; `epoch` is incremented so the
  market is re-rolled.
- **AI.** `update_ship_ai`: hostile ships steer at and shoot the player, flee below 25% hull;
  others wander between random waypoints. Enemy type depends on the system's government
  (`spawn_enemy`).

## Procedural data

Everything about a system is a pure function of seeds, so none of it is saved:

- `gen_galaxy(n)` → 256 `System`s from `BASE_SEED`, rotated `n` times per galaxy.
- `make_market(sys, seed)` where the seed mixes system index, galaxy number and `epoch`. Prices
  and quantities are therefore stable while you stay, and change after each jump.

Money is in tenths of a credit, fuel in tenths of a light year, throughout.

## Rendering

Pure 2D raylib line drawing with a hand-written 3D pipeline in `render.odin`:

1. `update_view` computes viewport size and focal length each frame (HUD takes the bottom
   `HUD_H` pixels).
2. `draw_model` transforms vertices into camera space, culls models behind the camera, computes a
   visible-face bitmask (`face_vis`), and draws only edges with no adjacent faces or at least
   one front-facing adjacent face (hidden-line removal). `draw_line3` clips against a near plane
   and projects. The station's docking slot interior has special clipping (`slot_clip`).
3. The whole frame is drawn under `rlgl.Scalef(ui_scale, ui_scale, 1)`; `view` and mouse
   coordinates are in scaled units.

Mesh faces are limited to 32 per model (u32 masks) and must be planar; `set_model` asserts both.

## Docking computer

Bought in the F4 equipment screen (`Player.dock_comp`). In flight, `dock_comp_ready` is true when
the ship is in front of the slot (within 3x the slot size, up to 1500 units out) and nose-on to it;
the HUD then shows a hint and C calls `do_dock` via `dock_comp_try`. Roll and speed are ignored.
It is not an autopilot, and the strict `dock_check` still applies without it.

## Persistence

`save.odin` writes `save.json` in the user config dir (`Galaxies/`) on launch and dock (and F9).
Writes go to `save.json.tmp` then rename. `load_game` validates via `apply_save`
(range checks, clamping); an unusable file is renamed `save.json.bad`. Only player progress is
stored (galaxy, system, target, cash, fuel, missiles, cargo, kills, flags such as the galactic
hyperdrive and docking computer, epoch). Flight state is
never saved: you always resume docked. After death, Enter reloads the last save.

## Testing

`./build.sh test` (`odin test src`, single-threaded). Tests: `galaxy_test.odin` (generation),
`save_test.odin` (round trip), `sim_test.odin` (headless flight simulation, docking, save clamping).
Because tests run without a window, input and audio go through `platform.odin` / `play` stubs under
`when ODIN_TEST`, and `save_path` refuses to touch the real config dir unless `save_dir` is set.
On Windows, linking raylib into the test binary breaks the runner, hence the stubs.

## Build and CI

`build.sh` / `build.bat` wrap `odin build src -o:speed` (`test`, `run` subcommands; `build.bat debug`
keeps the console on Windows). The toolchain is pinned in `mise.toml`. GitHub Actions
(`.github/workflows/test.yml`) runs tests and a release build on Ubuntu and Windows; the Windows
release is built with `-subsystem:windows`.
