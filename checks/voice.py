#!/usr/bin/env python3
"""口吻检查：第三人称自指 + 答辩腔。

这本书是「我」在说话。两类东西会破坏这一点，而它们在写作中
会反复冒出来（因为它们各自都有一个看起来合理的动机）：

  1. 第三人称自指 —— 「本书讲的是…」读起来像论文摘要
  2. 答辩腔 —— 宣布自己诚实、预防性辩解、解释自己的写作选择

哨兵：规则表少于 8 条时判定自己坏了（见正文 @sec-sentinel）。
"""
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
RULES = yaml.safe_load((ROOT / "voice.yml").read_text(encoding="utf-8"))["forbidden"]
SENTINEL_MIN = 8


def main() -> int:
    if len(RULES) < SENTINEL_MIN:
        print(f"guard: 口吻规则只有 {len(RULES)} 条，低于哨兵下限 {SENTINEL_MIN}",
              file=sys.stderr)
        return 2

    targets = sorted(ROOT.glob("chapters/**/*.qmd")) + [ROOT / "index.qmd"]
    if len(targets) < 20:
        print(f"guard: 只找到 {len(targets)} 个待检文件 —— 文件布局变了？",
              file=sys.stderr)
        return 2

    hits = []
    for path in targets:
        in_fence = False
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.strip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence or line.strip().startswith("<!--"):
                continue
            if line.startswith("claim:"):          # front matter 里的承诺不受此限
                continue
            for rule in RULES:
                pat = rule["pattern"]
                if pat not in line:
                    continue
                probe = line
                for ok in rule.get("allow", []):
                    probe = probe.replace(ok, "")
                if pat in probe:
                    hits.append((path.relative_to(ROOT), lineno, pat, rule["why"]))

    if hits:
        print(f"guard: {len(hits)} 处口吻问题", file=sys.stderr)
        for rel, lineno, pat, why in hits[:25]:
            print(f"  {rel}:{lineno}  「{pat}」—— {why}", file=sys.stderr)
        if len(hits) > 25:
            print(f"  …… 另有 {len(hits) - 25} 处", file=sys.stderr)
        return 1

    print(f"✓ 口吻: {len(targets)} 个文件，{len(RULES)} 条规则，无第三人称自指与答辩腔")
    return 0


if __name__ == "__main__":
    sys.exit(main())
