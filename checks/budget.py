#!/usr/bin/env python3
"""字数预算判定。

低于下界 = 没写完；高于上界 = 在膨胀。两者都是判定失败，不是提示。
字数统计只算正文：剔除 YAML front matter、代码块、表格、图片、引用块，
因为那些不是"读者要读的字"，把它们算进来会让预算失去意义。
"""
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
BUDGET = yaml.safe_load((ROOT / "budget.yml").read_text(encoding="utf-8"))

FENCE = re.compile(r"^(```|:::)", re.M)


def body_chars(path: Path) -> int:
    """正文中文字符数。代码块/表格/front matter 不计。"""
    text = path.read_text(encoding="utf-8")
    if text.startswith("---"):                      # 去掉 front matter
        parts = text.split("---", 2)
        text = parts[2] if len(parts) > 2 else ""

    # HTML 注释是骨架/待办，不是正文。算进来的话，一章写满 TODO
    # 也会显示成"已完成" —— 那正是本书讲的假绿。
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)

    out, in_fence = [], False
    for line in text.splitlines():
        if FENCE.match(line.strip()):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        s = line.strip()
        # 表格、引用、标题都是内容，计入。
        # 只排除图片行与 Quarto 的 div 标记 —— 它们不占正文篇幅。
        # 代码块已经在上面的 fence 分支里排除了：它是证据，不是正文，
        # 而且以 ASCII 为主，计进来会严重扭曲中文字数。
        if s.startswith(("!", ":::")):
            continue
        out.append(line)

    # 只数 CJK 字符 + 拉丁词，标点不计
    body = "\n".join(out)
    cjk = len(re.findall(r"[一-鿿]", body))
    latin = len(re.findall(r"[A-Za-z]+", body))
    return cjk + latin


def main() -> int:
    enforce = "--enforce" in sys.argv
    tol = BUDGET["tolerance"]
    rows, failed, total_actual = [], [], 0

    for rel, target in BUDGET["chapters"].items():
        path = ROOT / rel
        actual = body_chars(path) if path.exists() else 0
        total_actual += actual
        lo, hi = int(target * (1 - tol)), int(target * (1 + tol))
        pct = actual / target * 100 if target else 0

        if actual == 0:
            state = "空"
        elif actual < lo:
            state = "欠"
        elif actual > hi:
            state = "超"
        else:
            state = "✓"

        if state in ("欠", "超"):
            failed.append((rel, actual, target, state))
        rows.append((rel, actual, target, pct, state))

    width = max(len(r[0]) for r in rows)
    print(f"{'章节':<{width}}  {'实际':>7} {'预算':>7} {'进度':>7}  状态")
    print("-" * (width + 32))
    for rel, actual, target, pct, state in rows:
        print(f"{rel:<{width}}  {actual:>7,} {target:>7,} {pct:>6.0f}%  {state}")
    print("-" * (width + 32))
    print(f"{'合计':<{width}}  {total_actual:>7,} {BUDGET['total']:>7,} "
          f"{total_actual / BUDGET['total'] * 100:>6.0f}%")

    if enforce and failed:
        print(f"\nguard: {len(failed)} 章不在预算区间内", file=sys.stderr)
        for rel, actual, target, state in failed:
            print(f"  [{state}] {rel}: {actual:,} / {target:,}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
