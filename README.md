# 让不确定的 Agent 产出确定性的结果

一本讲怎么给 Agent 建判定边界的书。目标 15 万字，约 300 页。

## 快速开始

```bash
brew install quarto typst
cargo install autocorrect --locked
pip install pyyaml

make preview      # 本机实时预览 → http://localhost:4200
make serve        # 局域网实时预览（手机也能看），会打印局域网地址
make check        # 全部判定（= CI 跑的东西）
make wordcount    # 字数进度对照预算
```

`make serve` 绑的是 `0.0.0.0`，同网段的设备都能访问。
换端口：`make serve PORT=8080`。

## 这个仓库怎么组织

| 路径 | 是什么 |
|---|---|
| `_quarto.yml` | 章节顺序的唯一事实源 |
| `budget.yml` | 每章字数预算，上下界都是判定条件 |
| `terms.yml` | 术语的唯一写法 |
| `chapters/` | 一章一文件 |
| `checks/` | 判定脚本（预算 · 交叉引用 · 术语 · 承诺） |
| `research/` | 研究件，不进书。`shapes.md` 是全书骨架 |
| `includes/` | Typst 中文排版模板 |
| `CLAUDE.md` | 写作 Agent 的常驻指导 |

## 判定

这本书用它自己讲的那套方法写。

| 检查 | 挡住什么 | 对应书里的 |
|---|---|---|
| `check-claims` | 一章没有可证伪的承诺 | 变异验证（@sec-tests） |
| `check-budget` | 某章烂尾或膨胀 | 文件健康度（@sec-modularity） |
| `check-terms` | 同一概念多种写法 | 单一 owner（@sec-shape-b） |
| `check-xref` | 引用指向不存在的锚点 | 生成物漂移检测 |
| `check-typography` | 中英混排、全半角标点 | 结构检查 lane |
| 退出码 2 | 工具没装 → 不报成「你写错了」 | 传感器故障判别（@sec-sensor-faults） |

`checks/budget.py` 里有一个专门的修复值得一提：HTML 注释不计入字数。
不这么做的话，一章写满 TODO 也会显示成「已完成」—— 那正是本书讲的假绿。

## 进度

```bash
make wordcount
```

**全书完成：150,879 字 / 26 章，全部章节落在预算区间内。**

| 判定 | 状态 |
|---|---|
| 章节承诺 | ✓ 26 章全部声明了可证伪的 claim |
| 字数预算 | ✓ 26 章全部在 ±20% 区间内 |
| 术语一致性 | ✓ 10 组术语，无冲突 |
| 交叉引用 | ✓ 647 处引用 / 703 个锚点，全部有效 |
| 核心概念 | ✓ 13 个，首次出现时全部带指向定义的指针 |
| 口吻 | ✓ 12 条规则，无第三人称自指与答辩腔 |

另有两道不进 `make check` 的（它们需要构建产物或运行中的服务）：

| 命令 | 查什么 |
|---|---|
| `make check-numbering` | 章号与页内小节号一致、章号连续、**交叉引用在产物里真的解析了** |
| `make check-serve` | 逐页看内容，**不看状态码** —— 空的 render error 页会返回 HTTP 200 |

## 素材来源

**一手材料是代码**，不是事故记录，也不是 markdown 文档。
见 `research/code-map.md` —— 它给每一章指定了必读源码，
并写了读代码的纪律。

书里几处最硬的证据都直接来自实现：

- `exit_code()` 的匹配臂顺序（基建故障排在策略违规**前面**）
- `sentinel_min` 是 `required_nonzero`（必填且类型上不能为零）
- 禁止 fallback 的分析器有五层过滤，含**绑定跟踪**
- `--unified=0` 让"只扫新增行"是字面成立的
- `is_policy_path` 三行解决"规则咬到自己"
- 配置的 `raw` / `validated` 可见性分层
- `FingerprintMultiset` 用多重集而非集合

## 这本书自己被它讲的方法检查着

写作过程中，这套检查抓到过四次真问题：

1. **字数统计把 HTML 注释算进去了** —— 一章写满 TODO 也显示"已完成"，
   正是书里讲的假绿
2. **字数口径排除了表格** —— 而这本书的表格是内容不是格式
3. **术语规则在术语表里误报** —— 那里是在*讨论*译法，不是在用；
   加了区段豁免，对应源系统的 `source_view = code_only`
4. **交叉引用抓到第 7 章漏写了一整节**（依赖图）
5. **一次结构审查**发现 13 个核心概念里有 10 个首次出现时没给指针，
   而术语表零引用 —— 都补了，并加了 `check-concepts` 防止复发
