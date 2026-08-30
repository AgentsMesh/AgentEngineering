#!/usr/bin/env python3
"""每章必须声明一个可验证的承诺，并且这个承诺必须是可证伪的。

这是变异验证的书籍版本：
    每章 front matter 里写 claim: "读完这章，读者能做到 X"
    然后自问：把这章删掉，读者还能不能做到 X？
    如果能，这章就是凑页数的。

检查器只能验证形式（承诺存在、不为空、不是套话）。
"能不能做到 X"要靠人判，但没有这句话就一定没人判。
"""
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
BUDGET = yaml.safe_load((ROOT / "budget.yml").read_text(encoding="utf-8"))

# 套话黑名单：这些开头的承诺等于没写
VAGUE = ["介绍", "讲解", "说明", "概述", "了解", "认识", "熟悉", "理解"]


def main() -> int:
    problems = []
    checked = 0

    for rel in BUDGET["chapters"]:
        path = ROOT / rel
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        if not text.startswith("---"):
            problems.append((rel, "缺少 front matter"))
            continue

        try:
            meta = yaml.safe_load(text.split("---", 2)[1]) or {}
        except yaml.YAMLError as exc:
            problems.append((rel, f"front matter 解析失败: {exc}"))
            continue

        claim = (meta.get("claim") or "").strip()
        checked += 1

        if not claim:
            problems.append((rel, "没有声明 claim"))
        elif len(claim) < 12:
            problems.append((rel, f"claim 过短，无法证伪: 「{claim}」"))
        elif any(claim.startswith(v) for v in VAGUE):
            problems.append((rel, f"claim 是套话，不可证伪: 「{claim}」"))

    if problems:
        print(f"guard: {len(problems)} 章的承诺不合格", file=sys.stderr)
        for rel, why in problems:
            print(f"  {rel}: {why}", file=sys.stderr)
        return 1

    print(f"✓ 章节承诺: {checked} 章全部声明了可证伪的 claim")
    return 0


if __name__ == "__main__":
    sys.exit(main())
