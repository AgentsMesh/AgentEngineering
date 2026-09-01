// 中文书籍排版模板。
//
// 三件事必须显式设，否则 CJK 会出问题：
//   1. lang/region —— 不设的话行首标点不会挤压
//   2. 字体回退链 —— 缺字时不能悄悄换成方框
//   3. 等宽字体要中英同宽 —— 否则含中文注释的代码块会歪
//
// ⚠️ part 和 callout 是必须定义的：Quarto 的 book 格式会发射
// #part[...] 和 #callout(...)，模板里没有就是 "unknown variable"，
// 而这个错误会让整个预览（包括 HTML）显示一个空白的 render error。

#let part(body) = {
  pagebreak(weak: true)
  v(30%)
  align(center)[
    #text(size: 22pt, weight: "bold",
          font: ("Source Han Sans SC", "Noto Sans CJK SC", "PingFang SC", "Heiti SC"))[#body]
  ]
  pagebreak(weak: true)
}

// Quarto 的 book 格式用 `#show: appendices.with("附录", ...)` 切换到附录编号。
// 它是一个 show rule 的构造器：接一个标题和选项，返回一个作用于文档剩余部分的函数。
#let appendices(title, hide-parent: false, body) = {
  pagebreak(weak: true)
  if not hide-parent {
    v(30%)
    align(center)[
      #text(size: 22pt, weight: "bold",
            font: ("Source Han Sans SC", "Noto Sans CJK SC", "PingFang SC", "Heiti SC"))[#title]
    ]
    pagebreak(weak: true)
  }
  // 附录用字母编号：附录 A、附录 B……
  set heading(numbering: "A.1.1")
  counter(heading).update(0)
  body
}

#let callout(body: [], title: "提示", background_color: rgb("#f5f5f5"),
             icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false,
    fill: background_color,
    stroke: (left: 3pt + rgb("#4a4a4a")),
    radius: 2pt,
    inset: 10pt,
    width: 100%,
  )[
    #text(weight: "bold", size: 9.5pt)[#title]
    #v(3pt)
    #body
  ]
}

#let book(
  title: none,
  subtitle: none,
  author: none,
  date: none,
  body,
) = {
  // ⚠️ Quarto 传进来的 title/author 是 content（`[...]`），不是 string，
  // 而 `set document` 只吃 string/array —— 直接传会报
  // "expected string or array, found content"。所以这里不设 document 元数据；
  // PDF 的标题栏留空不影响阅读，而强行转换会在 title 含行内标记时再次炸掉。

  set text(
    lang: "zh",
    region: "cn",
    font: ("Source Han Serif SC", "Noto Serif CJK SC", "Songti SC"),
    size: 10pt,
  )

  set par(justify: true, first-line-indent: 2em, leading: 0.85em)

  // ⚠️ 必须给标题设编号：书里有 647 处 @sec- 交叉引用，
  // 而 Typst 里引用一个没有编号的标题会报
  // "cannot reference heading without numbering"。
  set heading(numbering: "1.1.1")

  show heading: set text(font: ("Source Han Sans SC", "Noto Sans CJK SC", "PingFang SC", "Heiti SC"))
  show heading: it => { set par(first-line-indent: 0em); it }

  // 代码块用中英等宽的字体，否则含中文注释的代码会歪
  show raw: set text(font: ("Sarasa Mono SC", "Menlo"), size: 8.5pt)

  set page(
    paper: "a5",
    margin: (top: 2cm, bottom: 2cm, inside: 2.2cm, outside: 1.8cm),
    numbering: "1",
  )

  // 封面
  if title != none {
    v(30%)
    align(center)[
      #text(size: 24pt, weight: "bold",
            font: ("Source Han Sans SC", "Noto Sans CJK SC", "PingFang SC", "Heiti SC"))[#title]
      #if subtitle != none [ #v(10pt) #text(size: 12pt)[#subtitle] ]
      #if author != none [ #v(30pt) #text(size: 11pt)[#author] ]
    ]
    pagebreak()
  }

  body
}
