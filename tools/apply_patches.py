#!/usr/bin/env python3
"""
apply_patches.py 鈥?Apply/verify/reverse Win7 compatibility patches
    to a local Flutter Engine source tree (flutter + dart SDK).

Usage:
    # Apply all patches (default)
    python apply_patches.py --engine-dir /path/to/engine/src

    # Dry-run (show what would be applied)
    python apply_patches.py --engine-dir /path/to/engine/src --dry-run

    # Reverse all patches
    python apply_patches.py --engine-dir /path/to/engine/src --reverse

    # Apply only dart SDK patches
    python apply_patches.py --engine-dir /path/to/engine/src --filter dart-sdk

    # Show current patch status
    python apply_patches.py --engine-dir /path/to/engine/src --status
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path


PATCH_DIR = Path(__file__).resolve().parent.parent / "engine_patches"
SERIES_FILE = PATCH_DIR / "series"
REPO_MAP = {
    "dart-sdk":       "dart",
    "flutter-engine": "flutter",
}


def parse_series():
    if not SERIES_FILE.exists():
        print(f"[ERROR] Series file not found: {SERIES_FILE}", file=sys.stderr)
        sys.exit(1)

    patches = []
    with open(SERIES_FILE) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if ":" not in line:
                print(f"[WARN] Skipping malformed series entry: {line}")
                continue
            repo_subdir, patch_filename = line.split(":", 1)
            if repo_subdir not in REPO_MAP:
                print(f"[WARN] Unknown repo tag '{repo_subdir}', skipping: {line}")
                continue
            patch_path = (PATCH_DIR / repo_subdir / patch_filename).resolve()
            if not patch_path.exists():
                print(f"[WARN] Patch file not found: {patch_path}")
                continue
            patches.append((repo_subdir, patch_path))
    return patches


def git_exec(args, cwd=None):
    cmd = ["git"] + args
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd, check=False)
        if result.returncode != 0:
            print(f"[GIT ERROR] {' '.join(cmd)}: {result.stderr.strip()}", file=sys.stderr)
            return None
        return result.stdout.strip()
    except FileNotFoundError:
        print("[ERROR] git not found in PATH", file=sys.stderr)
        sys.exit(1)


def patch_status(engine_src: Path, repo_subdir: str):
    repo_dir = engine_src / REPO_MAP[repo_subdir]
    if not (repo_dir / ".git").exists():
        print(f"[SKIP] Not a git repo: {repo_dir}")
        return
    status = git_exec(["diff", "--stat"], cwd=repo_dir)
    if status:
        lines = [l for l in status.split("\n") if l.strip()]
        print(f"  Patched ({len(lines)} modified files):")
        for line in lines:
            print(f"    {line}")
    else:
        print(f"  Clean (no uncommitted changes)")


def apply_single(patch_path: Path, engine_src: Path, repo_subdir: str,
                 dry_run: bool = False, reverse: bool = False):
    repo_dir = engine_src / REPO_MAP[repo_subdir]
    if not repo_dir.exists():
        print(f"[ERROR] Engine repo not found: {repo_dir}")
        return False

    with open(patch_path) as f:
        header = f.read(100)

    if reverse:
        cmd = ["apply", "-R"]
        if dry_run:
            cmd.append("--check")
        result = git_exec(cmd + ["--ignore-space-change", "--ignore-whitespace",
                                 str(patch_path)], cwd=repo_dir)
    else:
        cmd = ["apply"]
        if dry_run:
            cmd.append("--check")
        result = git_exec(cmd + ["--ignore-space-change", "--ignore-whitespace",
                                 str(patch_path)], cwd=repo_dir)

    if result is None:
        return False
    if dry_run:
        label = "Would apply" if not reverse else "Would reverse"
        print(f"  {label}: {patch_path.name}")
    else:
        label = "Applied" if not reverse else "Reverted"
        print(f"  {label}: {patch_path.name}")
    return True


def main():
    parser = argparse.ArgumentParser(description="Manage Win7 engine patches")
    parser.add_argument("--engine-dir", required=True,
                        help="Path to engine src/ directory (after gclient sync)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Check what patches would be applied without changing files")
    parser.add_argument("--reverse", action="store_true",
                        help="Reverse (un-apply) all patches")
    parser.add_argument("--filter", default=None,
                        help="Only process patches matching this repo tag (dart-sdk|flutter-engine)")
    parser.add_argument("--status", action="store_true",
                        help="Show current patch status of engine repos")
    args = parser.parse_args()

    engine_src = Path(args.engine_dir).resolve()
    if not engine_src.exists():
        print(f"[ERROR] Engine directory not found: {engine_src}", file=sys.stderr)
        sys.exit(1)

    patches = parse_series()

    if args.status:
        print(f"Engine patch status for: {engine_src}")
        for repo_subdir in ["dart-sdk", "flutter-engine"]:
            if not args.filter or args.filter == repo_subdir:
                print(f"\n[{repo_subdir} @ {REPO_MAP[repo_subdir]}/]")
                patch_status(engine_src, repo_subdir)
        return

    if not patches:
        print("No patches to process.")
        return

    if args.filter:
        patches = [(r, p) for r, p in patches if r == args.filter]
        if not patches:
            print(f"No patches matching filter: {args.filter}")
            return

    action = "Dry-run" if args.dry_run else "Reversing" if args.reverse else "Applying"
    print(f"{action} {len(patches)} patches in series order...")

    ok = True
    for repo_subdir, patch_path in patches:
        repo_dir = engine_src / REPO_MAP[repo_subdir]
        if not repo_dir.exists():
            print(f"  [SKIP] Source tree not found: {repo_dir}")
            continue
        if not apply_single(patch_path, engine_src, repo_subdir,
                            dry_run=args.dry_run, reverse=args.reverse):
            print(f"  [FAIL] {patch_path.name} 鈥?check conflict.")
            ok = False

    if args.dry_run:
        print("\nDry-run complete. No files changed.")
    else:
        print(f"\n{'Reverse' if args.reverse else 'Apply'} {'failed' if not ok else 'complete'}.")

    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()