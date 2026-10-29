# Building xtool on native Windows

This fork builds the `xtool` CLI with the native Windows Swift toolchain (no WSL).

## Prerequisites

- Visual Studio 2022 (or Build Tools) with the **MSVC v143 x64/x86 build tools** and a **Windows 11 SDK**
- Swift 6.2 or newer: `winget install --id Swift.Toolchain -e --skip-dependencies`
- Git and [vcpkg](https://github.com/microsoft/vcpkg)
- **Developer Mode** enabled (Settings → System → For developers), so `xtool sdk` can create symlinks without
  elevation
- To talk to devices: Apple's device service, from iTunes or the Apple Devices app

## Build

```powershell
git clone https://github.com/jpdagostin0/xtool-win
cd xtool-win
vcpkg install --triplet x64-windows   # OpenSSL, libimobiledevice & co. from vcpkg.json (~10 min)
. .\scripts\windows-env.ps1
swift build --product xtool
.\.build\out\Products\Debug-windows-x86_64\xtool.exe --help
```

Keep `scripts\windows-env.ps1` loaded when running `xtool.exe`: it puts the vcpkg DLLs on `PATH`.

## Status

- Builds and runs; `xtool devices` starts up and waits for devices.
- `.xip` extraction (`xtool sdk`) is ported and checked against a synthetic archive with hardlinks, symlinks and
  paths over `MAX_PATH`, but has not been run on a real `Xcode.xip`. NTFS is case-insensitive, so paths in Xcode
  that differ only by case would collide.
- `XTL_DISABLE_TLS_VALIDATION` is ignored on Windows (no `SecTrust` in swift-corelibs-foundation).
- Device features, `xtool dev` and the test suite are untested on Windows.

See [`Vendor/README.md`](../Vendor/README.md) for the patched dependencies.
