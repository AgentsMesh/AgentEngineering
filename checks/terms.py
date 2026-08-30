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
        exempt = False
        for lineno, line in enumerate(text, 1):
            if line.strip().startswith("```"):
                in_fence = not in_fence
                continue
            # 区段豁免：讨论术语本身的散文，不该被术语规则命中。
            # 对应源系统的 source_view = code_only —— 规则不看讲解自己的文字。
            if "<!-- terms:off -->" in line:
                exempt = True
                continue
            if "<!-- terms:on -->" in line:
                exempt = False
                continue
            if in_fence or exempt or line.strip().startswith("<!--"):
                continue
            for term in TERMS:
                # 先把豁免片段挖掉再匹配，否则规则会在正确的用法上误报，
                # 然后被绕过 —— 见正文 @sec-forbid-tuning
                probe = line
                for ok in term.get("allow", []):
                    probe = probe.replace(ok, "")
                for bad in term["forbidden"]:
                    if bad in probe:
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
