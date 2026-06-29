# kelivo-win7 — Kelivo for Windows 7

**Flutter LLM Chat Client, patched for Windows 7 SP1 x64 compatibility.**

This repository maintains a custom Flutter Engine fork (based on **3.44.1**)
with Win7 compatibility patches, plus the overlays and scripts needed to
produce a working `kelivo.exe` for Windows 7.

## Repository Structure

```
kelivo-win7/
├── .github/workflows/         — CI pipeline (Engine build + upload)
├── engine_patches/             — Win7 patch series for Flutter Engine + Dart SDK
│   ├── series                  — patch ordering (quilt-style)
│   ├── dart-sdk/               — patches for engine/src/dart/
│   └── flutter-engine/         — patches for engine/src/flutter/
├── windows_overrides/          — Patched windows/runner/ files for Kelivo
├── dart_overrides/             — Dart-level dependency overrides
├── tools/                      — Automation scripts
│   ├── apply_patches.py        — Apply/reverse patch series
│   ├── audit_engine.ps1        — Win10+ API scanner
│   └── bootstrap.ps1           — Full automatic setup on a fresh build machine
├── release/                    — Release packaging
│   ├── scripts/
│   │   ├── install_prereq.bat  — KB2670838 + VC++ auto-installer
│   │   └── package-win7.ps1    — Release zip packager
│   └── files/                  — Bundled binaries (KB2670838, VC++ redist)
├── docs/                       — Reference documentation
└── test-resources/             — Win7 VM test scripts & logs
```

## Quick Start

### Option A: Full automatic bootstrap (recommended)

On a **fresh Windows machine with VS2022 and 80 GB+ free disk**:

```powershell
# Copy the kelivo-win7/ folder to the build machine, then:
cd kelivo-win7
powershell -ExecutionPolicy Bypass -File tools\bootstrap.ps1
```

This script handles: VS2022 detection/install → depot_tools → engine fetch → patch apply → engine build → Flutter config → Kelivo clone → Kelivo build.  
Takes ~4-6 hours total on a modern machine.

### Option B: CI pipeline (GitHub Actions)

Push this repo to GitHub. The workflow at `.github/workflows/flutter-engine-windows-x64-release-build.yml` will:
1. Spin up a `windows-2022` runner automatically
2. Build the patched engine
3. Upload `flutter_windows.dll` as artifact

### Option C: Manual step-by-step

```bash
# 1. Fetch engine source
cd engine_build
fetch --no-history --nohooks flutter
cd src/flutter && git checkout 3.44.1
cd src/dart   && git checkout dart-3.12.1
cd .. && gclient sync --with_branch_heads --with_tags -D

# 2. Apply Win7 patches
python ../kelivo-win7/tools/apply_patches.py --engine-dir src/

# 3. Build
cd src/flutter
flutter tools/gn --runtime-mode release --target-os windows --windows-cpu x64 --no-enable-impeller
ninja -C out/windows_release_x64 flutter_windows.dll

# 4. Point Flutter to local engine
flutter config --local-engine-src-path "$PWD/src" --local-engine windows_release_x64

# 5. Build Kelivo
cd /path/to/kelivo
cp /path/to/kelivo-win7/windows_overrides/* windows/runner/
cp /path/to/kelivo-win7/dart_overrides/pubspec.win7.yaml ./
flutter pub get
flutter build windows --release
```

## Patch Series Reference

| # | Patch | Target | Win8+ API | Risk |
|---|-------|--------|-----------|------|
| 1 | dart-revert-GetHostNameW | Dart SDK | ↓ `GetHostNameW` | Chinese hostname |
| 2 | dart-restore-RtlAddGrowableFunctionTable | Dart SDK | ↓ `RtlAddGrowableFunctionTable` | SEH unwind |
| 3 | dart-revert-PathCchCombineEx | Dart SDK | ↓ `PathCchCombineEx` | Symlinks |
| 4 | embedder-disable-impeller | Engine | — | Render quality |
| 5 | embedder-pointer-mouse-fallback | Engine | ↓ `GetPointerInfo` etc. | Touch input |
| 6 | embedder-thread-naming-compat | Engine | ↓ `SetThreadDescription` | Debug naming |
| 7 | dart-file-ops-fallback | Dart SDK | ↓ `SetFileInformationByHandle` | Advanced file ops |

## Upstream Sync

- **Flutter**: rebase patches on each stable (approx. quarterly)
- **Kelivo**: submodule pin, apply overlays per release

## License

Same as Kelivo upstream — MIT.
