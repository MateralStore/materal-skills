#!/usr/bin/env python3
"""
Scan non-MGC C# files and enforce the "single file first" rule.

Usage:
  python single_file_first.py <module_path>
  python single_file_first.py <module_path> --apply

Behavior:
- Always skip files under MGC/bin/obj.
- Report candidates like Class.Tag.cs.
- --apply only performs safe rename:
  if exactly one fragment exists and Class.cs does not exist,
  rename Class.Tag.cs -> Class.cs.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path

IGNORED_DIRS = {"MGC", "bin", "obj"}
IGNORED_TAGS = {"g", "designer", "generated", "AssemblyInfo"}

METHOD_PATTERN = re.compile(r"^\s*(public|protected|internal|private)\b.*\(.*\)")
TYPE_PATTERN = re.compile(r"\b(class|interface|record|enum)\b")


@dataclass
class FragmentInfo:
    path: Path
    tag: str
    non_empty_lines: int
    method_count: int


@dataclass
class GroupInfo:
    directory: Path
    class_name: str
    base_file: Path
    fragments: list[FragmentInfo]


def should_skip(path: Path) -> bool:
    return any(part in IGNORED_DIRS for part in path.parts)


def count_non_empty_lines(content: str) -> int:
    return sum(1 for line in content.splitlines() if line.strip())


def count_methods(content: str) -> int:
    count = 0
    for line in content.splitlines():
        stripped = line.strip()
        if not stripped or TYPE_PATTERN.search(stripped):
            continue
        if METHOD_PATTERN.search(stripped):
            lowered = stripped.lower()
            if lowered.startswith(("if ", "for ", "while ", "switch ", "catch ", "using ", "lock ")):
                continue
            count += 1
    return count


def discover_groups(root: Path) -> list[GroupInfo]:
    grouped: dict[tuple[Path, str], GroupInfo] = {}

    for file in root.rglob("*.cs"):
        if should_skip(file):
            continue

        stem = file.stem  # e.g. UserController.Crud
        if "." not in stem:
            continue

        class_name, _, tag = stem.partition(".")
        if not class_name or not tag:
            continue

        first_tag = tag.split(".", 1)[0]
        if first_tag in IGNORED_TAGS:
            continue

        content = file.read_text(encoding="utf-8", errors="ignore")
        fragment = FragmentInfo(
            path=file,
            tag=tag,
            non_empty_lines=count_non_empty_lines(content),
            method_count=count_methods(content),
        )

        key = (file.parent, class_name)
        if key not in grouped:
            grouped[key] = GroupInfo(
                directory=file.parent,
                class_name=class_name,
                base_file=file.parent / f"{class_name}.cs",
                fragments=[],
            )
        grouped[key].fragments.append(fragment)

    return sorted(grouped.values(), key=lambda g: str(g.base_file))


def summarize_group(group: GroupInfo) -> tuple[str, str]:
    fragment_count = len(group.fragments)
    total_lines = sum(x.non_empty_lines for x in group.fragments)
    total_methods = sum(x.method_count for x in group.fragments)
    base_exists = group.base_file.exists()

    if not base_exists and fragment_count == 1:
        return "rename_to_main", "only one fragment and base file missing"

    if total_lines <= 300 and total_methods <= 8 and fragment_count <= 3:
        return "merge_recommended", "within simple-class thresholds"

    return "keep_split", "exceeds split thresholds"


def apply_safe_renames(groups: list[GroupInfo]) -> list[str]:
    changes: list[str] = []
    for group in groups:
        action, _ = summarize_group(group)
        if action != "rename_to_main":
            continue

        src = group.fragments[0].path
        dst = group.base_file
        src.rename(dst)
        changes.append(f"renamed: {src} -> {dst}")

    return changes


def print_report(groups: list[GroupInfo]) -> None:
    if not groups:
        print("No fragmented files found.")
        return

    print("Detected fragmented class files:")
    for group in groups:
        action, reason = summarize_group(group)
        print(f"- class: {group.class_name}")
        print(f"  dir: {group.directory}")
        print(f"  base: {group.base_file} (exists={group.base_file.exists()})")
        print(f"  action: {action} ({reason})")
        for frag in sorted(group.fragments, key=lambda x: x.path.name):
            print(
                f"  fragment: {frag.path.name} | tag={frag.tag} | lines={frag.non_empty_lines} | methods={frag.method_count}"
            )


def main() -> int:
    parser = argparse.ArgumentParser(description="MMB single-file-first checker")
    parser.add_argument("root", help="module path, e.g. ZhiTu.Main")
    parser.add_argument("--apply", action="store_true", help="apply only safe rename_to_main actions")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.exists():
        print(f"Path not found: {root}")
        return 1

    groups = discover_groups(root)
    print_report(groups)

    if args.apply:
        changes = apply_safe_renames(groups)
        if changes:
            print("\nApplied changes:")
            for item in changes:
                print(f"- {item}")
        else:
            print("\nNo safe rename action applied.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
