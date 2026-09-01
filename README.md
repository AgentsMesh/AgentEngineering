# 让不确定的 Agent 产出确定性的结果

**用确定性的基建，把不确定的 Agent 包围起来。**

📖 **[在线阅读 → agentsmesh.github.io/AgentEngineering](https://agentsmesh.github.io/AgentEngineering/)**

---

几十个 Agent 在一个三百多万行、二十六个客户端产品的仓库里并行改代码，
单日峰值合入五十二次，没有人逐行看过 diff。

这件事能成立，靠的不是 Agent 变可靠了 —— 它每次给出的代码都不一样，
你也没法要求它一样。靠的是换一个承诺：

> **不承诺同样的代码，只承诺同样的判定边界。**

十八万字讲的就是这条边界怎么建、怎么让它自己不腐化，
以及它在哪里按定义就够不着。

## 这本书讲什么

| 部 | 内容 |
|---|---|
| **一 · 问题** | 两堵墙、不确定性住在哪、承诺什么、**七个失败形状**（全书骨架） |
| **二 · 环境** | 代码放哪、依赖怎么流、规则住哪个载体、工具链让 Agent 的手伸到哪 |
| **三 · 判定** | 测试看运行时的事实、结构检查看结构的事实、路径不变量看路径背后的约定 |
| **四 · 回路** | 用控制论重述前三部：增益与延迟、传感器故障、观测器、设定点在环外 |

每一部最后有一节 **「小规模怎么做」**，每一条都能在一周内、用现有工具链落地。

素材来自一个用 Bazel 的单体仓库，但大部分内容不依赖 Bazel，也不依赖单体仓库 ——
真正需要重基建的只有讲依赖图那一节，它被单独标了出来。

## 这本书自己也被同一套东西管着

书里讲的方法，这个仓库对自己用了一遍。`make check` 跑九道判定，每一道都会失败：

| 判定 | 查什么 |
|---|---|
| `typography` | 中文排版（autocorrect） |
| `xref` | 交叉引用有效 + 锚点不重复 |
| `budget` | 每章字数在预算区间内 |
| `terms` | 术语只有一种写法 |
| `claims` | 每章声明了一条可证伪的承诺 |
| `concepts` | 核心概念首次出现时带指向定义的指针 |
| `voice` | 口吻：无第三人称自指、答辩腔、给书打日期的时间词 |
| `prose` | 段落形态：单句段占比、平均句数 |
| `tics` | 口头禅与加粗占比（阈值以人写的对照稿校准） |
| `redundancy` | 车轱辘话：同一论断被完整重述 |

每一道都带哨兵下限 —— 扫到的文件或句子少于下限就报**基建故障**（退出码 2），
而不是报通过。退出码遵循书里那条三态约定：`0` 通过 / `1` 内容违规 / `2` 判不了。

这些检查抓到过的都是我自己引入的：四十三处第三人称自指、两处重复的小节锚点、
一处把提交数少算了一半的统计、四十五对跨章重述。
其中两次写进了正文，因为它们是这套方法最好的自证 ——
不是"我做到了"，是"我没做到，而机制抓住了我"。

## 本地跑

```bash
brew install --cask quarto
cargo install autocorrect --locked   # 中文排版，可选
pip install pyyaml

make preview      # 本机预览 → http://localhost:4200（起来后自动验 26 页）
make serve        # 局域网预览，手机也能看
make check        # 九道判定
make wordcount    # 字数进度对照预算
```

### 出 PDF

```bash
brew install --cask font-source-han-serif font-source-han-sans
make pdf          # 渲染前会先查 9222 端口，被占会直接报基建故障
```

PDF 走 Typst。渲染时 Quarto 要把 mermaid 图转成图片，
做法是拉起 headless Chrome 并连**固定端口 9222** ——
端口被别的进程占着的话它会静默卡死，所以 `make pdf` 前面挂了一道前置检查
（`checks/pdf_preflight.py`，起因见文件开头）。

⚠️ 整书渲染会清空 `_output/`，正在跑的预览会开始服务空的 error 页。
`make preview` / `make serve` 会先 `stop-preview`（按端口停，不按进程名 ——
`pkill -f "quarto preview"` 一个都匹配不到）。

## 仓库怎么组织

| 路径 | 是什么 |
|---|---|
| `_quarto.yml` | 章节顺序的唯一事实源 |
| `index.qmd` · `chapters/` | 一章一文件 |
| `budget.yml` · `terms.yml` · `concepts.yml` · `voice.yml` | 各条判定的策略，与机制分开 |
| `checks/` | 判定脚本，每个文件开头写清楚它为什么存在、踩过什么坑 |
| `research/` | 研究件，不进书 |
| `includes/` | Typst 模板 |
| `CLAUDE.md` | 写作纪律，只放必须无条件生效的 |

`research/ai-flavor-measurement.md` 记的是量「AI 味」的六个方法坑，
其中两个让我给出过错误的结论 —— 留着是因为方法上的坑比结论活得久。

## 许可

内容与代码的授权尚未确定，暂按 all rights reserved。
需要引用或转载请开 issue。

---

作者：yishuiliunian · <yishuiliunian@gmail.com>
