#!/usr/bin/env python3
"""
移除 C# 文件中与 GlobalUsings.cs 重复的 using 语句
"""
import os
import sys
import re
from pathlib import Path
from typing import Set, List, Tuple


def find_project_root(file_path: Path) -> Path | None:
    """查找包含 .csproj 文件的项目根目录"""
    current = file_path.parent
    while current != current.parent:  # 直到到达驱动器根目录
        csproj_files = list(current.glob("*.csproj"))
        if csproj_files:
            return current
        current = current.parent
    return None


def find_global_usings(project_root: Path) -> Path | None:
    """查找项目根目录下的 GlobalUsings.cs 文件"""
    global_usings = project_root / "GlobalUsings.cs"
    if global_usings.exists():
        return global_usings
    return None


def parse_global_usings(global_usings_path: Path) -> Set[str]:
    """解析 GlobalUsings.cs 文件，提取所有全局 using 的命名空间"""
    namespaces = set()
    try:
        with open(global_usings_path, 'r', encoding='utf-8-sig') as f:
            for line in f:
                line = line.strip()
                # 匹配 global using Namespace;
                match = re.match(r'global\s+using\s+([\w.]+)', line)
                if match:
                    namespaces.add(match.group(1))
    except Exception as e:
        print(f"Error reading GlobalUsings.cs: {e}", file=sys.stderr)
    return namespaces


def parse_file_usings(file_path: Path) -> Tuple[List[str], str, str]:
    """
    解析文件的 using 语句
    返回: (using列表, using前的前置内容, using后的内容)
    """
    try:
        with open(file_path, 'r', encoding='utf-8-sig') as f:
            content = f.read()

        lines = content.splitlines(keepends=True)
        usings = []
        usings_end_idx = 0
        first_using_idx = -1

        # 查找 using 语句区域
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith('using '):
                if first_using_idx == -1:
                    first_using_idx = i
                usings_end_idx = i
                # 提取命名空间（排除 static using 和 alias using）
                match = re.match(r'using\s+(?:static\s+)?([\w.]+)', stripped)
                if match and not '= ' in stripped:  # 排除 alias using
                    usings.append((match.group(1), i, line))
            elif stripped and not stripped.startswith('//'):
                # 遇到非空非注释行，且不是 using，则 using 区域结束
                if first_using_idx != -1:
                    break

        # 分割内容
        before_usings = ''.join(lines[:first_using_idx]) if first_using_idx > 0 else ''
        after_usings = ''.join(lines[usings_end_idx + 1:]) if usings else content

        return usings, before_usings, after_usings, lines if first_using_idx >= 0 else [], first_using_idx

    except Exception as e:
        print(f"Error reading file {file_path}: {e}", file=sys.stderr)
        return [], '', '', [], -1


def remove_duplicate_usings(file_path: Path, global_namespaces: Set[str]) -> bool:
    """移除文件中与全局 using 重复的 using 语句"""
    if not global_namespaces:
        print(f"No global usings found for {file_path}")
        return False

    # 读取文件内容
    try:
        with open(file_path, 'r', encoding='utf-8-sig') as f:
            content = f.read()
            has_bom = content.startswith('\ufeff')
            if has_bom:
                content = content[1:]

        lines = content.splitlines(keepends=True)
    except Exception as e:
        print(f"Error reading file {file_path}: {e}", file=sys.stderr)
        return False

    # 第一遍扫描：找出需要移除的 using
    usings_to_remove = set()
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('using '):
            match = re.match(r'using\s+(?:static\s+)?([\w.]+)', stripped)
            if match and match.group(1) in global_namespaces and '= ' not in stripped:
                usings_to_remove.add(match.group(1))

    if not usings_to_remove:
        print(f"No duplicate usings found in {file_path}")
        return False

    # 第二遍扫描：重新构建文件内容
    final_lines = []
    remaining_usings = []  # 保留的 using 语句
    in_using_section = True

    for line in lines:
        stripped = line.strip()
        is_using_line = stripped.startswith('using ')

        if is_using_line:
            match = re.match(r'using\s+(?:static\s+)?([\w.]+)', stripped)
            if match and match.group(1) in usings_to_remove and '= ' not in stripped:
                continue  # 跳过重复的 using
            remaining_usings.append(line)
        elif in_using_section:
            # 遇到第一个非 using 行（包括空行和注释）
            if not stripped or stripped.startswith('//'):
                # 如果后面没有剩余的 using，跳过这些空行/注释
                continue
            # 遇到实质内容，using 区域结束
            in_using_section = False
            # 添加保留的 using
            final_lines.extend(remaining_usings)
            # 如果有剩余的 using，添加一个空行分隔
            if remaining_usings:
                final_lines.append('\n')
            # 添加当前行
            final_lines.append(line)
        else:
            final_lines.append(line)

    # 处理文件只有 using 的情况（虽然不太可能）
    if in_using_section:
        final_lines.extend(remaining_usings)

    new_content = ''.join(final_lines)

    # 写回文件
    try:
        with open(file_path, 'w', encoding='utf-8-sig') as f:
            if has_bom:
                f.write('\ufeff')
            f.write(new_content)
        print(f"Removed {len(usings_to_remove)} duplicate using(s) from {file_path}")
        for ns in sorted(usings_to_remove):
            print(f"  - using {ns};")
        return True
    except Exception as e:
        print(f"Error writing file {file_path}: {e}", file=sys.stderr)
        return False


def process_file(file_path: str) -> bool:
    """处理单个文件"""
    path = Path(file_path).resolve()

    if not path.exists():
        print(f"File not found: {file_path}", file=sys.stderr)
        return False

    if not path.suffix.lower() == '.cs':
        print(f"Not a C# file: {file_path}", file=sys.stderr)
        return False

    # 查找项目根目录
    project_root = find_project_root(path)
    if not project_root:
        print(f"Could not find project root for: {file_path}", file=sys.stderr)
        return False

    # 查找 GlobalUsings.cs
    global_usings_path = find_global_usings(project_root)
    if not global_usings_path:
        print(f"No GlobalUsings.cs found in {project_root}", file=sys.stderr)
        return False

    # 解析全局 using
    global_namespaces = parse_global_usings(global_usings_path)
    if not global_namespaces:
        print(f"No global usings found in {global_usings_path}", file=sys.stderr)
        return False

    print(f"Found {len(global_namespaces)} global usings in {global_usings_path.relative_to(path.parent.parent.parent)}")

    # 移除重复 using
    return remove_duplicate_usings(path, global_namespaces)


def main():
    if len(sys.argv) < 2:
        print("Usage: remove_duplicate_usings.py <file1.cs> [file2.cs] ...")
        sys.exit(1)

    files = sys.argv[1:]
    success_count = 0

    for file_path in files:
        print(f"\nProcessing: {file_path}")
        print("-" * 60)
        if process_file(file_path):
            success_count += 1

    print("\n" + "=" * 60)
    print(f"Processed {len(files)} file(s), {success_count} modified")


if __name__ == "__main__":
    main()
