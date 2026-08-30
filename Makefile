# 书的构建与判定入口。本地与 CI 跑同一条命令、同一份配置。
# 退出码语义与 AIO guardrails 一致：
#   0 = 通过    1 = 内容违规（改稿）    2 = 基建故障（改环境，改稿没有意义）

SHELL := /bin/bash
CHAPTERS := $(shell find chapters -name '*.qmd' 2>/dev/null)

.PHONY: help
help:
	@echo "make html       构建网页版"
	@echo "make pdf        构建 PDF（Typst）"
	@echo "make build-all  两种格式都构建（CI 跑这个）"
	@echo "make preview    本机实时预览（localhost）"
	@echo "make serve      局域网实时预览（手机也能看）"
	@echo "make check      全部判定（= CI 跑的东西）"
	@echo "make fix        自动修可修的（中文排版）"
	@echo "make check-numbering 章节编号一致性（需要先 make html）"
	@echo "make check-serve 逐页验证预览服务（需要 make serve 正在跑）"
	@echo "make wordcount  字数进度对照预算"

# ---------- 构建 ----------

# 预览端口。改这个值可以同时开多个预览。
PORT ?= 4200

.PHONY: html pdf preview serve
html: tool-quarto
	quarto render --to html

pdf: tool-quarto
	quarto render --to typst

# 两种格式都构建 —— CI 跑这个，因为 preview 只看 HTML，
# 而 PDF 那一侧的错误必须有地方能发现。
.PHONY: build-all
build-all: tool-quarto
	quarto render

# 本机预览：只绑 127.0.0.1，自动开浏览器，改文件自动重渲染。
# ⚠️ 显式 --to html：quarto preview 默认渲染全部格式，
# 于是 PDF 那一侧的任何错误（缺一个 Typst 函数就够了）
# 会让整个预览显示一个空白的 render error —— 而 HTML 本身是好的。
# 一次判定失败不该污染另一次判定。
preview: tool-quarto
	quarto preview --to html --port $(PORT)

# 局域网预览：绑全部网卡，同一个 Wi-Fi 下的手机/平板/别的机器都能看
# 注意这会把这本书暴露给同网段的所有设备。
serve: tool-quarto
	@ip=$$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1); \
	echo "局域网地址: http://$$ip:$(PORT)"; \
	quarto preview --to html --host 0.0.0.0 --port $(PORT) --no-browser

# ---------- 判定 ----------

.PHONY: check
check: check-typography check-xref check-budget check-terms check-claims check-concepts check-voice
	@echo "✓ 全部判定通过"

# 基建自检：工具缺失是 exit 2，不是"你写错了"。
# 按需要检查 —— 预览不需要 autocorrect，判定才需要。
# 一个过度要求的前置检查，会在环境没问题的时候报环境问题。
.PHONY: tools tool-quarto tool-autocorrect tool-python
tools: tool-quarto tool-autocorrect tool-python

tool-quarto:
	@command -v quarto      >/dev/null || { echo "guard: quarto 未安装（brew install --cask quarto）"; exit 2; }

tool-autocorrect:
	@command -v autocorrect >/dev/null || { echo "guard: autocorrect 未安装（cargo install autocorrect-cli）"; exit 2; }

tool-python:
	@command -v python3     >/dev/null || { echo "guard: python3 未安装"; exit 2; }

# 中文排版：中英混排空格、全半角标点
.PHONY: check-typography fix
check-typography: tool-autocorrect tool-python
	@python3 checks/typography.py

fix:
	@autocorrect --fix chapters/ index.qmd

# 交叉引用有效性：@sec-/@fig-/@tbl- 指向的目标必须存在
.PHONY: check-xref
check-xref: tool-python
	@python3 checks/xref.py

# 每章字数必须落在预算区间内（防止某章悄悄膨胀或烂尾）
.PHONY: check-budget wordcount
check-budget: tool-python
	@python3 checks/budget.py --enforce

wordcount:
	@python3 checks/budget.py

# 术语一致性：同一个概念全书只能有一种写法
.PHONY: check-terms
check-terms: tool-python
	@python3 checks/terms.py

# 每章必须声明它的可验证承诺，且承诺不能为空
.PHONY: check-claims
check-claims: tool-python
	@python3 checks/claims.py

# 核心概念首次出现时必须带指向定义的指针
.PHONY: check-concepts
check-concepts: tool-python
	@python3 checks/concepts.py

# 口吻：第三人称自指 + 答辩腔
.PHONY: check-voice
check-voice: tool-python
	@python3 checks/voice.py

# 章节编号一致性 —— 需要构建产物，所以不进 make check（CI 里 build 之后跑）
.PHONY: check-numbering
check-numbering: tool-python
	@python3 checks/numbering.py

# 预览服务的健康检查 —— 逐页看内容，不看状态码。
# 不进 `make check`：它需要服务正在跑，而 CI 里没有。
# 服务没起时返回 exit 2（判不了），不是 exit 1（你写错了）。
.PHONY: check-serve
check-serve: tool-python
	@python3 checks/serve.py

.PHONY: clean
clean:
	rm -rf _output .quarto
