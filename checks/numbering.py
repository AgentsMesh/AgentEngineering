#!/usr/bin/env python3
"""章节编号一致性。

这条检查来自一个真实的 bug：侧栏显示「2 两堵墙」，而正文标题显示「3 两堵墙」，
后面所有小节都跟着错位。

根因是每一章同时有 front matter 的 `title:` 和正文的 `# 一级标题` ——
Quarto 用前者做章标题，Pandoc 又把后者当成一个独立的一级节去编号，
于是产生两套错开的编号。

Quarto 的文档说得很清楚：两者用其一，不该同时有。

判定三件事：
  1. 每章只能有一个内容 h1（前言那种无编号章除外）
  2. 章号和它第一个二级标题的前缀必须一致（2 → 2.1）
  3. 章号必须连续，不跳号

需要先 make html。
"""
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
BUDGET = yaml.safe_load((ROOT / "budget.yml").read_text(encoding="utf-8"))
SENTINEL_MIN = 20


def strip_tags(html: str) -> str:
    return re.sub(r"<[^>]+>", "", html).strip().replace("\xa0", " ")


def main() -> int:
    out_root = ROOT / "_output"
    if not out_root.exists():
        print("guard: 还没有构建产物 —— 先跑 make html", file=sys.stderr)
        return 2

    pages = []
    for rel in BUDGET["chapters"]:
        out = out_root / rel.replace(".qmd", ".html")
        if out.exists():
            pages.append((rel, out))

    if len(pages) < SENTINEL_MIN:
        print(f"guard: 只找到 {len(pages)} 个产物，低于哨兵下限 {SENTINEL_MIN}",
              file=sys.stderr)
        print("       更可能是构建不完整，而不是章节变少了", file=sys.stderr)
        return 2

    problems, seen = [], []
    unresolved = 0
    for rel, out in pages:
        html = out.read_text(encoding="utf-8")

        # ⚠️ 源文件里的 @sec- 语法正确，不等于它在产物里解析成功了。
        # 这一条是撞出来的：把章级锚点从 h1 挪进 front matter 的 `id:` 之后，
        # 源文件层面的交叉引用检查依然全绿，而产物里 109 处变成了 ?sec-xxx。
        # 源文件的检查看语法，这里必须看结果。
        n = html.count("quarto-unresolved-ref")
        if n:
            unresolved += n
            problems.append((rel, f"{n} 处交叉引用在产物里没解析（页面上会显示 ?sec-xxx）"))
        h1 = [strip_tags(m) for m in re.findall(r"<h1[^>]*>(.*?)</h1>", html, re.S)]
        h1 = [x for x in h1 if x]
        h2 = [strip_tags(m) for m in re.findall(r"<h2[^>]*>(.*?)</h2>", html, re.S)]
        h2 = [x for x in h2 if x and x != "目录"]

        title = h1[0] if h1 else ""
        num = re.match(r"^([0-9]+|[A-Z])(?:\s|\u00a0|&nbsp;)", title)

        # 无编号章（前言）：跳过编号一致性。
        # index.qmd 例外：Quarto 的首页固有地有两个 h1（书名 + 章标题），
        # 这是模板结构，不是内容重复。
        if not num:
            if len(h1) > 1 and rel != "index.qmd":
                problems.append((rel, f"有 {len(h1)} 个 h1 —— front matter title 和正文 # 重复了"))
            continue

        seen.append((rel, num.group(1)))

        if len(h1) > 1:
            problems.append((rel, f"有 {len(h1)} 个 h1：{h1[:2]} —— 编号会错开"))

        if h2:
            pre = re.match(r"^([\dA-Z]+)\.", h2[0])
            if pre and pre.group(1) != num.group(1):
                problems.append((rel, f"章号 {num.group(1)}，但小节是 {h2[0][:18]}"))

    # 数字章必须连续
    digits = [int(n) for _, n in seen if n.isdigit()]
    for i, n in enumerate(digits, start=1):
        if n != i:
            problems.append(("章序", f"第 {i} 个数字章的编号是 {n}，跳号了"))
            break

    if problems:
        print(f"guard: {len(problems)} 处编号问题", file=sys.stderr)
        for rel, why in problems[:15]:
            print(f"  {rel}: {why}", file=sys.stderr)
        return 1

    print(f"✓ 章节编号: {len(pages)} 页，{len(digits)} 个数字章连续，"
          f"页内与侧栏一致，交叉引用全部解析")
    return 0


if __name__ == "__main__":
    sys.exit(main())
