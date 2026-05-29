# BMHeroRecomp Android port

Current status: Android/arm64 bring-up builds, installs, and reaches the main menu on a real Android device.

## What works

- Android Gradle project exists under `android/`.
- SDLActivity-based Java glue is adapted for `io.github.bmherorecomp`.
- Native target builds as Android `libmain.so` while desktop keeps `BMHeroRecompiled`.
- Shell-only SDL lifecycle probe builds with:

```sh
source ~/.config/android-build-env.sh
gradle -p android --no-daemon :app:assembleDebug -PbmheroProbe=true
```

- Full native debug APK builds with:

```sh
source ~/.config/android-build-env.sh
gradle -p android --no-daemon :app:assembleDebug
```

- Development-only bundled-ROM APK builds with:

```sh
source ~/.config/android-build-env.sh
gradle -p android --no-daemon :app:assembleDebug -PbmheroBundleDevRoms=true
```

Verified build artifact:

- `android/app/build/outputs/apk/debug/app-debug.apk`
- Contains `lib/arm64-v8a/libmain.so` and `lib/arm64-v8a/libSDL2.so`.
- Safety check confirmed no ROM-like assets (`.z64`, `.n64`, `.v64`, dev-rom paths, baserom names) are packaged by default.
- Device test on AYN Thor (`kalama`, 1920x1080) verified the SDLActivity lifecycle, Vulkan renderer startup, and BMHeroRecomp main menu rendering.

## Required local/generated files

The full Android build currently depends on generated/ignored local outputs in the repo root:

- `RecompiledFuncs/`
- `RecompiledPatches/`
- `rsp/`
- host tools `N64Recomp` and `RSPRecomp`

These are intentionally not release assets. Do not commit ROM-derived/generated artifacts unless the upstream project explicitly changes its policy.

A local dev ROM may exist as `bmhero.z64` for generation/testing. Do not commit it and do not package it in release APKs. The dev-ROM APK option copies this local file into the APK as `assets/program/dev-roms/bmhero.us.z64` only when `-PbmheroBundleDevRoms=true` is set.

## Main Android changes

- `android/`: Gradle/SDLActivity project copied/adapted from BanjoRecomp.
- `src/android/sdl_lifecycle_probe.cpp`: minimal SDLActivity-driven native probe.
- Root `CMakeLists.txt`: Android target split and Android dependency wiring.
- RT64/plume/nativefiledialog patches: Android SDL Vulkan path, host DXC selection, nfd null backend.
- RecompFrontend patches: SDL include propagation for Android.
- RecompFrontend Android path patch: `APP_PROGRAM_PATH` points asset loading at the Activity-extracted program directory instead of the process working directory.
- RT64 Android path patch: RT64 data/config paths use `SDL_AndroidGetInternalStoragePath()` instead of desktop Linux `$HOME` fallback.
- `src/main/main.cpp` exports Android `SDL_main` and wires `nativeSetAppAudioActive` into Android audio-focus lifecycle handling: focus loss pauses the runtime VI loop, closes/resets SDL queued audio, and resume reopens the AudioTrack-backed SDL device.
- Dev-ROM build option: Gradle copies local `bmhero.z64` to `assets/program/dev-roms/bmhero.us.z64`, `BMHeroSDLActivity` sets `RECOMP_AUTO_ROM_PATH`, and the launcher consumes that path before falling back to the Android file-dialog/null-NFD path.
- SlotMap patches: use `posix_memalign` instead of `aligned_alloc` for Android API compatibility.

## Device verification

Probe APK:

```sh
source ~/.config/android-build-env.sh
gradle -p android --no-daemon :app:assembleDebug -PbmheroProbe=true
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
adb shell monkey -p io.github.bmherorecomp -c android.intent.category.LAUNCHER 1
```

Confirmed logcat evidence:

- `nativeSetupJNI()`
- `surfaceCreated()` / `surfaceChanged()`
- `Running main function SDL_main`
- `SDL_Init succeeded; video=Android audio=openslES`
- `SDL lifecycle probe completed`

Full APK:

```sh
source ~/.config/android-build-env.sh
gradle -p android --no-daemon :app:assembleDebug
APK=android/app/build/outputs/apk/debug/app-debug.apk
unzip -l "$APK" | grep -Ei '\.(z64|n64|v64)|dev-rom|baserom|Bomberman Hero|bmhero\.z64'
adb install -r "$APK"
adb shell monkey -p io.github.bmherorecomp -c android.intent.category.LAUNCHER 1
```

The APK hygiene grep must print nothing. Full APK logcat reached:

- `APP_PROGRAM_PATH=/data/user/0/io.github.bmherorecomp/files/program`
- `APP_FOLDER_PATH=/data/user/0/io.github.bmherorecomp/files/data`
- `Running main function SDL_main`
- Adreno Vulkan startup with application/engine name `plume`
- Stable BMHeroRecomp main menu render with `Load ROM`, `Controls`, `Settings`, `Mods`, `Exit`

Dev-ROM APK:

```sh
source ~/.config/android-build-env.sh
gradle -p android --no-daemon :app:assembleDebug -PbmheroBundleDevRoms=true
APK=android/app/build/outputs/apk/debug/app-debug.apk
unzip -l "$APK" | grep -F 'assets/program/dev-roms/bmhero.us.z64'
adb install -r "$APK"
adb shell monkey -p io.github.bmherorecomp -c android.intent.category.LAUNCHER 1
```

Confirmed dev-ROM behavior:

- Local `bmhero.z64` verified as big-endian `BOMBERMAN HERO` / game id `NBDE` before packaging.
- Dev APK contains `assets/program/dev-roms/bmhero.us.z64` and the bytes match local `bmhero.z64`.
- Device logcat sets `RECOMP_AUTO_ROM_PATH=/data/user/0/io.github.bmherorecomp/files/program/dev-roms/bmhero.us.z64`.
- Normal APK builds still exclude ROM-like assets by default.

## Remaining verification / likely next blockers

1. General ROM import/load flow on Android. The dev-ROM path is available for smoke testing, but the user-facing file-picker path still needs validation/replacement.
2. Android controller mappings/input navigation in the menu and in-game.
3. Sleep/wake and recents audio-focus lifecycle needs manual on-device validation with the latest APK; the native wiring now matches the BanjoRecomp fix pattern instead of the old no-op JNI stub.
4. Longer Vulkan swapchain lifecycle tests: suspend/resume, rotate/display mode changes, and background/foreground.

## Useful checks

```sh
APK=android/app/build/outputs/apk/debug/app-debug.apk
unzip -l "$APK" | grep -Ei '\.(z64|n64|v64)|dev-rom|baserom|Bomberman Hero|bmhero\.z64'
unzip -l "$APK" | grep -E 'lib/(arm64-v8a)/(libmain|libSDL2)\.so'
```

The first command should print nothing for normal builds.
