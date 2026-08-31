#!/usr/bin/env python3
"""口头禅与结构套路 —— 也就是俗称的「AI 味」。

`prose.py` 管的是段落形态（单句成段、平均句数），这条管的是词法层：
同一个句式被无意识地反复使用，读起来像机器在打节拍。

阈值不是拍脑袋定的，是拿源分享稿当对照组量出来的 ——
同一个人、同一个领域、同一种语言、420 句，人写的。
测出来的基线：句首「而」0.7% · 每 255 字一处加粗。
书里最初的读数是 9.8% 和每 107 字一处，也就是 14 倍和 2.4 倍。

阈值定在基线和当时读数之间，取一个够得着但确实要改的位置：
句首「而」≤3.5% · 每 ≥150 字一处加粗 · 小节加粗收尾 ≤50%。
不定成 0.7% 是因为那会变成另一种不自然 ——
目标是去掉拐棍，不是模仿另一个人的呼吸。

三条都是**跨章统计**，所以它们按全书判定，不逐章拦 ——
一章偶尔密一点不是问题，全书系统性地密才是。

测量的坑（这条检查自己踩过一次）：书是硬换行的，
所以「行首的而」远多于「句首的而」—— 第一版按行首数，
得到 41‰ 这个被污染的读数。必须先按空行切段、段内合行，
再按 。！？ 切句。@sec-shape-a：探针测的不是你以为的东西。

退出码：0 通过 / 1 内容违规 / 2 基建故障。
"""
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("guard: 缺 pyyaml（pip3 install pyyaml）", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent

MAX_ER_RATIO = 0.035        # 句首「而」占全部句子的比例上限
MIN_CHARS_PER_BOLD = 150    # 平均每多少字才允许一处加粗
MAX_BOLD_ENDING = 0.50      # 以加粗结尾的小节占比上限
SENTINEL_MIN_SENTENCES = 2000   # 扫到的句子少于这个数，说明解析坏了


def chapters() -> list[Path]:
    cfg = yaml.safe_load((ROOT / "_quarto.yml").read_text(encoding="utf-8"))
    out: list[Path] = []

    def walk(node):
        if isinstance(node, str) and node.endswith(".qmd"):
            out.append(ROOT / node)
        elif isinstance(node, dict):
            for v in node.values():
                walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)

    walk(cfg["book"])
    return out


def strip_non_prose(text: str) -> str:
    text = re.sub(r"^---\n.*?\n---\n", "", text, flags=re.S)   # front matter
    text = re.sub(r"```.*?```", "", text, flags=re.S)          # 代码与 mermaid
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    return text


def paragraphs(text: str) -> list[str]:
    """按空行切段，段内合行 —— 硬换行不能被当成句子边界。"""
    body = re.sub(r"^\|.*$", "", strip_non_prose(text), flags=re.M)   # 表格
    body = re.sub(r"^#{1,6} .*$", "", body, flags=re.M)               # 标题
    body = re.sub(r"^\s*[-*>] .*$", "", body, flags=re.M)             # 列表与引用
    out = []
    for chunk in re.split(r"\n\s*\n", body):
        joined = re.sub(r"\s*\n\s*", "", chunk).strip()
        if len(joined) > 20:
            out.append(joined)
    return out


def sentences(paras: list[str]) -> list[str]:
    out = []
    for p in paras:
        plain = re.sub(r"\*\*|\*|`", "", p)
        out += [s.strip() for s in re.split(r"(?<=[。！？])", plain) if len(s.strip()) > 3]
    return out


def main() -> int:
    files = chapters()
    all_sentences: list[str] = []
    prose_chars = 0
    bold_count = 0
    sections_total = 0
    sections_bold_end = 0
    per_chapter: list[tuple[float, str, int]] = []

    for path in files:
        raw = path.read_text(encoding="utf-8")
        paras = paragraphs(raw)
        sents = sentences(paras)
        all_sentences += sents

        stripped = strip_non_prose(raw)
        prose_chars += len(re.sub(r"\s", "", stripped))
        bold_count += len(re.findall(r"\*\*[^*]+\*\*", stripped))

        for sec in re.split(r"\n#{2,4} ", stripped)[1:]:
            blocks = [b.strip() for b in re.split(r"\n\s*\n", sec) if b.strip()]
            sections_total += 1
            if blocks and "**" in blocks[-1][-160:]:
                sections_bold_end += 1

        er = sum(1 for s in sents if s.startswith("而"))
        if sents:
            per_chapter.append((er / len(sents), path.stem, er))

    if len(all_sentences) < SENTINEL_MIN_SENTENCES:
        print(
            f"guard: 只解析出 {len(all_sentences)} 句（下限 {SENTINEL_MIN_SENTENCES}）——"
            "解析逻辑坏了，不是书变短了",
            file=sys.stderr,
        )
        return 2

    er_total = sum(1 for s in all_sentences if s.startswith("而"))
    er_ratio = er_total / len(all_sentences)
    chars_per_bold = prose_chars // max(bold_count, 1)
    bold_end_ratio = sections_bold_end / max(sections_total, 1)

    print(f"全书 {len(all_sentences):,} 句 / {prose_chars:,} 字（对照：源分享 420 句）\n")
    print(f"  句首「而」      {er_total:>5} 句   {er_ratio*100:>5.1f}%   上限 {MAX_ER_RATIO*100:.1f}%")
    print(f"  加粗密度        {bold_count:>5} 处   每 {chars_per_bold} 字   下限 每 {MIN_CHARS_PER_BOLD} 字")
    print(f"  加粗收尾的小节  {sections_bold_end:>5} 个   {bold_end_ratio*100:>5.1f}%   上限 {MAX_BOLD_ENDING*100:.0f}%")

    bad = []
    if er_ratio > MAX_ER_RATIO:
        bad.append("句首「而」过密")
    if chars_per_bold < MIN_CHARS_PER_BOLD:
        bad.append("加粗过密")
    if bold_end_ratio > MAX_BOLD_ENDING:
        bad.append("太多小节以加粗句收尾")

    if bad:
        print(f"\nguard: {' · '.join(bad)}", file=sys.stderr)
        print("\n句首「而」最密的几章：", file=sys.stderr)
        for ratio, name, count in sorted(per_chapter, reverse=True)[:6]:
            print(f"  {name:<32}{count:>4} 句  {ratio*100:>5.1f}%", file=sys.stderr)
        return 1

    print("\n✓ 口头禅: 句首「而」、加粗密度、加粗收尾三项都在阈值内")
    return 0


if __name__ == "__main__":
    sys.exit(main())
