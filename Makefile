# 书的构建与判定入口。本地与 CI 跑同一条命令、同一份配置。
# 退出码语义与 AIO guardrails 一致：
#   0 = 通过    1 = 内容违规（改稿）    2 = 基建故障（改环境，改稿没有意义）

SHELL := /bin/bash
CHAPTERS := $(shell find chapters -name '*.qmd' 2>/dev/null)

.PHONY: help
help:
	@echo "make html       构建全书（网页 + PDF，互不覆盖）"
	@echo "make pdf        同上 —— 两个目标现在是一回事，见 Makefile 里的说明"
	@echo "make build-all  两种格式都构建（CI 跑这个）"
	@echo "make preview    本机实时预览（localhost）"
	@echo "make serve      局域网实时预览（手机也能看）"
	@echo "make check      全部判定（= CI 跑的东西）"
	@echo "make fix        自动修可修的（中文排版）"
	@echo "make check-prose 行文形态（只报数，不拦）"
	@echo "make check-tics  口头禅与加粗占比（已在 make check 里）"
	@echo "make check-numbering 章节编号一致性（需要先 make html）"
	@echo "make check-serve 逐页验证预览服务（需要 make serve 正在跑）"
	@echo "make check-pdf-preflight  渲染 PDF 前的端口检查"
	@echo "make stop-preview  停掉占着预览端口的进程"
	@echo "make wordcount  字数进度对照预算"
	@echo "make html-only  只渲染网页 —— 会删掉 PDF 产物"
	@echo "make pdf-only   只渲染 PDF —— 会删掉网页产物，serve 会 404"

# ---------- 构建 ----------

# 预览端口。改这个值可以同时开多个预览。
PORT ?= 4200

# ⚠️ quarto 在每次 render 开始时会清空 output-dir，而两种格式共用 _output。
# 所以 `quarto render --to typst` 会先把 HTML 产物全删掉，再产出 PDF ——
# 正在跑的 `make serve` 于是开始 404，而没有任何东西报错。
# 这是形状 D 的一个实例：一个动作的副作用发生在它声明的范围之外。
# 修法不是写一行注释提醒，是让单格式渲染不再是默认路径：
# html 和 pdf 都渲染全部格式，代价是慢一点，换来的是没有一次渲染会毁掉另一半。
# 真的只想要一种格式时用 html-only / pdf-only，它们的名字里写着后果。
.PHONY: html pdf html-only pdf-only preview serve check-pdf-preflight
html: build-all
pdf: build-all

# 渲染 PDF 之前先看一眼 9222 端口 —— 被占的话 quarto 会静默卡死。
# 详见 checks/pdf_preflight.py 开头的说明。
check-pdf-preflight: tool-python
	@python3 checks/pdf_preflight.py

html-only: tool-quarto warn-preview
	@echo "⚠️  这会删掉 _output 里已有的 PDF 产物"
	quarto render --to html

pdf-only: tool-quarto check-pdf-preflight warn-preview
	@echo "⚠️  这会删掉 _output 里已有的 HTML 产物"
	quarto render --to typst

# 两种格式都构建 —— CI 跑这个，因为 preview 只看 HTML，
# 而 PDF 那一侧的错误必须有地方能发现。
# 整书渲染会清空 _output/，而正在跑的 preview 持有清空前那一份的状态 ——
# 渲染完它会 26 页全部返回空的 render error，且不报任何错。
# 这里不去杀掉别人的进程，只保证这件事不再是静默的。
.PHONY: warn-preview
warn-preview:
	@if lsof -nP -iTCP:$(PORT) -sTCP:LISTEN >/dev/null 2>&1; then \
	  echo "⚠️  端口 $(PORT) 上有预览在跑 —— 这次渲染会让它开始服务空的 error 页。"; \
	  echo "   渲染完记得重启预览（或者渲染完跑一次 make check-serve 确认）。"; \
	fi

.PHONY: build-all
build-all: tool-quarto check-pdf-preflight warn-preview
	quarto render

