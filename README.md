# kelivo-win7 鈥?Kelivo for Windows 7

**Flutter LLM Chat Client, patched for Windows 7 SP1 x64 compatibility.**

This repository maintains a custom Flutter Engine fork (based on **3.44.1**)
with Win7 compatibility patches, plus the overlays and scripts needed to
produce a working `kelivo.exe` for Windows 7.

## Repository Structure

```
kelivo-win7/
鈹溾攢鈹€ .github/workflows/         鈥?CI pipeline (Engine build + upload)
鈹溾攢鈹€ engine_patches/             鈥?Win7 patch series for Flutter Engine + Dart SDK
鈹?  鈹溾攢鈹€ series                  鈥?patch ordering (quilt-style)
鈹?  鈹溾攢鈹€ dart-sdk/               鈥?patches for engine/src/dart/
鈹?  鈹斺攢鈹€ flutter-engine/         鈥?patches for engine/src/flutter/
鈹溾攢鈹€ windows_overrides/          鈥?Patched windows/runner/ files for Kelivo
鈹溾攢鈹€ dart_overrides/             鈥?Dart-level dependency overrides
鈹溾攢鈹€ tools/                      鈥?Automation scripts
鈹?  鈹溾攢鈹€ apply_patches.py        鈥?Apply/reverse patch series
鈹?  鈹溾攢鈹€ audit_engine.ps1        鈥?Win10+ API scanner
鈹?  鈹斺攢鈹€ bootstrap.ps1           鈥?Full automatic setup on a fresh build machine
鈹溾攢鈹€ release/                    鈥?Release packaging
鈹?  鈹溾攢鈹€ scripts/
鈹?  鈹?  鈹溾攢鈹€ install_prereq.bat  鈥?KB2670838 + VC++ auto-installer
鈹?  鈹?  鈹斺攢鈹€ package-win7.ps1    鈥?Release zip packager
鈹?  鈹斺攢鈹€ files/                  鈥?Bundled binaries (KB2670838, VC++ redist)
鈹溾攢鈹€ docs/                       鈥?Reference documentation
鈹斺攢鈹€ test-resources/             鈥?Win7 VM test scripts & logs
```

## Quick Start

### Option A: Full automatic bootstrap (recommended)

On a **fresh Windows machine with VS2022 and 80 GB+ free disk**:

```powershell
# Copy the kelivo-win7/ folder to the build machine, then:
cd kelivo-win7
powershell -ExecutionPolicy Bypass -File tools\bootstrap.ps1
```

This script handles: VS2022 detection/install 鈫?depot_tools 鈫?engine fetch 鈫?patch apply 鈫?engine build 鈫?Flutter config 鈫?Kelivo clone 鈫?Kelivo build.  
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
# Dart SDK is pinned by gclient via engine DEPS at the correct
# commit for this engine version. No manual checkout needed.
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
| 1 | dart-revert-GetHostNameW | Dart SDK | 鈫?`GetHostNameW` | Chinese hostname |
| 2 | dart-restore-RtlAddGrowableFunctionTable | Dart SDK | 鈫?`RtlAddGrowableFunctionTable` | SEH unwind |
| 3 | dart-revert-PathCchCombineEx | Dart SDK | 鈫?`PathCchCombineEx` | Symlinks |
| 4 | embedder-disable-impeller | Engine | 鈥?| Render quality |
| 5 | embedder-pointer-mouse-fallback | Engine | 鈫?`GetPointerInfo` etc. | Touch input |
| 6 | embedder-thread-naming-compat | Engine | 鈫?`SetThreadDescription` | Debug naming |
| 7 | dart-file-ops-fallback | Dart SDK | 鈫?`SetFileInformationByHandle` | Advanced file ops |

## Upstream Sync

- **Flutter**: rebase patches on each stable (approx. quarterly)
- **Kelivo**: submodule pin, apply overlays per release

## License

Same as Kelivo upstream 鈥?MIT.