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

根因是可复现的，不是「预览放久了会坏」：
**在 quarto preview 活着的时候跑一次整书 render，就会把它服务的文件
从底下抽掉。** quarto render 在开始时清空 output-dir，而 preview
持有的是清空前那一份的状态，于是 26 页全部返回空的 render error。
第一次撞上时它已经这样服务了将近十五个小时，没有任何东西说过一句话。

还有第二个坑，它让第一个坑更难被修掉：`pkill -f "quarto preview"`
一个进程都匹配不到 —— 真实的命令行是 `deno … quarto.js preview`。
它的坏处不是没杀掉，是**你以为杀掉了**：接着起的新进程会因为
端口被占直接退出，那行 ERROR 滚过日志没人看，而旧进程继续服务坏产物。
于是「重启一下」这个动作本身变成了一次静默失败，
排查的人会以为问题出在别处（缓存、字体、渲染器），一路查下去。

所以修法有三条，都做了：渲染目标发现有预览在跑就提醒
（Makefile 的 warn-preview），make preview/serve 起来之后自动跑一遍
这条检查，以及 make stop-preview 按**端口**而不是进程名去停。

第二次之后加的不是一条更聪明的检查，是让这条检查跑不掉：
`make preview` 现在会在服务起来之后自动跑一遍它（见 Makefile）。
试过一个「预览进程比源文件老」的启发式，废掉了 ——
preview 本来就会监听文件改动并重渲染，所以那个条件对健康的预览
也永远成立，是一台误报机器。而误报的规则会被绕过（@sec-bypass）。
能测效果就不要去猜状态。

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
