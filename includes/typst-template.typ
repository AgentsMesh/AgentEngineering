// 中文排版模板。
// 三件事必须显式设，否则 CJK 会出问题：
//   1. lang/region —— 不设的话行首标点不会挤压
//   2. 字体回退链 —— 缺字时不能悄悄换成方框
//   3. 中英文之间的间距 —— Typst 的 CJK 处理需要显式启用

#let book(
  title: none,
  subtitle: none,
  author: none,
  body,
) = {
  set document(title: title, author: author)

  set text(
    lang: "zh",
    region: "cn",
    font: ("Source Han Serif SC", "Noto Serif CJK SC", "Songti SC"),
    size: 10pt,
  )

  set par(justify: true, first-line-indent: 2em, leading: 0.85em)

  show heading: set text(font: ("Source Han Sans SC", "Noto Sans CJK SC"))
  show heading: it => { set par(first-line-indent: 0em); it }

  // 代码块用等宽中英对齐的字体，否则含中文注释的代码会歪
  show raw: set text(font: ("Sarasa Mono SC", "Menlo"), size: 8.5pt)

  set page(
    paper: "a5",
    margin: (top: 2cm, bottom: 2cm, inside: 2.2cm, outside: 1.8cm),
    numbering: "1",
  )

  body
}
