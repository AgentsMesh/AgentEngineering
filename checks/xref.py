#!/usr/bin/env python3
"""交叉引用有效性。

300 页的书前后互指几百次，手工维护必错。这条检查保证每个 @sec-/@fig-/@tbl-
都指向一个真实存在的锚点，并报出无人引用的孤儿锚点（通常意味着那段内容
本来打算被引用，后来被改写掉了）。

它还拦重复锚点，而这一条是补上去的：一次改写在第 8 章留下了两个
同名的 #sec-correct-step-eight，而这条检查当时是绿的 ——
因为它只问「引用指向的锚点存在吗」，两个同名锚点里只要有一个存在，
这个问题的答案就是「是」。@sec-shape-a：探针测的不是你以为的东西。

重复锚点的实际后果是渲染层静默选一个：读者点一次交叉引用，
跳到的可能是写的人没打算给他看的那一节，而没有任何东西会报错。

行内代码（`@sec-xxx` 这种反引号里的）不算引用。一本讲交叉引用的书
必然要把引用的**写法**当成例子写出来，而那不是一次引用 ——
这正是正文 @sec-source-view 讲的"规则被自己的文档绊倒"：
不排除它，这条检查会在第 18 章那段讲它自己的文字上误报，
然后被绕过（@sec-bypass）。Quarto 也不解析代码里的引用，
所以这个排除和渲染行为是一致的，不是为了让检查过而开的口子。
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REF = re.compile(r"@(sec|fig|tbl|eq)-([A-Za-z0-9_-]+)")
INLINE_CODE = re.compile(r"`[^`]*`")
LABEL = re.compile(r"\{#(sec|fig|tbl|eq)-([A-Za-z0-9_-]+)[^}]*\}")


def main() -> int:
    labels: dict[str, Path] = {}
    seen: dict[str, list[tuple[Path, int]]] = {}
    refs: list[tuple[str, Path, int]] = []

    for path in sorted(ROOT.glob("**/*.qmd")):
        if "_output" in path.parts:
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            for kind, name in LABEL.findall(line):
                key = f"{kind}-{name}"
                labels[key] = path
                seen.setdefault(key, []).append((path, lineno))
            for kind, name in REF.findall(INLINE_CODE.sub("", line)):
                refs.append((f"{kind}-{name}", path, lineno))

    dangling = [(r, p, n) for r, p, n in refs if r not in labels]
    duplicated = {k: v for k, v in seen.items() if len(v) > 1}
    referenced = {r for r, _, _ in refs}
    orphans = {k: v for k, v in labels.items() if k not in referenced and k.startswith("sec-")}

    if dangling:
        print(f"guard: {len(dangling)} 处交叉引用指向不存在的锚点", file=sys.stderr)
        for ref, path, lineno in dangling:
            print(f"  {path.relative_to(ROOT)}:{lineno}  @{ref}", file=sys.stderr)

    if duplicated:
        print(f"guard: {len(duplicated)} 个锚点被定义了不止一次", file=sys.stderr)
        for label, places in sorted(duplicated.items()):
            where = " · ".join(f"{p.relative_to(ROOT)}:{n}" for p, n in places)
            print(f"  #{label}  ←  {where}", file=sys.stderr)

    if orphans:
        print(f"\n提示: {len(orphans)} 个 section 锚点无人引用（不拦，供检视）")
        for label, path in sorted(orphans.items()):
            print(f"  {path.relative_to(ROOT)}  #{label}")

    if not dangling and not duplicated:
        print(
            f"✓ 交叉引用: {len(refs)} 处引用 / {len(labels)} 个锚点，"
            f"全部有效且无重复定义"
        )
    return 1 if (dangling or duplicated) else 0


if __name__ == "__main__":
    sys.exit(main())
