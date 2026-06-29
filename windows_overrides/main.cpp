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
        L"Kelivo 鍦?Windows 7 涓婅繍琛岄渶瑕佸畨瑁?KB2670838 骞冲彴鏇存柊銆俓n\n"
        L"璇蜂粠寰蒋瀹樻柟缃戠珯鎼滅储骞跺畨瑁?KB2670838锛堥€傜敤浜?Windows 7 SP1 鐨刓n"
        L"骞冲彴鏇存柊锛夛紝鐒跺悗閲嶆柊鍚姩 Kelivo銆俓n\n"
        L"瀹夎浣嶇疆: 鎺у埗闈㈡澘 鈫?Windows Update 鈫?妫€鏌ユ洿鏂?鈫?鍙€夋洿鏂癨n"
        L"鎴栨悳绱? https://www.catalog.update.microsoft.com 鎼滅储 KB2670838\n\n"
        L"浠?Windows 7 SP1 x64 闇€瑕佹鏇存柊銆俉indows 10/11 鐢ㄦ埛涓嶅彈褰卞搷銆?,
        L"Kelivo - 缂哄皯绯荤粺缁勪欢",
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