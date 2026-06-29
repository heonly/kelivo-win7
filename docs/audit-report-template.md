# Engine Win10+ API Audit Report

> Generated: {{date}}  
> Engine source: {{engine_src_path}}  
> Flutter tag: {{flutter_ver}} · Dart tag: {{dart_ver}}  
> Audit method: four-entry scan (A/B/C/D)

---

## Entry A — Dart SDK runtime (`dart/runtime/`)

| API | File | Line | Status | Patch |
|---|---|---|---|---|
| GetHostNameW | runtime/bin/platform_win.cc | 142 | FOUND | 0001 (revert) |
| RtlAddGrowableFunctionTable | — | — | NOT_FOUND (compat already removed) | 0002 (restore) |
| PathCchCombineEx | runtime/bin/file_win.cc | 88 | FOUND | 0003 (revert) |
| SetFileInformationByHandle | runtime/bin/file_win.cc | 203 | FOUND | 0007 (dynamic_load) |
| GetPointerInfo | — | — | NOT_FOUND (dart doesn't use user32) | N/A |
| ... | ... | ... | ... | ... |

---

## Entry B — Flutter Engine embedder (`flutter/shell/platform/windows/`)

| API | File | Line | Status | Patch |
|---|---|---|---|---|
| EnableMouseInPointer | pointer_injector_win32.cc | 45 | FOUND | 0005 (dynamic_load) |
| GetPointerInfo | flutter_windows_view.cc | 312 | FOUND | 0005 (dynamic_load) |
| RegisterPointerInputTargetEx | flutter_windows_view.cc | 178 | FOUND | 0005 (dynamic_load) |
| SetThreadDescription | thread_helper.cc | 22 | FOUND | 0006 (dynamic_load) |
| GetThreadDescription | thread_helper.cc | 35 | FOUND | 0006 (dynamic_load) |
| DCompositionCreateSurfaceHandle | — | — | NOT_FOUND (compiled out) | 0004 (gn flag) |
| GetSystemTimePreciseAsFileTime | text_rendering.cc | 15 | FOUND (but has fallback) | NO_ACTION |
| ... | ... | ... | ... | ... |

---

## Entry C — DLL IAT scan (`flutter_windows.dll`)

| API | Module | IAT Found | Status |
|---|---|---|---|
| GetHostNameW | — | NOT FOUND | OK (dart impl, not in dll) |
| SetThreadDescription | KERNEL32.dll | FOUND | 0006 pending |
| GetPointerInfo | — | NOT FOUND (dynamic usage) | 0005 pending |
| ... | ... | ... | ... |

---

## Entry D — Git commit range (3.24.5 → 3.44.1)

```
$ gh api repos/flutter/flutter/commits?sha=3.44.1&path=shell/platform/windows --paginate | \
  jq '.[].commit.message' | grep -iE "window|win7|compat|dcomp|dwrite|d2d|memory"
```

Key commits introducing Win10+ APIs:
- {{commit_hash}} — {{description}}
- ...

---

## Summary

| Entry | Hits | Actionable | Patches |
|---|---|---|---|
| A | {{n}} | {{n}} | 0001, 0002, 0003, 0007 |
| B | {{n}} | {{n}} | 0004, 0005, 0006 |
| C | {{n}} | {{n}} | — (verification only) |
| D | {{n}} | {{n}} | — (verification only) |
| **Total** | **{{n}}** | **{{n}}** | **7 patches** |

## Unresolved Items

- {{any API not covered by existing patches}}
