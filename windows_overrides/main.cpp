#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"
#include "win32_window.h"

// The main function signature for Windows desktop applications.
int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // ============================================================
  // Win7 compatibility check: KB2670838 platform update
  // ============================================================
  // On Windows 7, the ANGLE (OpenGL ES over Direct3D) backend
  // requires D3D11.1, which is provided by KB2670838.
  // Without it, the Flutter engine will fail to create a rendering
  // context, resulting in a blank window or crash.
  if (!kelivo::IsPlatformUpdateInstalled()) {
    MessageBoxW(
        nullptr,
        L"Kelivo 在 Windows 7 上运行需要安装 KB2670838 平台更新。\n\n"
        L"请从微软官方网站搜索并安装 KB2670838（适用于 Windows 7 SP1 的\n"
        L"平台更新），然后重新启动 Kelivo。\n\n"
        L"安装位置: 控制面板 → Windows Update → 检查更新 → 可选更新\n"
        L"或搜索: https://www.catalog.update.microsoft.com 搜索 KB2670838\n\n"
        L"仅 Windows 7 SP1 x64 需要此更新。Windows 10/11 用户不受影响。",
        L"Kelivo - 缺少系统组件",
        MB_ICONERROR | MB_OK);
    return EXIT_FAILURE;
  }

  // Attach to console if available (for debugging).
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM for clipboard and other Windows APIs.
  // NB: CoInitializeEx is called here for the main thread.
  // Individual subsystems (e.g., flutter_window) will CoInitialize
  // as needed, which is safe on the same thread.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Create the Flutter project and controller.
  flutter::DartProject project(L"data");
  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Disable Impeller on Windows 7 to ensure Skia+ANGLE rendering.
  // (Engine compiled with --no-enable-impeller handles this at build
  //  time; adding the runtime flag as a belt-and-suspenders measure.)
  command_line_arguments.push_back("--disable-impeller");

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);

  if (!window.CreateAndShow(L"kelivo", origin, size)) {
    return EXIT_FAILURE;
  }

  window.SetQuitOnClose(true);

  // Run the Flutter message loop.
  // On Win7, a separate UI thread policy is applied by the engine
  // config (UIThreadPolicy::RunOnSeparateThread) to avoid message
  // pump deadlocks with COM and clipboard.
  window.Run();

  // Cleanup.
  ::CoUninitialize();
  ::FreeConsole();

  return EXIT_SUCCESS;
}
