#!/usr/bin/env python3
"""中文排版检查，带哨兵。

哨兵存在的理由是一次真实的教训：autocorrect 默认不认某些扩展名，
配置错了它会扫描 0 个文件、返回 0、显示通过 —— 一个标准的假绿。
所以这里不直接调 autocorrect，而是先确认它真的扫到了东西。

对应正文 @sec-sentinel：一条规则必须声明它至少应该看到多少个事实。
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGETS = ["chapters/", "index.qmd"]

# 哨兵下限：本书有 26 章。低于这个数说明扫描面异常缩小 ——
# 更可能是扩展名/配置坏了，而不是章节一夜之间消失了。
SENTINEL_MIN = 20


def main() -> int:
    expected = len(list((ROOT / "chapters").rglob("*.qmd"))) + 1
    if expected < SENTINEL_MIN:
        print(f"guard: 只找到 {expected} 个待检文件，低于哨兵下限 {SENTINEL_MIN}",
              file=sys.stderr)
        print("       更可能是文件布局变了，而不是章节变少了", file=sys.stderr)
        return 2

    try:
        proc = subprocess.run(
            ["autocorrect", "--lint", "--format", "json", *TARGETS],
            cwd=ROOT, capture_output=True, text=True,
        )
    except FileNotFoundError:
        print("guard: autocorrect 未安装", file=sys.stderr)
        return 2

    try:
        report = json.loads(proc.stdout)
    except json.JSONDecodeError:
        print("guard: autocorrect 的输出解析不了 —— 版本变了？", file=sys.stderr)
        print(proc.stdout[:400], file=sys.stderr)
        return 2

    count = report.get("count", 0)
    if count:
        print(f"guard: {count} 处中文排版问题（跑 `make fix` 自动修）", file=sys.stderr)
        for msg in report.get("messages", [])[:20]:
            print(f"  {msg.get('filepath')}:{msg.get('line')}:{msg.get('col')}",
                  file=sys.stderr)
        return 1

    print(f"✓ 中文排版: {expected} 个文件，无问题（哨兵下限 {SENTINEL_MIN}）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
