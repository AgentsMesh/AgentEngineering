# 让不确定的 Agent 产出确定性的结果

一本讲怎么给 Agent 建判定边界的书。目标 15 万字，约 300 页。

## 快速开始

```bash
brew install quarto typst
cargo install autocorrect --locked
pip install pyyaml

make preview      # 实时预览
make check        # 全部判定（= CI 跑的东西）
make wordcount    # 字数进度对照预算
```

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

当前：骨架已全部种下（26 章，全部声明了 claim），正文约 4%。
