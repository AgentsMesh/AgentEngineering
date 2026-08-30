#!/usr/bin/env python3
"""术语一致性。同一个概念全书只能有一种写法。"""
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
TERMS = yaml.safe_load((ROOT / "terms.yml").read_text(encoding="utf-8"))["terms"]


def main() -> int:
    hits = []
    for path in sorted(ROOT.glob("chapters/**/*.qmd")):
        text = path.read_text(encoding="utf-8").splitlines()
        in_fence = False
        for lineno, line in enumerate(text, 1):
            if line.strip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence or line.strip().startswith("<!--"):
                continue
            for term in TERMS:
                for bad in term["forbidden"]:
                    if bad in line:
                        hits.append((path, lineno, bad, term["canonical"]))

    if hits:
        print(f"guard: {len(hits)} 处术语不一致", file=sys.stderr)
        for path, lineno, bad, good in hits:
            print(f"  {path.relative_to(ROOT)}:{lineno}  「{bad}」→ 应为「{good}」",
                  file=sys.stderr)
        return 1

    print(f"✓ 术语一致性: {len(TERMS)} 组术语，无冲突")
    return 0


if __name__ == "__main__":
    sys.exit(main())
