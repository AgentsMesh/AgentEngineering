#!/usr/bin/env python3
"""交叉引用有效性。

300 页的书前后互指几百次，手工维护必错。这条检查保证每个 @sec-/@fig-/@tbl-
都指向一个真实存在的锚点，并报出无人引用的孤儿锚点（通常意味着那段内容
本来打算被引用，后来被改写掉了）。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REF = re.compile(r"@(sec|fig|tbl|eq)-([A-Za-z0-9_-]+)")
LABEL = re.compile(r"\{#(sec|fig|tbl|eq)-([A-Za-z0-9_-]+)[^}]*\}")


def main() -> int:
    labels: dict[str, Path] = {}
    refs: list[tuple[str, Path, int]] = []

    for path in sorted(ROOT.glob("**/*.qmd")):
        if "_output" in path.parts:
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for kind, name in LABEL.findall(line):
                labels[f"{kind}-{name}"] = path
            for kind, name in REF.findall(line):
                refs.append((f"{kind}-{name}", path, lineno))

    dangling = [(r, p, n) for r, p, n in refs if r not in labels]
    referenced = {r for r, _, _ in refs}
    orphans = {k: v for k, v in labels.items() if k not in referenced and k.startswith("sec-")}

    if dangling:
        print(f"guard: {len(dangling)} 处交叉引用指向不存在的锚点", file=sys.stderr)
        for ref, path, lineno in dangling:
            print(f"  {path.relative_to(ROOT)}:{lineno}  @{ref}", file=sys.stderr)

    if orphans:
        print(f"\n提示: {len(orphans)} 个 section 锚点无人引用（不拦，供检视）")
        for label, path in sorted(orphans.items()):
            print(f"  {path.relative_to(ROOT)}  #{label}")

    if not dangling:
        print(f"✓ 交叉引用: {len(refs)} 处引用 / {len(labels)} 个锚点，全部有效")
    return 1 if dangling else 0


if __name__ == "__main__":
    sys.exit(main())
