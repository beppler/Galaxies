# Galaxies

A wireframe space trading/combat game in the spirit of classic 1980s space-trading games, written in
[Odin](https://odin-lang.org) with `vendor:raylib`. Runs on Windows, macOS and Linux.
The code is written from scratch, but the galaxy generation and commodity/market data follow
the design of the original *Elite* (3x16-bit "twist" seed, 8 galaxies x 256 systems, start at
Lave) and may be closely derived from it.

## Build

Toolchain is pinned in `mise.toml` (`mise install`).

Linux also needs X11/GL/ALSA dev
packages (`libx11-dev libxrandr-dev libxi-dev libxcursor-dev libxinerama-dev libgl1-mesa-dev libasound2-dev`) and clang.

```shell
./build.sh        # or build.bat on Windows;  ./build.sh run | test
```

## Controls

The game starts fullscreen; **F11** switches between fullscreen and windowed at any time.

### Flight

| Key | Action |
| --- | ------ |
| Arrows | Roll / pitch |
| A / D | Yaw |
| W / S | Speed up / down |
| Space | Fire laser |
| M | Fire missile |
| T | Compass: station / planet |
| H | Hyperspace to selected system |
| G | Galactic hyperdrive |
| F3 | Galactic chart (Enter sets destination) |

### Docked

| Key | Action |
| --- | ------ |
| F1 | Status |
| F2 | Market (B/S buy/sell, Shift = x10) |
| F3 | Galactic chart |
| F4 | Equipment |
| F5 / L | Launch |
| F9 | Save |

Docking: fly nose-first into the rotating station slot, match its roll, speed < 220.

Saves go to the user config dir (`Galaxies/save.json`) on dock/launch.

## Ideas / not yet done

Missions, more ship types, gamepad support.

## License

The code is released under the [MIT License](LICENSE); this does not extend to any rights in
the original game that the galaxy and market data may derive from. The bundled font, JetBrains Mono, is under
the SIL Open Font License (`assets/JetBrainsMono-OFL.txt`).

Galaxies is an independent fan project inspired by *Elite* (David Braben and Ian Bell). It is
not affiliated with or endorsed by the original authors, Acornsoft or Frontier Developments,
and "Elite" is a trademark of its owners.