# 本机预览：只绑 127.0.0.1，自动开浏览器，改文件自动重渲染。
# ⚠️ 显式 --to html：quarto preview 默认渲染全部格式，
# 于是 PDF 那一侧的任何错误（缺一个 Typst 函数就够了）
# 会让整个预览显示一个空白的 render error —— 而 HTML 本身是好的。
# 一次判定失败不该污染另一次判定。
# 停掉占着预览端口的进程。必须按端口找，不能 pkill 进程名 ——
# quarto preview 的真实命令行是 `deno … quarto.js preview`，
# `pkill -f "quarto preview"` 一个都匹配不到。
# 它的坏处不是没杀掉，是**你以为杀掉了**：
# 接着起的新进程会因为端口被占直接退出，那行 ERROR 滚过日志没人看见，
# 而旧进程继续服务它那份坏掉的产物。这个静默失败曾经让人白折腾半小时。
.PHONY: stop-preview
stop-preview:
	@pid=$$(lsof -nP -iTCP:$(PORT) -sTCP:LISTEN -t 2>/dev/null | head -1); \
	if [ -n "$$pid" ]; then \
	  echo "停掉 $(PORT) 上的进程 $$pid"; kill $$pid; \
	  n=0; while lsof -nP -iTCP:$(PORT) -sTCP:LISTEN -t >/dev/null 2>&1; do \
	    n=$$((n+1)); [ $$n -gt 15 ] && break; sleep 1; done; \
	fi

# 起预览，等它就绪，自动验一遍 26 页，然后把预览留在前台。
# 不自动验的话，一个陈掉的预览可以静默地服务十几个小时的空 error 页
# —— 那次的磁盘产物一直是好的，坏的只有预览进程自己的状态。
preview: tool-quarto stop-preview
	@quarto preview --to html --port $(PORT) --no-browser & \
	 pid=$$!; \
	 n=0; until curl -s http://127.0.0.1:$(PORT)/ 2>/dev/null | head -c 3000 | grep -q .; do \
	   n=$$((n+1)); [ $$n -gt 90 ] && break; sleep 2; done; \
	 python3 checks/serve.py || echo "⚠️  预览起来了但页面不对 —— 上面有明细"; \
	 echo "预览在 http://127.0.0.1:$(PORT)/  （Ctrl-C 停）"; \
	 wait $$pid

# 局域网预览：绑全部网卡，同一个 Wi-Fi 下的手机/平板/别的机器都能看
# 注意这会把这本书暴露给同网段的所有设备。
serve: tool-quarto stop-preview
	@ip=$$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1); \
	echo "局域网地址: http://$$ip:$(PORT)"; \
	quarto preview --to html --host 0.0.0.0 --port $(PORT) --no-browser & \
	pid=$$!; \
	n=0; until curl -s http://127.0.0.1:$(PORT)/ 2>/dev/null | head -c 3000 | grep -q .; do \
	  n=$$((n+1)); [ $$n -gt 90 ] && break; sleep 2; done; \
	python3 checks/serve.py || echo "⚠️  预览起来了但页面不对 —— 上面有明细"; \
	wait $$pid

# ---------- 判定 ----------

.PHONY: check
check: check-typography check-xref check-budget check-terms check-claims check-concepts check-voice check-prose-strict check-tics
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

# 行文形态：段落成型、加粗密度。
# 2026-08 起切成拦截：26 章全部通过，存量已清零。
# 这正是正文 @sec-four-steps 讲的那个上线流程 —— 先报数、清存量、再切拦截，
# 而"零违规的报数规则应该被切成拦截"是 @sec-rule-worth 的直接应用：
# 此刻切的成本接近零（不会误报，因为没有违规），而它从此提供保护。
# check-prose 保留为只报数的版本，用来看趋势。
.PHONY: check-prose check-prose-strict
check-prose: tool-python
	@python3 checks/prose.py

check-prose-strict: tool-python
	@python3 checks/prose.py --strict

# 口头禅与结构套路（俗称「AI 味」）。阈值拿源分享稿当对照组量出来。
# 2026-08 起切成拦截：存量已清（句首「而」454 → 35 句，加粗占比 18.0% → 7.3%）。
# 和 check-prose 走的是同一条路：先报数、清存量、再切拦截。
.PHONY: check-tics
check-tics: tool-python
	@python3 checks/tics.py

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
