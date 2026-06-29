@echo off
chcp 65001 >nul
title Kelivo Win7 前置依赖安装

echo ========================================
echo   Kelivo Win7 前置依赖检测与安装
echo ========================================
echo.

setlocal enabledelayedexpansion

REM --- 检测操作系统版本 ---
ver | findstr "6.1" >nul
if errorlevel 1 (
    echo [信息] 当前系统不是 Windows 7，无需安装 Win7 更新。
    goto check_vc
)
echo [信息] 检测到 Windows 7 SP1

REM --- 检查 KB2670838 ---
echo.
echo [步骤 1/3] 检查 KB2670838 平台更新...
dism /online /get-packages 2>nul | findstr "KB2670838" >nul
if errorlevel 1 (
    echo [需要] KB2670838 平台更新缺失！
    echo.
    echo 该更新为 Flutter/ANGLE 渲染提供 D3D11.1 支持。
    echo 请从以下地址下载后手动安装：
    echo   https://www.catalog.update.microsoft.com/Search.aspx?q=KB2670838
    echo.
    echo 或在本脚本同目录的 prerequisite 文件夹中查找离线包。
    if exist "..\files\prerequisite\KB2670838-x64.msu" (
        echo [安装] 发现本地离线包，正在安装...
        wusa.exe "..\files\prerequisite\KB2670838-x64.msu" /quiet /norestart
        set PLATFORM_UPDATE_INSTALLED=1
    ) else (
        echo [跳过] 未找到本地离线包，请手动安装后再运行 Kelivo。
        set PLATFORM_UPDATE_INSTALLED=0
    )
) else (
    echo [OK] KB2670838 已安装
)

REM --- 检查 VC++ Redistributable ---
:check_vc
echo.
echo [步骤 2/3] 检查 Visual C++ Redistributable...
reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" /v Version >nul 2>&1
if errorlevel 1 (
    echo [需要] VC++ 2015-2022 Redistributable (x64) 缺失！
    if exist "..\files\prerequisite\vcredist_x64.exe" (
        echo [安装] 正在安装 VC++ Redistributable...
        "..\files\prerequisite\vcredist_x64.exe" /install /quiet /norestart
    ) else (
        echo [跳过] 未找到 vcredist_x64.exe。
        echo   请从 https://aka.ms/vs/17/release/vc_redist.x64.exe 下载安装。
    )
) else (
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" /v Version') do set VC_VER=%%a
    echo [OK] VC++ Redistributable 已安装 (版本 %VC_VER%)
)

REM --- 检测 .NET Framework 4.x ---
echo.
echo [步骤 3/3] 检查 .NET Framework 4.x...
reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release >nul 2>&1
if errorlevel 1 (
    echo [可选] .NET Framework 4.x 未安装（某些功能可能需要）
) else (
    for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release') do set DOTNET_VER=%%a
    echo [OK] .NET Framework 4.x 已安装 (Release=%DOTNET_VER%)
)

REM --- 最终报告 ---
echo.
echo ========================================
echo   检测完成
echo ========================================
echo.
echo 如果以上步骤全部通过，你现在可以运行 kelivo.exe 了！
echo.
echo 按任意键启动 Kelivo...
pause >nul

if exist "kelivo.exe" (
    start "" kelivo.exe
) else if exist "..\..\kelivo.exe" (
    start "" "..\..\kelivo.exe"
) else (
    echo [警告] 未找到 kelivo.exe，请确保本脚本位于发布目录中。
    echo 发布目录结构应为：
    echo   kelivo-win7-x64/
    echo   ├── install_prereq.bat
    echo   ├── kelivo.exe
    echo   ├── flutter_windows.dll
    echo   └── ...
    pause
)

endlocal
