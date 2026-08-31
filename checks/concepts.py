#!/usr/bin/env python3
"""核心概念的首次出现必须带指针。

一本书里的前向引用是正常的 —— 你会在第 2 章提到第 17 章才定义的东西。
但如果**第一次**提到它时不给指针，读者就卡住了：
他不知道这个词在哪定义，也不知道该不该现在去查。

哨兵：概念表少于 10 条时判定自己坏了（见正文 @sec-sentinel）。
"""
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
BUDGET = yaml.safe_load((ROOT / "budget.yml").read_text(encoding="utf-8"))
CONCEPTS = yaml.safe_load((ROOT / "concepts.yml").read_text(encoding="utf-8"))["concepts"]

SENTINEL_MIN = 10          # 概念表至少这么多条，否则判定自己坏了
WINDOW = 6                 # 指针必须出现在首次提及的前后几行内


def main() -> int:
    if len(CONCEPTS) < SENTINEL_MIN:
        print(f"guard: 概念表只有 {len(CONCEPTS)} 条，低于哨兵下限 {SENTINEL_MIN}",
              file=sys.stderr)
        return 2

    order = [r for r in BUDGET["chapters"] if (ROOT / r).exists()]
    text = {r: (ROOT / r).read_text(encoding="utf-8") for r in order}

    # 锚点必须真的存在，否则这条检查在验一个不存在的目标
    labels = set()
    for body in text.values():
        labels.update(re.findall(r"\{#(sec-[A-Za-z0-9_-]+)", body))

    problems, ghosts = [], []
    # mermaid 图里的标签不是正文散文 —— 一张图里出现某个术语，
    # 不构成"读者需要在这里拿到指针"。把图块整体剔掉再找首次出现。
    text = {rel: re.sub(r"```\{mermaid\}.*?```", "", body, flags=re.S)
            for rel, body in text.items()}

    for item in CONCEPTS:
        term, anchor = item["term"], item["anchor"]
        if anchor not in labels:
            ghosts.append((term, anchor))
            continue

        for rel in order:
            lines = text[rel].splitlines()
            hit = next(
                (i for i, line in enumerate(lines)
                 if term in line and not line.strip().startswith(("#", "<!--", "|"))),
                None,
            )
            if hit is None:
                continue
            window = "\n".join(lines[max(0, hit - WINDOW): hit + WINDOW + 1])
            if f"@{anchor}" not in window:
                problems.append((term, rel, hit + 1, anchor))
            break

    if ghosts:
        print(f"guard: {len(ghosts)} 个概念指向不存在的锚点", file=sys.stderr)
        for term, anchor in ghosts:
            print(f"  「{term}」 → @{anchor}", file=sys.stderr)
        return 2

    if problems:
        print(f"guard: {len(problems)} 个概念首次出现时没有指向定义的指针",
              file=sys.stderr)
        for term, rel, line, anchor in problems:
            print(f"  {rel}:{line}  「{term}」应补 @{anchor}", file=sys.stderr)
        return 1

    print(f"✓ 核心概念: {len(CONCEPTS)} 个，首次出现时全部带指针")
    return 0


if __name__ == "__main__":
    sys.exit(main())
