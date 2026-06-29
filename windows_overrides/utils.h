#ifndef KELIVO_UTILS_H_
#define KELIVO_UTILS_H_

// Utility functions for Kelivo Windows 7 compatibility support.

#include <windows.h>

namespace kelivo {

// Detects whether the required platform update (KB2670838) is installed
// on Windows 7 SP1. This update provides D3D11.1 support needed by ANGLE.
// Returns true on non-Win7 systems (they have native support) or when
// the update is present.
bool IsPlatformUpdateInstalled();

}  // namespace kelivo

#endif  // KELIVO_UTILS_H_
