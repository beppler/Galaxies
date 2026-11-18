# Elite (Odin)

A wireframe space trading/combat game in the spirit of Acorn Elite, written in
[Odin](https://odin-lang.org) with `vendor:raylib`. Runs on Windows, macOS and Linux.
All code and models are original; the galaxy uses the classic 3x16-bit "twist" seed idea
(8 galaxies x 256 systems, start at Lave).

## Build
Toolchain is pinned in `mise.toml` (`mise install`). Linux also needs X11/GL/ALSA dev
packages (`libx11-dev libxrandr-dev libxi-dev libxcursor-dev libxinerama-dev libgl1-mesa-dev libasound2-dev`) and clang.

    ./build.sh        # or build.bat on Windows;  ./build.sh run | test

## Controls
Flight: arrows roll/pitch, Q/E yaw, W/S speed, SPACE laser, M missile, H hyperspace to the
selected system, G galactic hyperdrive, F3 galactic chart (ENTER sets destination), F11 fullscreen.
Docking: fly nose-first into the rotating station slot, match its roll, speed < 220.
Docked: F1 status, F2 market (B/S buy/sell, Shift = x10), F3 chart, F4 equipment, F5/L launch, F9 save.

Saves go to the user config dir (`odin-elite/save.json`) on dock/launch.

## Ideas / not yet done
Hidden-line removal, planets, missions, more ship types, gamepad support.
