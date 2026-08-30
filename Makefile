# 书的构建与判定入口。本地与 CI 跑同一条命令、同一份配置。
# 退出码语义与 AIO guardrails 一致：
#   0 = 通过    1 = 内容违规（改稿）    2 = 基建故障（改环境，改稿没有意义）

SHELL := /bin/bash
CHAPTERS := $(shell find chapters -name '*.qmd' 2>/dev/null)

.PHONY: help
help:
	@echo "make html       构建网页版"
	@echo "make pdf        构建 PDF（Typst）"
	@echo "make preview    实时预览"
	@echo "make check      全部判定（= CI 跑的东西）"
	@echo "make fix        自动修可修的（中文排版）"
	@echo "make wordcount  字数进度对照预算"

# ---------- 构建 ----------

.PHONY: html pdf preview
html: tools
	quarto render --to html

pdf: tools
	quarto render --to typst

preview: tools
	quarto preview

# ---------- 判定 ----------

.PHONY: check
check: check-tools check-typography check-xref check-budget check-terms check-claims
	@echo "✓ 全部判定通过"

# 基建自检：工具缺失是 exit 2，不是"你写错了"
.PHONY: tools check-tools
tools check-tools:
	@command -v quarto      >/dev/null || { echo "guard: quarto 未安装"; exit 2; }
	@command -v autocorrect  >/dev/null || { echo "guard: autocorrect 未安装"; exit 2; }
	@command -v python3      >/dev/null || { echo "guard: python3 未安装"; exit 2; }

# 中文排版：中英混排空格、全半角标点
.PHONY: check-typography fix
check-typography:
	@autocorrect --lint chapters/ index.qmd || exit 1

fix:
	@autocorrect --fix chapters/ index.qmd

# 交叉引用有效性：@sec-/@fig-/@tbl- 指向的目标必须存在
.PHONY: check-xref
check-xref:
	@python3 checks/xref.py

# 每章字数必须落在预算区间内（防止某章悄悄膨胀或烂尾）
.PHONY: check-budget wordcount
check-budget:
	@python3 checks/budget.py --enforce

wordcount:
	@python3 checks/budget.py

# 术语一致性：同一个概念全书只能有一种写法
.PHONY: check-terms
check-terms:
	@python3 checks/terms.py

# 每章必须声明它的可验证承诺，且承诺不能为空
.PHONY: check-claims
check-claims:
	@python3 checks/claims.py

.PHONY: clean
clean:
	rm -rf _output .quarto
