# Engine Win10+ API Audit Report

> Generated: {{date}}  
> Engine source: {{engine_src_path}}  
> Flutter tag: {{flutter_ver}} 路 Dart tag: {{dart_ver}}  
> Audit method: four-entry scan (A/B/C/D)

---

## Entry A 鈥?Dart SDK runtime (`dart/runtime/`)

| API | File | Line | Status | Patch |
|---|---|---|---|---|
| GetHostNameW | runtime/bin/platform_win.cc | 142 | FOUND | 0001 (revert) |
| RtlAddGrowableFunctionTable | 鈥?| 鈥?| NOT_FOUND (compat already removed) | 0002 (restore) |
| PathCchCombineEx | runtime/bin/file_win.cc | 88 | FOUND | 0003 (revert) |
| SetFileInformationByHandle | runtime/bin/file_win.cc | 203 | FOUND | 0007 (dynamic_load) |
| GetPointerInfo | 鈥?| 鈥?| NOT_FOUND (dart doesn't use user32) | N/A |
| ... | ... | ... | ... | ... |

---

## Entry B 鈥?Flutter Engine embedder (`flutter/shell/platform/windows/`)

| API | File | Line | Status | Patch |
|---|---|---|---|---|
| EnableMouseInPointer | pointer_injector_win32.cc | 45 | FOUND | 0005 (dynamic_load) |
| GetPointerInfo | flutter_windows_view.cc | 312 | FOUND | 0005 (dynamic_load) |
| RegisterPointerInputTargetEx | flutter_windows_view.cc | 178 | FOUND | 0005 (dynamic_load) |
| SetThreadDescription | thread_helper.cc | 22 | FOUND | 0006 (dynamic_load) |
| GetThreadDescription | thread_helper.cc | 35 | FOUND | 0006 (dynamic_load) |
| DCompositionCreateSurfaceHandle | 鈥?| 鈥?| NOT_FOUND (compiled out) | 0004 (gn flag) |
| GetSystemTimePreciseAsFileTime | text_rendering.cc | 15 | FOUND (but has fallback) | NO_ACTION |
| ... | ... | ... | ... | ... |

---

## Entry C 鈥?DLL IAT scan (`flutter_windows.dll`)

| API | Module | IAT Found | Status |
|---|---|---|---|
| GetHostNameW | 鈥?| NOT FOUND | OK (dart impl, not in dll) |
| SetThreadDescription | KERNEL32.dll | FOUND | 0006 pending |
| GetPointerInfo | 鈥?| NOT FOUND (dynamic usage) | 0005 pending |
| ... | ... | ... | ... |

---

## Entry D 鈥?Git commit range (3.24.5 鈫?3.44.1)

```
$ gh api repos/flutter/flutter/commits?sha=3.44.1&path=shell/platform/windows --paginate | \
  jq '.[].commit.message' | grep -iE "window|win7|compat|dcomp|dwrite|d2d|memory"
```

Key commits introducing Win10+ APIs:
- {{commit_hash}} 鈥?{{description}}
- ...

---

## Summary

| Entry | Hits | Actionable | Patches |
|---|---|---|---|
| A | {{n}} | {{n}} | 0001, 0002, 0003, 0007 |
| B | {{n}} | {{n}} | 0004, 0005, 0006 |
| C | {{n}} | {{n}} | 鈥?(verification only) |
| D | {{n}} | {{n}} | 鈥?(verification only) |
| **Total** | **{{n}}** | **{{n}}** | **7 patches** |

## Unresolved Items

- {{any API not covered by existing patches}}

## Patch Generation Status

> The 7 patch files in `engine_patches/` are template stubs as of
> 2026-06-29. They must be regenerated against the actual Flutter
> 3.44.1 / Dart 3.12.1 engine source using the instructions inside
> each patch file before they can be applied.
>
> Run `tools/generate_patches.sh` on a machine with VS2022 and
> depot_tools to produce real diffs.