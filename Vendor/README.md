# Vendored dependencies

Copies of upstream packages with patches needed to build xtool on native Windows. `Package.swift` references them by
path, which also overrides the copies that other dependencies pull in transitively (SwiftPM prints "Conflicting
identity" warnings for `xtool-core` and `combine-schedulers`; these are expected).

All Windows changes are behind `#if os(Windows)` / `.when(platforms: [.windows])`, so other platforms build as before.

| Package | Upstream | Base commit | Windows changes |
| --- | --- | --- | --- |
| `zsign` | https://github.com/xtool-org/zsign | `f6158be` | C++17 (MSVC STL needs C++14+); Windows shims in `src/win32/` (from upstream's VS project, minus its hard-coded OpenSSL libs); `asprintf`; `_HAS_STD_BYTE=0` because of `using namespace std`. Dropped `build/` (prebuilt VS OpenSSL) and `test/`. |
| `unxip` | https://github.com/saagarjha/unxip | `6c39905` | `WindowsCompat.swift`: Win32 versions of `openat`/`mkdirat`/`linkat`/`symlinkat`/`pwrite` using `\\?\` paths; symlinks are created after everything else so directory links get the right flag; zlib/lzma via pkg-config; `DispatchIO` gets a `HANDLE`. `Sources/libunxip/libunxip.swift` is a copy of `unxip.swift` instead of a symlink. |
| `PathKit` | https://github.com/kylef/PathKit | `3bfd273` | Pure-Swift `glob`/`fnmatch` replacement. Test fixture symlinks omitted. |
| `XcodeProj` | https://github.com/tuist/XcodeProj | `b505c06b` | `glob` delegates to PathKit on Windows. |
| `xtool-core` | https://github.com/xtool-org/xtool-core | `154d721` | Darwin-only Foundation APIs gated on `canImport(Darwin)` instead of `!os(Linux)`. |
| `combine-schedulers` | https://github.com/pointfreeco/combine-schedulers | `114354e` | `NSLock`-based lock instead of pthreads. |
