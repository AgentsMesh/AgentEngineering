#!/usr/bin/env python3
"""PDF 渲染的前置条件检查。

为什么需要它：quarto 在渲染 PDF 时要把 mermaid 图转成图片，
而它的做法是拉起一个 headless Chrome 并连到**固定端口 9222**。
如果这台机器上已经有别的进程占着 9222，quarto 会连上那个进程、
发出它不认识的协议消息，然后**无限等待一个永远不会来的回复** ——
不报错、不超时、CPU 占用为零。

这不是假想。写这本书的机器上，有一个自家产品的调试端口正好也是 9222，
于是一次 PDF 渲染卡在第 2 章卡了几个小时，
而日志的最后一行是"[ 2/26] 正在渲染"—— 看起来完全正常。

它符合书里两个形状：形状 B（同一个资源有两个占用者）
和形状 A（探针 —— 这里是"渲染有没有在进行"—— 测的不是你以为的东西，
因为"进程还在"不等于"它在干活"）。

所以这条检查做的事很简单：**在开始渲染之前，看一眼 9222 上是谁。**
是别人 → 退出码 2（基建故障，改稿没有意义），并说清楚是谁占着。
没人占 → 通过。

退出码遵循全书的三态约定：0 通过 / 1 内容违规 / 2 基建故障。
这条检查不可能产生"内容违规"，所以它只会返回 0 或 2。
"""
import re
import subprocess
import sys

PORT = 9222

# quarto 自己拉起的那个 Chrome 长这样。它出现在 9222 上是正常的
# （上一次渲染没退干净），不该被当成冲突。
QUARTO_CHROME = re.compile(r"--headless\b.*--remote-debugging-port=9222")


def listeners(port: int) -> list[tuple[str, str]]:
    """返回 [(pid, 进程名)]，按 pid 去重。lsof 不可用时返回空列表。"""
    try:
        out = subprocess.run(
            ["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN"],
            capture_output=True,
            text=True,
            timeout=15,
        ).stdout
    except (OSError, subprocess.SubprocessError):
        return []

    found: dict[str, str] = {}
    for line in out.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2:
            found.setdefault(parts[1], parts[0])
    return sorted(found.items())


def cmdline(pid: str) -> str:
    try:
        return subprocess.run(
            ["ps", "-o", "args=", "-p", pid],
            capture_output=True,
            text=True,
            timeout=10,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def main() -> int:
    holders = listeners(PORT)
    if not holders:
        print(f"✓ PDF 前置条件: 端口 {PORT} 空闲，mermaid 转图可以拉起浏览器")
        return 0

    foreign = [(pid, name) for pid, name in holders if not QUARTO_CHROME.search(cmdline(pid))]
    if not foreign:
        print(f"✓ PDF 前置条件: 端口 {PORT} 上只有上次渲染残留的 headless Chrome，quarto 会复用或重启它")
        return 0

    print(
        f"guard: 端口 {PORT} 被别的进程占着，PDF 渲染会静默卡死",
        file=sys.stderr,
    )
    for pid, name in foreign:
        print(f"  {name}（pid {pid}）", file=sys.stderr)
        args = cmdline(pid)
        if args:
            print(f"    {args[:120]}", file=sys.stderr)
    print(
        "\n  quarto 把 mermaid 转成图片时要连 127.0.0.1:9222 上的 headless Chrome。\n"
        "  端口被占的时候它连上的是那个进程，然后无限等待 —— 不报错，CPU 为零。\n"
        "  停掉上面那个进程再跑，或者用 `make html-only` 先出网页版。",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main())
