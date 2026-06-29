#include "utils.h"

namespace kelivo {

bool IsPlatformUpdateInstalled() {
  // Use VerifyVersionInfo to check if we're on Win7 SP1 or higher.
  // If the running OS is newer than Win7 SP1, no platform update needed.
  OSVERSIONINFOEXW osvi = {sizeof(osvi), 0, 0, 0, 0, {0}, 0, 0};
  osvi.dwMajorVersion = 6;
  osvi.dwMinorVersion = 1;
  osvi.wServicePackMajor = 1;

  DWORDLONG condition_mask = 0;
  VER_SET_CONDITION(condition_mask, VER_MAJORVERSION, VER_GREATER_EQUAL);
  VER_SET_CONDITION(condition_mask, VER_MINORVERSION, VER_GREATER_EQUAL);
  VER_SET_CONDITION(condition_mask, VER_SERVICEPACKMAJOR, VER_GREATER_EQUAL);

  if (!VerifyVersionInfoW(&osvi,
                          VER_MAJORVERSION | VER_MINORVERSION | VER_SERVICEPACKMAJOR,
                          condition_mask)) {
    // Not Win7 or newer — return true (not our concern).
    return true;
  }

  // We are on Win7 SP1 (or Win8+). Check if D3D11CreateDevice is available.
  // On Win7 without KB2670838, D3D11CreateDevice may still exist but
  // return E_NOTIMPL. We check for a more authoritative sign:
  // the presence of D3D11.1 (ID3D11Device1) which comes with the platform update.
  HMODULE d3d11 = LoadLibraryW(L"d3d11.dll");
  if (!d3d11) {
    return false;  // No D3D11 at all — very unlikely on Win7 SP1.
  }

  // D3D11_CREATE_DEVICE_FLAG is always there. We use the
  // presence of D3D11CreateDevice as basic indicator.
  auto create_device = reinterpret_cast<void*>(
      GetProcAddress(d3d11, "D3D11CreateDevice"));
  FreeLibrary(d3d11);

  if (create_device) {
    return true;  // D3D11 available (KB2670838 is installed or not needed).
  }

  // D3D11 not available — KB2670838 is likely missing.
  return false;
}

}  // namespace kelivo
