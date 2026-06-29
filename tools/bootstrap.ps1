<#
.SYNOPSIS
    Bootstrap the entire Kelivo Win7 build from scratch on a fresh Windows machine.

.DESCRIPTION
    Automates Stage 0鈥? of the Kelivo Win7 plan:
      Step 1: Install VS2022 Build Tools (if missing)
      Step 2: Install depot_tools
      Step 3: Fetch Flutter Engine 3.44.1 + Dart 3.12.1
      Step 4: Apply Win7 patches
      Step 5: Build Engine (flutter_windows.dll)
      Step 6: Configure Flutter to use local engine
      Step 7: Clone & patch Kelivo
      Step 8: Build Kelivo Win7 executable

    Prerequisites: Windows 10+ x64, ~80 GB free disk, admin rights.
    Time estimate: 4-6 hours (depends on network + CPU).

.PARAMETER SkipBuild
    If set, prepare engine source + apply patches but skip the long build.
    Useful for testing the pipeline.
.PARAMETER KelivoRef
    Kelivo commit to build (default: c8c9ff37).
#>

param(
    [switch]$SkipBuild = $false,
    [string]$KelivoRef = "c8c9ff37"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")

$EngineBranch = "3.44.1"
$DartBranch = "dart-3.12.1"
$EngineCommit = "c416acfeb8126e097f758c664aaa3da929e27da0"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Kelivo Win7 Bootstrap v1.0" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target: Flutter engine commit $EngineCommit ($EngineBranch)"
Write-Host "Kelivo: $KelivoRef"
Write-Host "Engine patches: $(Join-Path $repoRoot 'engine_patches')"
Write-Host ""
Write-Host "[IMPORTANT] This script will download ~8 GB of dependencies" -ForegroundColor Yellow
Write-Host "            and requires ~6 hours total. Run it on a machine" -ForegroundColor Yellow
Write-Host "            with VS2022 and 80+ GB free disk." -ForegroundColor Yellow
Write-Host ""

function Run-Step {
    param([string]$Name, [scriptblock]$Block)
    Write-Host "[$(Get-Date -Format HH:mm:ss)] >>> $Name ..." -ForegroundColor Yellow
    try {
        & $Block
        Write-Host "[$(Get-Date -Format HH:mm:ss)] <<< $Name OK" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL] $Name : $_" -ForegroundColor Red
        throw
    }
}

# ========== STEP 1: VS2022 Build Tools ==========
Run-Step -Name "Step 1: Check/Install VS2022 Build Tools" -Block {
    $vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
        -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath 2>$null

    if (-not $vsPath) {
        Write-Host "  VS2022 not found. Downloading VS2022 Build Tools..."
        $vsInstaller = "$env:TEMP\vs_buildtools.exe"
        if (-not (Test-Path $vsInstaller)) {
            Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vs_buildtools.exe" -OutFile $vsInstaller
        }
        Write-Host "  Installing VS2022 Build Tools (this may take 20-30 min)..."
        $proc = Start-Process -FilePath $vsInstaller -ArgumentList @(
            "--quiet", "--wait", "--norestart",
            "--add", "Microsoft.VisualStudio.Workload.VCTools",
            "--add", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
            "--add", "Microsoft.VisualStudio.Component.Windows10SDK.20348",
            "--includeRecommended"
        ) -Wait -PassThru
        if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
            throw "VS2022 install failed with exit code $($proc.ExitCode)"
        }
        Write-Host "  VS2022 installed (reboot may be needed for full activation)"

        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path","User")
    } else {
        Write-Host "  VS2022 found at: $vsPath"
    }
}

