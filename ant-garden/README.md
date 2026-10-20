# Ant Meadow

A native, offline 3D Android garden game built with Godot 4.6.2.

Tap a snack to walk to it. Food is collected automatically. Tap **DELIVER** to bring it to the nest. Steer with the touch pad; use **BURST** to escape the beetles. Deliver every snack to open the next day. Three hearts, pause/resume, sound controls and a saved best score are included.

Desktop: WASD/arrows to move, Space to burst, H to return home, Esc to pause.

The game uses procedural 3D geometry, moving grass, custom ground and water shaders, animated six-legged ants, sun shadows, pond, mushrooms, clover, flowers, berries and original audio. No network connection or API is required.

## Validation

`godot --headless --path ant-garden --editor --import --quit`
`godot --headless --path ant-garden -- --self-test`

The delivered APK targets ARM64 Android 7.0 and newer. It is signed for manual installation.

This build passed 43 integration checks, including a complete expedition, the next day, damage, retry, pause, sound and real touch input. A separate x86_64 build from the same game source passed installation, rendering, touch collection and delivery, burst, pause/resume and background/foreground tests on an Android API 24 emulator at 1280 × 720. Both resume tests preserved the score. No Godot script errors or Android crashes were logged.

Open this folder in Godot 4.6.2 to edit the game. Android export requires JDK 17, Android SDK build tools 35 and the matching Godot Android export template. See the bundle's BUILD-NOTES.md for signing and repeat builds.

