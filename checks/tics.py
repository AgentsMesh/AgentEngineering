#!/usr/bin/env python3
"""口头禅与结构套路 —— 也就是俗称的「AI 味」。

`prose.py` 管的是段落形态（单句成段、平均句数），这条管的是词法层：
同一个句式被无意识地反复使用，读起来像机器在打节拍。

阈值不是拍脑袋定的，是拿源分享稿当对照组量出来的 ——
同一个人、同一个领域、同一种语言、420 句，人写的。
测出来的基线：句首「而」0.7% · 被加粗的字占正文 6.1%。
书里最初的读数是 9.8% 和 18.0%。

阈值：句首「而」≤3.5% · 被加粗字占比 ≤8%。
不定成基线本身是因为那会变成另一种不自然 ——
目标是去掉拐棍，不是模仿另一个人的呼吸。

这里原本还有第三条「小节以加粗句收尾的比例」，删掉了：
它的第一版定义（末段里含加粗）在这本书上读出 76%，
而按「末句整句加粗」重测是 0% —— 两个定义差了 76 个百分点，
说明第一版量的是一个近乎恒真的东西，不是那个套路。
换成有区分度的定义之后它和加粗占比是 2.4× 对 2.6×，
基本同一个量的两种说法。一条和已有指标高度共线、
又难以定义清楚的检查，留着只会制造噪声。修规则不修稿。

两条都是跨章统计，所以它们按全书判定，不逐章拦 ——
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
MAX_BOLD_CHAR_RATIO = 0.08  # 被加粗的字占正文的比例上限
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


def unbalanced_bold(text: str) -> bool:
    """正文里的 ** 是不是成对。

    一个漏掉的闭合标记不会让 markdown 报错，也不会让页面变得难看多少 ——
    它只会让「加粗到哪里结束」这个问题的答案一路滑到下一个 ** 为止。
    对渲染来说是一段过长的加粗；对这条检查来说，是一次几百字的假加粗，
    足以把全书的占比从 7.3% 抬到 9.8%。
    量的是同一件事，坏的是量它的那把尺子 —— 所以这里返回基建故障（2），
    不是内容违规（1）。

    行内代码要先换成占位符：glob 里的 `Modules/**/*.swift` 带一个 **，
    它不是加粗标记，但会让计数变成奇数。
    """
    t = re.sub(r"```.*?```", "§", text, flags=re.S)
    t = re.sub(r"`[^`\n]*`", "§", t)
    return t.count("**") % 2 == 1


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
    bold_chars = 0
    per_chapter: list[tuple[float, str, int]] = []

    broken = [p for p in files if unbalanced_bold(p.read_text(encoding="utf-8"))]
    if broken:
        print(f"guard: {len(broken)} 个文件里的 ** 没有成对 —— 加粗统计不可信", file=sys.stderr)
        for p in broken:
            print(f"  {p.relative_to(ROOT)}", file=sys.stderr)
        return 2

    for path in files:
        raw = path.read_text(encoding="utf-8")
        paras = paragraphs(raw)
        sents = sentences(paras)
        all_sentences += sents

        # 逐文件量。把全书拼成一个字符串再匹配，会让某一章末尾的
        # `**` 和下一章开头的 `**` 配成一对，匹配出跨章的巨大假区间 ——
        # 那次的读数是 58%，逐文件量是 15.8%。
        stripped = strip_non_prose(raw)
        prose_chars += len(re.sub(r"\s", "", re.sub(r"\*", "", stripped)))
        for b in re.findall(r"\*\*([^*]+)\*\*", stripped):
            bold_count += 1
            bold_chars += len(re.sub(r"\s", "", b))

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
    bold_ratio = bold_chars / max(prose_chars, 1)

    print(f"全书 {len(all_sentences):,} 句 / {prose_chars:,} 字（对照：源分享 420 句 / 6.1%）\n")
    print(f"  句首「而」      {er_total:>5} 句   {er_ratio*100:>5.1f}%   上限 {MAX_ER_RATIO*100:.1f}%")
    print(f"  被加粗的字      {bold_count:>5} 处   {bold_ratio*100:>5.1f}%   上限 {MAX_BOLD_CHAR_RATIO*100:.0f}%")

    bad = []
    if er_ratio > MAX_ER_RATIO:
        bad.append("句首「而」过密")
    if bold_ratio > MAX_BOLD_CHAR_RATIO:
        bad.append("加粗过多")

    if bad:
        print(f"\nguard: {' · '.join(bad)}", file=sys.stderr)
        if er_ratio > MAX_ER_RATIO:
            print("\n句首「而」最密的几章：", file=sys.stderr)
            for ratio, name, count in sorted(per_chapter, reverse=True)[:6]:
                print(f"  {name:<32}{count:>4} 句  {ratio*100:>5.1f}%", file=sys.stderr)
        return 1

    print("\n✓ 口头禅: 句首「而」与加粗占比都在阈值内")
    return 0


if __name__ == "__main__":
    sys.exit(main())
