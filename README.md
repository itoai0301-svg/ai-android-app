# Ant Meadow

A complete native, offline 3D ant game for Android, built with Godot 4.6.2.

Open `ant-garden/project.godot` in Godot to run or edit the game. Collect snacks, return them to the nest, avoid beetles, and use Burst for a short sprint. The game includes touch controls, navigation, animated ants, procedural garden scenery, custom shaders, original audio, multiple days, pause/resume and a saved best score.

## Source and builds

- `ant-garden/`: complete game code, scenes, shaders, audio, icon and Android export presets.
- `tests/android_smoke.py`: Android emulator touch and lifecycle checks.
- `validation/`: results from the delivered APK's 43 gameplay checks, Android emulator checks and signature verification.
- [BUILD-NOTES.md](BUILD-NOTES.md): Android dependencies, signing and rebuild commands.

The tested APK supports ARM64 Android 7.0 and newer. No API key or network connection is required. Build tools, generated APKs, imported caches and signing keys are excluded from Git. The original signing key remains in the separately saved private source archive for future updates.

The earlier Alien Rift game remains at the repository root. Its existing Android workflow runs on `main`; Ant Meadow is the project in `ant-garden/` on this branch.