# ========== STEP 2: depot_tools ==========
Run-Step -Name "Step 2: Install depot_tools" -Block {
    $depotPath = "C:\depot_tools"
    if (-not (Test-Path $depotPath)) {
        Write-Host "  Cloning depot_tools..."
        git clone --depth 1 "https://chromium.googlesource.com/chromium/tools/depot_tools.git" $depotPath
        $env:Path = "$depotPath;$env:Path"
        [System.Environment]::SetEnvironmentVariable("Path", "$depotPath;$env:Path", "User")
        Write-Host "  depot_tools installed at $depotPath"
    } else {
        Write-Host "  depot_tools already present at $depotPath"
        $env:Path = "$depotPath;$env:Path"
    }

    $env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"
    [System.Environment]::SetEnvironmentVariable("DEPOT_TOOLS_WIN_TOOLCHAIN", "0", "User")

    gclient --version 2>$null | ForEach-Object { Write-Host "  gclient: $_" }
}

# ========== STEP 3: Fetch Engine ==========
Run-Step -Name "Step 3: Fetch Flutter Engine $EngineBranch + Dart $DartBranch" -Block {
    $engineDir = "C:\engine"
    if (-not (Test-Path "$engineDir\src\flutter\.git")) {
        New-Item -Path $engineDir -ItemType Directory -Force | Out-Null
        Set-Location $engineDir

        Write-Host "  Running fetch (may take 15-30 min)..."
        fetch --no-history --nohooks flutter 2>&1 | ForEach-Object { Write-Host "    $_" }

        Write-Host "  Checking out branches..."
        Set-Location "$engineDir\src\flutter"
        git fetch --depth 1 origin $EngineCommit 2>&1 | Out-Null
        git checkout $EngineCommit
        Write-Host "  Flutter engine: $(git rev-parse HEAD | ForEach-Object { $_.Substring(0,12) })"

        Set-Location $engineDir
        gclient sync --with_branch_heads --with_tags -D --jobs=4 2>&1 | ForEach-Object { Write-Host "    $_" }
        gclient runhooks 2>&1 | ForEach-Object { Write-Host "    $_" }
    } else {
        Write-Host "  Engine source already present at $engineDir"
    }
    Set-Location $repoRoot
}

# ========== STEP 4: Apply Patches ==========
Run-Step -Name "Step 4: Apply Win7 patches" -Block {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $python) {
        throw "Python not found in PATH. Install Python 3.x and try again."
    }
    & $python (Join-Path $repoRoot "tools\apply_patches.py") --engine-dir "C:\engine\src"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [WARN] apply_patches reported errors - check patches manually" -ForegroundColor Yellow
    }
}

