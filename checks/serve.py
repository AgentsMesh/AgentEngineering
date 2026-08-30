#!/usr/bin/env python3
"""预览服务的健康检查。

这条检查存在的理由是一次真实的教训：quarto preview 会缓存一个
**空的** render error —— 页面返回 HTTP 200，标题是 "Quarto Render Error"，
body 是空的，而磁盘上的产物完全正常。

也就是说：
  - HTTP 状态码说通过（200）
  - 服务日志里没有任何错误
  - 而用户看到一片空白

这是形状 A：探针（HTTP 200）测的不是你以为的东西。
所以不能只看状态码，必须看内容。

用法：make check-serve  （服务没起时报 exit 2，不是 exit 1）
"""
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PORT = 4200
SENTINEL_MIN = 20          # 至少抽查这么多页，否则判定自己坏了
MIN_BYTES = 3000           # 一页正文不可能小于这个数


def pages() -> list[str]:
    out = ["/"]
    for qmd in sorted(ROOT.glob("chapters/**/*.qmd")):
        out.append("/" + str(qmd.relative_to(ROOT)).replace(".qmd", ".html"))
    return out


def main() -> int:
    urls = pages()
    if len(urls) < SENTINEL_MIN:
        print(f"guard: 只找到 {len(urls)} 页 —— 文件布局变了？", file=sys.stderr)
        return 2

    base = f"http://127.0.0.1:{PORT}"
    try:
        urllib.request.urlopen(base, timeout=5).read()
    except (urllib.error.URLError, OSError) as exc:
        print(f"guard: 预览服务没起来（{exc}）—— 先跑 make serve", file=sys.stderr)
        return 2

    broken, thin = [], []
    for path in urls:
        try:
            body = urllib.request.urlopen(base + path, timeout=15).read()
        except (urllib.error.URLError, OSError) as exc:
            broken.append((path, f"取不到: {exc}"))
            continue
        # HTTP 200 不等于渲染成功 —— 必须看内容
        if b"Quarto Render Error" in body:
            broken.append((path, "空的 render error（磁盘产物可能是好的，重启预览）"))
        elif len(body) < MIN_BYTES:
            thin.append((path, len(body)))

    if broken:
        print(f"guard: {len(broken)} 页渲染失败", file=sys.stderr)
        for path, why in broken[:15]:
            print(f"  {path}  {why}", file=sys.stderr)
        return 1

    if thin:
        print(f"guard: {len(thin)} 页内容异常少（< {MIN_BYTES}B）", file=sys.stderr)
        for path, size in thin[:15]:
            print(f"  {path}  {size}B", file=sys.stderr)
        return 1

    print(f"✓ 预览服务: {len(urls)} 页全部渲染正常（最小 {MIN_BYTES}B）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
