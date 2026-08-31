#!/usr/bin/env python3
"""车轱辘话 —— 同一个论断在书里被完整重述。

一本 18 万字的书必然会回指自己，问题不在回指，在于**回指的时候
把整段话又写了一遍**。第 13 章和第 15 章曾经各有一节
「报数模式还是一件测量仪器」，内容几乎逐字相同；
磁盘那五次事故在第 4 章和第 6 章各完整叙述过一遍；
fail-open 那段论证在第 11 章和第 18 章各写了一遍。
每一处单独看都合理（"这里读者需要这个背景"），合起来就是车轱辘话。

正确的形态是**指针加增量**：指向讲得最完整的那一处，
然后只写这一章需要的那一层。改完之后近重复从 69 对降到 24 对。

## 怎么量

按空行切段、段内合行、按 。！？ 切句，取 ≥14 个汉字的句子，
用 5-gram 的 Jaccard 相似度找近重复。5-gram 倒排索引先粗筛，
只比较共享稀有 gram 的句对，避免 O(n²)。

## 两类必须排除的假阳性

**一、小结类小节。**「压成三句话」复述论断是这个体裁的本分。
实测这些小结与正文的 6-gram 重叠是 22%–48%（均值 32%），
也就是三分之二是新的压缩，不是复述 —— 所以整节排除。

**二、刻意的复现句。** 「不承诺同样的代码，只承诺同样的判定边界」
在前言和末章各出现一次，那是主题句；
「本机绿是必要条件，不是充分条件」是一条被引用的规矩。
这类靠 ALLOW 白名单放行，每条都要写清楚为什么它该重复。

## 阈值

MAX_PAIRS 定在 27：清完存量之后的实测是 24 对，只留 3 对余量。
第一版定在 32，变异测试当场打脸 —— 注入 8 段完整复制的话，
读数从 24 涨到 32，**刚好卡在上限，检查不响**。
一个宽到能容下八段车轱辘话的上限等于没有上限（@sec-sentinel-limits
讲的是同一件事）。所以余量按「再多三对就该有人看一眼」定，不按手感定。

退出码：0 通过 / 1 内容违规 / 2 基建故障。
"""
import re
import sys
from collections import defaultdict
from pathlib import Path

try:
    import yaml
except ImportError:
    print("guard: 缺 pyyaml（pip3 install pyyaml）", file=sys.stderr)
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent
JACCARD = 0.45
MAX_PAIRS = 27
SENTINEL_MIN_SENTENCES = 3000   # 扫到的句子少于这个数，说明解析坏了

# 刻意的复现句：每条都要说清楚为什么它该出现不止一次。
ALLOW = [
    ("不承诺同样的代码", "全书主题句，前言与末章各一次"),
    ("本机绿是必要条件", "一条被反复引用的规矩，引用不算重述"),
    ("从第一天就打印它", "正文明说过这条被重复三次，是刻意的"),
    ("误报的规则会被绕过", "全书回指最多的一条因果链"),
    ("判定覆盖到哪里", "全书结论句"),
]


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


def prose(text: str) -> str:
    text = re.sub(r"^---\n.*?\n---\n", "", text, flags=re.S)
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"`[^`\n]*`", "", text)
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    text = re.sub(r"^\|.*$", "", text, flags=re.M)
    # 小结类小节整体排除，理由见模块开头
    text = re.sub(
        r"^#{2,4} (压成三句话|压成一句话|四章各自压成一句)[^\n]*\n.*?(?=^#{2,4} |\Z)",
        "", text, flags=re.M | re.S,
    )
    text = re.sub(r"^#{1,6} .*$", "", text, flags=re.M)
    text = re.sub(r"@sec-[a-z0-9-]+", "", text)
    return re.sub(r"\*+|>", "", text)


def sentences(files: list[Path]) -> list[tuple[str, str]]:
    out = []
    for f in files:
        for para in re.split(r"\n\s*\n", prose(f.read_text(encoding="utf-8"))):
            p = re.sub(r"\s*\n\s*", "", para).strip()
            for x in re.split(r"(?<=[。！？])", p):
                x = x.strip()
                if len(re.findall(r"[一-鿿]", x)) >= 14:
                    out.append((f.stem, x))
    return out


def grams(s: str, n: int = 5) -> set:
    z = "".join(re.findall(r"[一-鿿]+", s))
    return {z[i:i + n] for i in range(len(z) - n + 1)}


def allowed(a: str, b: str) -> bool:
    return any(k in a and k in b for k, _ in ALLOW)


def main() -> int:
    sents = sentences(chapters())
    if len(sents) < SENTINEL_MIN_SENTENCES:
        print(
            f"guard: 只解析出 {len(sents)} 句（下限 {SENTINEL_MIN_SENTENCES}）——"
            "解析逻辑坏了，不是书变短了",
            file=sys.stderr,
        )
        return 2

    G = [grams(s) for _, s in sents]
    idx = defaultdict(list)
    for i, g in enumerate(G):
        for x in g:
            idx[x].append(i)

    cand = set()
    for ids in idx.values():
        if len(ids) > 6:          # 太常见的 gram 不参与粗筛
            continue
        for a in range(len(ids)):
            for b in range(a + 1, len(ids)):
                cand.add((ids[a], ids[b]))

    hits = []
    for i, j in cand:
        if not G[i] or not G[j]:
            continue
        jac = len(G[i] & G[j]) / len(G[i] | G[j])
        if jac >= JACCARD and not allowed(sents[i][1], sents[j][1]):
            hits.append((jac, sents[i], sents[j]))
    hits.sort(reverse=True)

    print(f"句子 {len(sents):,}，近重复 {len(hits)} 对（上限 {MAX_PAIRS}）")
    if len(hits) > MAX_PAIRS:
        print(f"\nguard: 近重复 {len(hits)} 对，超过上限 {MAX_PAIRS}", file=sys.stderr)
        print("相似度最高的几对：", file=sys.stderr)
        for jac, (c1, s1), (c2, s2) in hits[:8]:
            where = "同章" if c1 == c2 else "跨章"
            print(f"  [{jac:.2f} {where}] {c1} / {c2}", file=sys.stderr)
            print(f"    A: {s1[:60]}", file=sys.stderr)
            print(f"    B: {s2[:60]}", file=sys.stderr)
        print(
            "\n  改法是指针加增量：指向讲得最完整的那一处，"
            "只写这一章需要的那一层。\n"
            "  确实该重复的，加进 checks/redundancy.py 的 ALLOW 并写明理由。",
            file=sys.stderr,
        )
        return 1

    print("✓ 车轱辘话: 跨章重述在阈值内")
    return 0


if __name__ == "__main__":
    sys.exit(main())
