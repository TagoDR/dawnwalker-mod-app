# DawnwalkerNativeFix — native UE4SS C++ mod

Fixes the `GiveBestGear` wrong-item bug by calling `GetItemHandle` /
`TryAddItem` through raw `ProcessEvent` + a byte-level `memcpy` of the
`FItemHandle` struct, bypassing UE4SS Lua's property-based table marshalling
(which silently drops the handle's data because `FItemHandle` has zero
reflected UProperty members — see /memories/repo/dawnwalker-mod-app.md for
the full root-cause writeup).

## Why this needs its own repo checkout (not vendored here)

Building a UE4SS C++ mod requires building UE4SS itself from source as a
CMake subdirectory dependency, which needs `RE-UE4SS`'s full git history +
submodules (~includes a private Unreal Engine pseudo-code submodule gated by
an Epic Games account linked to GitHub). That's too large/account-gated to
vendor into this repo, so it's cloned as a sibling folder instead (gitignored).

## One-time setup (per machine)

1. Link a GitHub account to an Epic Games account and accept the
   `@EpicGames` GitHub org invite (see unrealengine.com/en-US/ue-on-github).
2. Confirm the exact live UE4SS build to match: check
   `Binaries\Win64\UE4SS.log` first lines for the version + git SHA
   (currently `v3.0.1 Beta #0`, SHA `97b7e501`).
3. From this `native-mods/` folder:
   ```powershell
   git clone https://github.com/UE4SS-RE/RE-UE4SS.git
   cd RE-UE4SS
   git checkout 97b7e501
   git submodule update --init --recursive
   ```

## Build

From `native-mods/`:
```powershell
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Game__Shipping__Win64
cmake --build build
```
(Use the MSVC Build Tools' bundled CMake/Ninja if not on PATH — see repo
memory for the exact local path.)

## Deploy

Copy the built `DawnwalkerNativeFix.dll` into the live game's
`Binaries\Win64\Mods\DawnwalkerNativeFix\dlls\main.dll` and add
`DawnwalkerNativeFix : 1` to `Mods\mods.txt`.
