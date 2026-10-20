# Ant Meadow build notes

Open ant-garden/project.godot in Godot 4.6.2. The APK is a signed ARM64 Android debug build for manual installation.

The game is entirely offline. Its art and audio are generated assets; no API key or external service is required.

## Checks completed

43 gameplay integration checks passed. Android API 24 emulator installation, rendering, touch collection, delivery, burst, pause/resume and background/foreground checks passed. Resume preserved the score. No Godot script errors or Android crashes were logged. The ARM64 APK signature and archive were verified. Physical device testing was not performed.

See validation/ for the exact results and APK SHA-256.

## Rebuild

Install JDK 17, Android SDK build tools 35 and Godot 4.6.2 Android export templates. Set the Android SDK and Java SDK paths in the Godot editor settings.

Signing keys are kept out of Git. The original development keystore is included only in the separately saved private source archive. To install an update over the delivered APK, configure that original keystore in the Godot editor settings. For a fresh installation, configure your own Android debug keystore. This project does not include a Play Store release key.

Create an out folder next to ant-garden, then run:

    godot --headless --path ant-garden --editor --import --quit
    godot --headless --path ant-garden -- --self-test
    godot --headless --path ant-garden --export-debug Android ../out/Ant-Meadow.apk

The AndroidTest export preset produces the x86_64 emulator build. tests/android_smoke.py exercises it with adb and Pillow using the touch target coordinates from the gameplay checks. Use a compliant emulator GLES driver, such as swangle, for rendering checks.
