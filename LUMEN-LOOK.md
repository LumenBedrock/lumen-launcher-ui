# Lumen Launcher – new look

This folder is the launcher UI (`mcpelauncher-ui-qt`, upstream: `LumenBedrock/lumen-launcher-ui`, branch `lumen`)
based on 1.0.8, with the new design work:

- Five switchable designs, picked in the top right corner and saved: **Sun**, **Classic**, **Orbit**, **Nebula**, **Pixel**.
  Each brings its own navigation (sidebar, top bar, orbit arc, glass dock, hotbar), home screen and background.
- Colours per design: accent, glow, sky and tab bar; 16 presets each, a hex field and a full colour picker.
  Sub pages (servers, versions, log, settings) follow the colours.
- Quick join (Sun design): click a server planet to start the game and join it (`--uri minecraft://connect/...`).
  The game still shows its "external server" warning; skipping it needs the client (call `joinExternalServer`).
- Servers page opens instantly (folded sections are built on demand).
- Website fonts bundled (Inter, Sora, Silkscreen, Pixelify Sans, Outfit – all OFL, licences in `Resources/fonts`).

Not released yet: still needs a test build inside the Flatpak (KDE runtime 6.10), a version bump and a signed release.

## Build

```
git clone --recurse-submodules https://github.com/LumenBedrock/lumen-launcher
cd lumen-launcher
rm -rf mcpelauncher-ui-qt && cp -r /path/to/lumen/launcher mcpelauncher-ui-qt
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DLAUNCHER_VERSION_NAME=1.0.8
cmake --build build
```

Arch/CachyOS packages: `qt6-base qt6-declarative qt6-svg qt6-webengine qt6-5compat qt6-tools`.

