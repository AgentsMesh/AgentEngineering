#!/usr/bin/env python3
"""行文形态：段落要成型，加粗要省。

一次测量发现：全书 54% 的段落只有一句话，91% 在两句以内，
六句以上的段落一个都没有，平均每 68 字一处加粗。

那是把一段推理拆成五个孤立的短句、每句自成一段的写法 ——
读起来像幻灯片提纲，不像有人在讲。《重构》那样的技术书，
段落通常 3–6 句，靠连接词和转折把读者带过一条完整的线。

判定三件事：
  1. 单句段落占比不超过阈值
  2. 平均句数达到下界
  3. 加粗密度不超过上限

哨兵：待检文件少于 20 个时判定自己坏了（见正文 @sec-sentinel）。
"""
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
BUDGET = yaml.safe_load((ROOT / "budget.yml").read_text(encoding="utf-8"))

SENTINEL_MIN = 20
MAX_SINGLE_RATIO = 0.35      # 单句段落占比上限
# 导航/索引性质的章节例外：前言的「我不讲什么」、术语表的词条辨析，
# 它们本来就是并列的短条目，硬合并成长段会更难读。
# 豁免写明理由，而不是把全局阈值放松 —— 见正文 @sec-allow-files。
LOOSE = {"index.qmd": 0.50, "chapters/05-appendix/d-glossary.qmd": 0.90}
MIN_AVG_SENTENCES = 2.0      # 平均句数下界
MIN_CHARS_PER_BOLD = 110     # 平均多少字才允许一处加粗

SKIP_PREFIX = ("#", "|", ">", "-", "*", ":::", "<!--", "```", "1.", "2.", "3.")


def analyse(text: str) -> tuple[int, int, int, int]:
    """返回 (段落数, 单句段数, 总句数, 加粗数, 中文字数) 的前四项 + 字数。"""
    text = re.sub(r"^---.*?---\n", "", text, flags=re.S)
    text = re.sub(r"```.*?```", "", text, flags=re.S)

    paras, singles, sentences, bolds = 0, 0, 0, 0
    for block in re.split(r"\n\s*\n", text):
        body = block.strip()
        if not body or body.startswith(SKIP_PREFIX):
            continue
        # 以冒号结尾的引导句（"三个原因："「这个模型是这么说的：」）
        # 是下文的一部分，不是一个独立段落。把它算成单句段落会
        # 系统性地惩罚正常的写法 —— 这是一次误报，修规则不修稿。
        if body.rstrip().endswith(("：", ":")):
            continue
        paras += 1
        n = len([x for x in re.split(r"[。？！]", body.replace("\n", "")) if x.strip()])
        sentences += n
        # 一个 60 字以上的长句不是碎片 —— 它承载了一段完整的推理，
        # 只是没有被句号切开（枚举、并列、带破折号的展开都是这样）。
        # 只按句数判会系统性地惩罚这种写法，而那是一次误报。
        cjk = len(re.findall(r"[一-鿿]", body))
        if n <= 1 and cjk < 60:
            singles += 1
        bolds += len(re.findall(r"\*\*", body)) // 2
    chars = len(re.findall(r"[一-鿿]", text))
    return paras, singles, sentences, bolds, chars


def main() -> int:
    strict = "--strict" in sys.argv
    files = [r for r in BUDGET["chapters"] if (ROOT / r).exists()]
    if len(files) < SENTINEL_MIN:
        print(f"guard: 只找到 {len(files)} 个待检文件 —— 文件布局变了？", file=sys.stderr)
        return 2

    rows, failed = [], []
    for rel in files:
        paras, singles, sents, bolds, chars = analyse((ROOT / rel).read_text(encoding="utf-8"))
        if not paras:
            continue
        ratio = singles / paras
        avg = sents / paras
        per_bold = chars // bolds if bolds else 9999
        limit = LOOSE.get(rel, MAX_SINGLE_RATIO)
        floor = 1.5 if rel in LOOSE else MIN_AVG_SENTENCES
        bad = (ratio > limit or avg < floor or per_bold < MIN_CHARS_PER_BOLD)
        rows.append((rel, paras, ratio, avg, per_bold, bad))
        if bad:
            failed.append(rel)

    width = max(len(Path(r[0]).stem) for r in rows)
    print(f"{'章节':<{width + 2}} {'段数':>5} {'单句%':>7} {'均句':>6} {'字/粗':>7}  状态")
    print("-" * (width + 36))
    for rel, paras, ratio, avg, per_bold, bad in rows:
        pb = "—" if per_bold == 9999 else str(per_bold)
        print(f"{Path(rel).stem:<{width + 2}} {paras:>5} {ratio * 100:>6.0f}% "
              f"{avg:>6.1f} {pb:>7}  {'✗' if bad else '✓'}")

    print("-" * (width + 36))
    print(f"阈值：单句 ≤{MAX_SINGLE_RATIO:.0%}，均句 ≥{MIN_AVG_SENTENCES}，"
          f"每 ≥{MIN_CHARS_PER_BOLD} 字一处加粗")

    if failed and strict:
        print(f"\nguard: {len(failed)} 章行文不达标", file=sys.stderr)
        return 1
    if failed:
        print(f"\n{len(failed)} 章待改写（跑 make check-prose-strict 让它拦人）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