# ========== STEP 5: Build Engine ==========
if (-not $SkipBuild) {
    Run-Step -Name "Step 5: Build Flutter Engine (release, Impeller OFF)" -Block {
        Set-Location "C:\engine\src\flutter"

        $vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
            -latest -products * -property installationPath
        if ($vsPath) {
            $vcvarsPath = Join-Path $vsPath "VC\Auxiliary\Build\vcvars64.bat"
            if (Test-Path $vcvarsPath) {
                cmd /c "`"$vcvarsPath`" && set" 2>&1 | ForEach-Object {
                    if ($_ -match '^([^=]+)=(.*)$') {
                        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
                    }
                }
            }
        }

        Write-Host "  Running GN..."
        python tools\gn.py `
            --runtime-mode release `
            --target-os windows `
            --windows-cpu x64 `
            --no-enable-impeller `
            --no-lto `
            --no-goma 2>&1 | ForEach-Object { Write-Host "    $_" }

        Write-Host "  Running ninja (this will take 2-4 hours)..."
        $buildStart = Get-Date
        ninja -C out\windows_release_x64 flutter_windows.dll flutter_exe 2>&1 | ForEach-Object { Write-Host "    $_" }
        $buildDuration = (Get-Date) - $buildStart

        Write-Host "  Engine build completed in $([math]::Round($buildDuration.TotalHours, 1)) hours!" -ForegroundColor Green
        Write-Host "  Output:" -ForegroundColor Green
        Get-ChildItem "C:\engine\src\out\windows_release_x64\flutter_windows.dll" | ForEach-Object {
            Write-Host "    $($_.FullName) ($([math]::Round($_.Length/1MB, 1)) MB)"
        }

        Set-Location $repoRoot
    }
} else {
    Write-Host "[Step 5] SKIPPED (--SkipBuild)" -ForegroundColor DarkGray
}

# ========== STEP 6: Configure Flutter ==========
if (-not $SkipBuild) {
    Run-Step -Name "Step 6: Configure Flutter to use local engine" -Block {
        flutter config --enable-windows-desktop 2>&1 | Out-Null
        flutter config --local-engine-src-path "C:\engine\src" 2>&1 | Out-Null
        flutter config --local-engine "windows_release_x64" 2>&1 | Out-Null

        Write-Host "  Flutter configured:"
        flutter config --list 2>&1 | ForEach-Object { Write-Host "    $_" }
    }
}

# ========== STEP 7: Build Kelivo ==========
if (-not $SkipBuild) {
    Run-Step -Name "Step 7: Clone & build Kelivo Win7" -Block {
        $kelivoDir = "C:\kelivo"
        if (-not (Test-Path "$kelivoDir\.git")) {
            git clone "https://github.com/Chevey339/kelivo.git" $kelivoDir
            Set-Location $kelivoDir
            git checkout $KelivoRef
        } else {
            Set-Location $kelivoDir
        }

        Write-Host "  Applying windows overrides..."
        Copy-Item (Join-Path $repoRoot "windows_overrides\runner.exe.manifest") "windows\runner\" -Force
        Copy-Item (Join-Path $repoRoot "windows_overrides\main.cpp") "windows\runner\" -Force
        Copy-Item (Join-Path $repoRoot "windows_overrides\utils.h") "windows\runner\" -Force
        Copy-Item (Join-Path $repoRoot "windows_overrides\utils.cc") "windows\runner\" -Force
        Copy-Item (Join-Path $repoRoot "dart_overrides\pubspec.win7.yaml") "pubspec.win7.yaml" -Force

        Write-Host "  Removing unused deps (bitsdojo_window, desktop_drop)..."
        $pubspec = Get-Content "pubspec.yaml"
        $pubspec = $pubspec -replace "^\s+bitsdojo_window:.*\n" , ""
        $pubspec = $pubspec -replace "^\s+desktop_drop:.*\n" , ""
        $pubspec | Set-Content "pubspec.yaml"

        Write-Host "  Running flutter pub get..."
        flutter pub get 2>&1 | ForEach-Object { Write-Host "    $_" }

        Write-Host "  Building Kelivo Windows release..."
        $buildStart = Get-Date
        flutter build windows --release 2>&1 | ForEach-Object { Write-Host "    $_" }
        $buildDuration = (Get-Date) - $buildStart

        Write-Host "  Kelivo built in $([math]::Round($buildDuration.TotalMinutes, 0)) min!" -ForegroundColor Green

        $exePath = "build\windows\runner\Release\kelivo.exe"
        if (Test-Path $exePath) {
            Write-Host "  Output EXE:" -ForegroundColor Green
            Get-ChildItem $exePath | ForEach-Object {
                Write-Host "    $($_.FullName) ($([math]::Round($_.Length/1MB, 1)) MB)"
            }
        }

        Set-Location $repoRoot
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Bootstrap Complete" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Output locations:" -ForegroundColor White
Write-Host "  Engine DLL:    C:\engine\src\out\windows_release_x64\flutter_windows.dll"
Write-Host "  Kelivo EXE:    C:\kelivo\build\windows\runner\Release\kelivo.exe"
Write-Host "  Patch sources: $(Join-Path $repoRoot 'engine_patches\')"
Write-Host ""
Write-Host "To package and release:" -ForegroundColor White
Write-Host "  powershell -File $(Join-Path $repoRoot 'release\scripts\package-win7.ps1') -BuildDir C:\kelivo\build\windows\runner\Release -Version $KelivoRef-win7 -OutDir C:\release"
Write-Host ""
Write-Host "To audit engine for Win10+ APIs:" -ForegroundColor White
Write-Host "  powershell -File $(Join-Path $repoRoot 'tools\audit_engine.ps1') -EngineSrc C:\engine\src"