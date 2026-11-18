# Galaxies

A wireframe space trading/combat game in the spirit of classic 1980s space-trading games, written in
[Odin](https://odin-lang.org) with `vendor:raylib`. Runs on Windows, macOS and Linux.
The code is written from scratch, but the galaxy generation and commodity/market data follow
the design of the original *Elite* (3x16-bit "twist" seed, 8 galaxies x 256 systems, start at
Lave) and may be closely derived from it.

## Build
Toolchain is pinned in `mise.toml` (`mise install`). Linux also needs X11/GL/ALSA dev
packages (`libx11-dev libxrandr-dev libxi-dev libxcursor-dev libxinerama-dev libgl1-mesa-dev libasound2-dev`) and clang.

    ./build.sh        # or build.bat on Windows;  ./build.sh run | test

## Controls
Flight: arrows roll/pitch, Q/E yaw, W/S speed, SPACE laser, M missile, H hyperspace to the
selected system, G galactic hyperdrive, F3 galactic chart (ENTER sets destination), F11 fullscreen.
Docking: fly nose-first into the rotating station slot, match its roll, speed < 220.
Docked: F1 status, F2 market (B/S buy/sell, Shift = x10), F3 chart, F4 equipment, F5/L launch, F9 save.

Saves go to the user config dir (`Galaxies/save.json`) on dock/launch.

## Ideas / not yet done
Planets, missions, more ship types, gamepad support.

## License
The code is released under the [MIT License](LICENSE); this does not extend to any rights in
the original game that the galaxy and market data may derive from. The bundled font, JetBrains Mono, is under
the SIL Open Font License (`assets/JetBrainsMono-OFL.txt`).

Galaxies is an independent fan project inspired by *Elite* (David Braben and Ian Bell). It is
not affiliated with or endorsed by the original authors, Acornsoft or Frontier Developments,
and "Elite" is a trademark of its owners.
