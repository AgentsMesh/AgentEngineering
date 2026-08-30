// Chapter-based numbering for books with appendix support
#let equation-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "(A.1)" } else { "(1.1)" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let callout-numbering = it => {
  let pattern = if state("appendix-state", none).get() != none { "A.1" } else { "1.1" }
  numbering(pattern, counter(heading).get().first(), it)
}
#let subfloat-numbering(n-super, subfloat-idx) = {
  let chapter = counter(heading).get().first()
  let pattern = if state("appendix-state", none).get() != none { "A.1a" } else { "1.1a" }
  numbering(pattern, chapter, n-super, subfloat-idx)
}
// Theorem configuration for theorion
// Chapter-based numbering (H1 = chapters)
#let theorem-inherited-levels = 1

// Appendix-aware theorem numbering
#let theorem-numbering(loc) = {
  if state("appendix-state", none).at(loc) != none { "A.1" } else { "1.1" }
}

// Theorem render function
// Note: brand-color is not available at this point in template processing
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  block(
    width: 100%,
    inset: (left: 1em),
    stroke: (left: 2pt + black),
  )[
    #if full-title != "" and full-title != auto and full-title != none {
      strong[#full-title]
      linebreak()
    }
    #body
  ]
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms.item: it => block(breakable: false)[
  #text(weight: "bold")[#it.term]
  #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
]

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let fields = old_block.fields()
  let _ = fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  align(left, block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1)))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}


// syntax highlighting functions from skylighting:
/* Function definitions for syntax highlighting generated by skylighting: */
#let EndLine() = raw("\n")
#let Skylighting(fill: none, number: false, start: 1, sourcelines) = {
   let blocks = []
   let lnum = start - 1
   let bgcolor = rgb("#f1f3f5")
   for ln in sourcelines {
     if number {
       lnum = lnum + 1
       blocks = blocks + box(width: if start + sourcelines.len() > 999 { 30pt } else { 24pt }, text(fill: rgb("#aaaaaa"), [ #lnum ]))
     }
     blocks = blocks + ln + EndLine()
   }
   block(fill: bgcolor, width: 100%, inset: 8pt, radius: 2pt, blocks)
}
#let AlertTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let AnnotationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let AttributeTok(s) = text(fill: rgb("#657422"),raw(s))
#let BaseNTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let BuiltInTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let CharTok(s) = text(fill: rgb("#20794d"),raw(s))
#let CommentTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let CommentVarTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ConstantTok(s) = text(fill: rgb("#8f5902"),raw(s))
#let ControlFlowTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let DataTypeTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DecValTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let DocumentationTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))
#let ErrorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let ExtensionTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let FloatTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let FunctionTok(s) = text(fill: rgb("#4758ab"),raw(s))
#let ImportTok(s) = text(fill: rgb("#00769e"),raw(s))
#let InformationTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let KeywordTok(s) = text(weight: "bold",fill: rgb("#003b4f"),raw(s))
#let NormalTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let OperatorTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let OtherTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let PreprocessorTok(s) = text(fill: rgb("#ad0000"),raw(s))
#let RegionMarkerTok(s) = text(fill: rgb("#003b4f"),raw(s))
#let SpecialCharTok(s) = text(fill: rgb("#5e5e5e"),raw(s))
#let SpecialStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let StringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let VariableTok(s) = text(fill: rgb("#111111"),raw(s))
#let VerbatimStringTok(s) = text(fill: rgb("#20794d"),raw(s))
#let WarningTok(s) = text(style: "italic",fill: rgb("#5e5e5e"),raw(s))


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

#let BROKEN_part(body) = {
  pagebreak(weak: true)
  v(30%)
  align(center)[
    #text(size: 22pt, weight: "bold",
          font: ("Source Han Sans SC", "Noto Sans CJK SC"))[#body]
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
            font: ("Source Han Sans SC", "Noto Sans CJK SC"))[#title]
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

  show heading: set text(font: ("Source Han Sans SC", "Noto Sans CJK SC"))
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
            font: ("Source Han Sans SC", "Noto Sans CJK SC"))[#title]
      #if subtitle != none [ #v(10pt) #text(size: 12pt)[#subtitle] ]
      #if author != none [ #v(30pt) #text(size: 11pt)[#author] ]
    ]
    pagebreak()
  }

  body
}
#import "@preview/fontawesome:0.5.0": *
#let brand-color = (:)
#let brand-color-background = (:)
#let brand-logo = (:)

#set page(
  paper: "a5",
  margin: (bottom: 2cm,left: 2cm,right: 2cm,top: 2cm,),
  numbering: "1",
  columns: 1,
)
// Logo is handled by orange-book's cover page, not as a page background
// NOTE: marginalia.setup is called in typst-show.typ AFTER book.with()
// to ensure marginalia's margins override the book format's default margins
#show: book.with(
title: [让不确定的 Agent 产出确定性的结果],
subtitle: [用确定性的基建，把不确定的 Agent 包围起来],
author: [yishuiliunian],
)
// Reset Quarto's custom figure counters at each chapter (level-1 heading).
// Orange-book only resets kind:image and kind:table, but Quarto uses custom kinds.
// This list is generated dynamically from crossref.categories.
#show heading.where(level: 1): it => {
  counter(figure.where(kind: "quarto-float-fig")).update(0)
  counter(figure.where(kind: "quarto-float-tbl")).update(0)
  counter(figure.where(kind: "quarto-float-lst")).update(0)
  counter(figure.where(kind: "quarto-callout-Note")).update(0)
  counter(figure.where(kind: "quarto-callout-Warning")).update(0)
  counter(figure.where(kind: "quarto-callout-Caution")).update(0)
  counter(figure.where(kind: "quarto-callout-Tip")).update(0)
  counter(figure.where(kind: "quarto-callout-Important")).update(0)
  counter(math.equation).update(0)
  it
}

= 前言
<前言>
#heading(level: 1, numbering: none)[前言]
<前言-1>
这本书讲一件事：#strong[怎么让一个不确定的东西，产出可以被确认的结果。]

那个不确定的东西是 Agent。它每次给出的代码都不一样，你没法要求它一样， 也不应该要求它一样。但你可以要求另一件事 ------ #strong[每一次产出，都能用同一套证据 判断它算不算数。]

不承诺同样的代码，只承诺同样的#strong[判定边界]（#ref(<sec-same-boundary>, supplement: [第])）。 整本书都在讲这条边界怎么建。

== 这本书的来历
<这本书的来历>
它来自一个真实的仓库：三百多万行代码，二十六个客户端产品，一条发布链路， 一个人。最近半年里，几十个 Agent 在这个仓库上并行工作，单日峰值合入 五十二次，全程没有人做逐行的代码审查。

这不是一个「我们有多能干」的故事。这个数字本身没什么意思 ------ #strong[有意思的是：在没有人逐行看的情况下，凭什么敢合。]

这本书回答的就是这一个问题。

== 两个前提
<两个前提>
#strong[第一，这里讲的每一条规则，都是先出事、后立规。] 没有一条是设计出来的。 书里会反复出现同一个句式：先描述一次真实的失败，再讲那次失败留下了什么。 你会看到失败，也会看到当时错误的判断 ------ 后者比前者有用得多。

#strong[第二，作者的实践跑在他的理论前面。] 这套东西最初被解释成一套"检查"， 后来发现因果讲反了；再后来发现，它其实是一个标准的#strong[闭环控制系统]， 只是当时没有这套语言。第四部会把这层补上 ------ 那部分是这本书里唯一 不是从事故里长出来、而是从一个成熟学科里借来的内容。

== 你在哪一层，该读哪几章
<sec-navigation>
这本书的素材来自一个用 Bazel 的单体仓库。#strong[但书里大部分内容不依赖 Bazel， 也不依赖单体仓库。] 为了不让你在第七章撞上"这个我做不到"就合上， 先把地图给你：

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([你的处境], [从哪读], [需要什么前提],),
  table.hline(),
  [一个人 / 小项目], [#ref(<sec-carriers>, supplement: [章节]) · #ref(<sec-rule-lifecycle>, supplement: [章节])], [无],
  [中型团队，单产品，没有单体仓库], [#ref(<sec-carriers>, supplement: [章节]) · #ref(<sec-tests>, supplement: [章节]) · #ref(<sec-three-failures>, supplement: [章节]) · #ref(<sec-rule-lifecycle>, supplement: [章节]) · #ref(<sec-small-scale-verdict>, supplement: [章节])], [无],
  [有单体仓库 + 统一构建系统], [全书], [一张全仓依赖图（Bazel 或等价物）],
  [想搞清楚这套东西为什么有效], [第一部 + 第四部], [无],
)
标着 ⚙️ 的小节需要较重的基建投入，第一遍可以跳过。

#strong[遇到不认识的词]，翻 #ref(<sec-appendix-glossary>, supplement: [附录]) ------ 那里按 「你在什么情况下会需要它」重新索引了一遍，并辨析了五组容易混淆的术语。

== 怎么读这本书
<sec-how-to-read>
四部分，可以按需跳读，但有一条依赖：

#strong[第一部（问题）] 建立词汇。#ref(<sec-seven-shapes>, supplement: [章节]) 那一章是全书骨架， 后面每一章都在回指它的编号。#strong[如果只读一章，读那一章。]

#strong[第二部（环境）] 讲 Agent 站的地面 ------ 代码放哪、依赖怎么流、 规则住哪、手能伸到哪。这一部有一节需要重基建（会标出来）， 其余全都不需要。

#strong[第三部（判定）] 讲怎么知道它做对了。三层：测试看运行时的事实， 结构检查看结构上的事实，路径不变量看这条路径背后的约定。

#strong[第四部（回路）] 用控制论把前三部重新表述一遍。 #strong[这一部是唯一不从事故里长出来的]，它借的是一个成熟学科的语言， 而它的价值在于预测那些还没撞过的墙。

每一部最后都有一节 #strong["小规模怎么做"]， 里面的每一条都能在一周内、用现有工具链落地。

== 书里的数字都可以被复核
<sec-numbers>
所有的数字取自一个真实运行的系统：310 万行代码、 27,703 个源文件、23 条架构规则、20 份路径清单、 28 条自动化工作流、近四个月 18 万次执行。

#strong[样本量小的地方会被明确标出来] ------ "最近三十个改动""最近五百次失败"这类，当趋势看没问题， 当结论用会偏薄。

而书里所有的失败案例都真实发生过，包括作者自己的三处： 一个挂了四个月没人发现的崩溃、一处违反自己纪律的轮询代码、 一个在七次事故里重复了五次才被提上来的机制。

#strong[它们没有被删掉，而且是刻意的。]

== 这本书不讲什么
<这本书不讲什么>
- #strong[不讲怎么写提示词。] 提示词是重要的，但它不是这本书的问题。 这本书的立场是：如果你的系统只能靠提示词把质量托住，那这个系统还没建好。
- #strong[不讲哪个模型更好。] 书里的每一条结论，换一个模型仍然成立。
- #strong[不讲商业判断。] 做什么产品、哪个值得做 ------ 第 #ref(<sec-setpoint-outside>, supplement: [章节]) 章会 说明白，那个问题按定义就在这套系统的能力之外，而且这是范畴问题，不是疏忽。

== 致谢与免责
<致谢与免责>
书里所有的数字都取自一个真实运行的系统，可以被复核。所有的事故都真实发生过。 所有的规则都还在跑。

也所以，书里有几处是作者自己没做到的地方 ------ 一个挂了四个月没人发现的 定时任务，一处违反自己纪律的轮询代码，以及一个在七次事故里重复了五次 才被提上来的机制。它们没有被删掉。#strong[它们是这本书里最有说服力的部分。]

#part[第一部 · 问题]
= 两堵墙
<两堵墙>
= 两堵墙
<sec-two-walls>
Agent 规模化会连着撞两堵墙。两堵墙的解法都不是让 Agent 慢下来， 而是把「判定」这一侧扩容、机械化，再让它只做必要的判定。

先说清楚它们长什么样，因为#strong[这两堵墙的形状是一样的，只是撞的时候看起来不像。]

== 墙一：人审不过来了
<sec-wall-one>
最先撑不住的是人。

最近一个月，Agent 合并了两百九十一次，平均每天有十份改动排队等人看。 而人的逐行阅读速度并不会因为 Agent 的出现而变快，注意力也不会无限增加。

审查队列一旦变长，结果只有两种：要么让代码在队列里等着，要么在疲惫的时候 快速点通过。#strong[两种都不是质量。]

值得注意的是第二种。它不会表现为质量下降 ------ 恰恰相反，它表现为 #strong[审查通过率上升]。所有的指标都在变好，唯独没有人真的看过。 这是本书要反复讲的一个形状：#strong[一个失效的检查，看起来和一个通过的检查一模一样。]

=== 那个当时看起来很激进的决定
<那个当时看起来很激进的决定>
于是有了一个决定：#strong[不再用人做机械性的代码审查。]

格式、编译、测试、依赖方向、生成物来源、危险配置 ------ 这些有明确答案的事情， 交给机器判定会更快，标准也更一致。人腾出来的注意力，留给那些机器判断不了的问题。

这个决定的关键不在"不用人"，在#strong["有明确答案的"]这五个字。它划出了一条线：

- 线的这一侧：#strong[答案唯一，且可以被程序确认。] 这个函数在不在正确的目录里？ 这次改动有没有引入一条被禁止的依赖方向？这个字符串是不是硬编码的？
- 线的那一侧：#strong[答案取决于判断。] 这个需求到底要解决什么问题？ 两个方案的取舍是什么？这个不可逆的动作是不是真的应该发生？

第一类问题交给机器不是妥协，是升级 ------ 因为#strong[人在这类问题上本来就不可靠]。 一个人连续看三十个 diff 之后，对"依赖方向对不对"的判断准确率会掉到什么程度， 没有人愿意测量。

=== 机器判定要吃算力
<机器判定要吃算力>
而机器判定需要算力，于是要开始买机器。

现在机柜里有三台虚拟化服务器、两台 NAS、九台 Mac Mini，外加一个硬盘柜。 九台 Mac Mini 里有八台组成了 CI 的执行池。这个池子的并发数不是统一的， 而是按每台机器的内存配额分档 ------ 五台小内存的各跑三个并发， 三台大内存的各跑九个，加起来是四十二路并发的 macOS CI。

这里已经埋了一个后面要用的观察：#strong[并发数是配额之和，不是实测吞吐。] 这两个数字的差距，就是第二堵墙的位置。

== 墙二：机器也审不过来了
<sec-wall-two>
加完机器没多久，第二堵墙就来了。

产出速率又一次越过了机器的审查速度。每条改动都跑全量检查时，流水线开始排队， 改动在队列里堆积。

#strong[瓶颈只是从人的注意力换成了机时，问题的形状没变。]

这一次的解法不是继续加机器，而是让机器自己决定该审什么。

拿到一次改动之后，构建系统会去查它的反向依赖图，只为真正受影响的目标生成 这一次的流水线，测试再按每片若干个目标并行下发。#strong[没被波及的部分根本不会跑。]

这个动作从表面看是"省算力"，但它真正改变的是别的东西 ------ 我们会在 #ref(<sec-gain-and-delay>, supplement: [章节]) 里说明：这不是扩容，是#strong[把测量收缩到本次真正变化的那个 子空间]。买机器解决不了的事情，缩小测量范围解决了，这两者之间的区别 不是程度问题，是性质问题。

== 两堵墙之后
<sec-after-walls>
这两个决定的效果，在流水线数据里能直接看到。

最近合并进主干的三十个改动，有八个在合并前至少被拦下过一次 ------ 百分之二十七。 它们平均每个跑一点七条流水线，从红灯到转绿的中位时间是一点四小时， 最快的一次六分钟。整个过程里没有人做逐行审查。

被拦得最狠的两个都是大改动。一个是把远端文件系统与传输队列并入基础层， 红了四次，四个多小时后才转绿；另一个是把输入法收敛到自研引擎，同样红了四次， 跨了将近二十个小时。#strong[这两条如果排队等人审，光把 diff 读一遍的时间就不止于此。]

== 为什么"让 Agent 慢下来"是错的解法
<sec-not-slow-down>
面对排队，有一个显而易见的选项没有被选：#strong[少开几个 Agent。]

它确实能解决排队 ------ 而且它是唯一一个#strong[不需要任何投入]就能立刻见效的解法。 所以值得说清楚为什么不选它。

不是因为它无效。是因为#strong[它把一个可以被解决的问题，变成了一个永久的税。]

判定这一侧的产能是#strong[可以被工程化的]：机器可以买，检查可以只跑受影响的部分， 判定可以下沉到便宜的层。这些投入都是一次性的，收益是持续的。

而降低产出速率是一个#strong[持续付出的成本]，它不产生任何积累。 今天少开五个 Agent，明天还得少开五个。

#strong[两者的区别不在于哪个更快，在于哪个会随时间变好。]

这个判断有一个前提，而这个前提必须被检验： #strong[判定这一侧的产能确实是可以被工程化的。] 第二堵墙的存在说明这个前提不是无条件成立的 ------ 买机器到某个点之后就不再有效了，需要换一种做法。

#ref(<sec-three-remedies>, supplement: [第]) 会说明：在#strong[增益]（Agent 的吞吐）与#strong[延迟] （判定回到手里的时间）这个框架下（#ref(<sec-two-variables>, supplement: [第])）， "降低产出速率"其实是三条正当出路之一， 而且当另外两条走不通时，#strong[它比失稳好。]

== 判定这一侧到底在做什么
<sec-what-verdict-does>
在进入后面的章节之前，先把这一侧的构成说清楚， 因为"判定"这个词容易被理解成"跑测试"。

它至少包含四类完全不同的活动：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([类别], [它回答], [贵吗],),
  table.hline(),
  [#strong[结构判定]], [这段代码放得对吗], [便宜，不用跑程序],
  [#strong[行为判定]], [跑起来之后发生了什么], [贵，要起环境],
  [#strong[不变量判定]], [这条路径的约定守住了吗], [便宜，只扫改动],
  [#strong[元判定]], [上面三类本身可信吗], [#strong[最容易被漏掉]],
)
#strong[第四类是这本书的重点]，也是最少被讨论的一类。

它包括：这次测试真的跑了用例吗？这条检查规则自己有没有坏？ 这个红灯是代码的错还是环境的错？

而它之所以容易被漏掉，是因为#strong[前三类的失败会主动表现出来， 第四类的失败是静默的] ------ 一个坏掉的检查器， 输出的是一片绿色。

== 这两堵墙其实是同一堵
<sec-same-wall>
到这里可以把话说破了。

墙一是：#strong[修正速率上去了，但判定速率没有，于是队列爆炸。] 墙二是：#strong[修正速率又上去了，判定速率也上去了，但判定的对象没有缩小，于是队列又爆炸。]

两次的形状完全一样：#strong[一侧的速率提高，另一侧的带宽没跟上。]

而两次的解法之所以不同 ------ 一次是换判定的执行者，一次是缩小判定的范围 ------ 是因为第一次的瓶颈是#strong[带宽绝对不足]（人一天读不了十份 diff）， 第二次的瓶颈是#strong[测量冗余]（大部分检查测的是没有变化的东西）。

第四部会给这两件事一个统一的名字。在那之前，先记住这个形状： #strong[每当你想通过"加更多"来解决一个排队问题，先问一句 ------ 排队的是修正，还是判定？]

如果排队的是判定，加修正端的产能只会让队列更长。而这恰恰是引入 Agent 时 最自然的动作。

== 一个数字的重新解读
<sec-reread-numbers>
前面给了一组数：最近三十个改动，八个被拦下过， 平均每个跑 1.7 条流水线，中位 1.4 小时转绿。

这组数通常被读成"这套系统在工作"。#strong[但它们还能被读出别的东西。]

#strong[27% 的拦截率高不高？]

如果拦下的都是真问题，这个数说明#strong[每四个改动就有一个 如果没有这层拦截，会带着问题进主干]。

而如果拦下的大多是格式类问题，这个数说明的是别的事情。 #strong[唯一走完全程的那个例子里，被拦下的正是文件长度那条规则] （#ref(<sec-no-escape-rate>, supplement: [第]) 会展开这一点）。

#strong[1.7 条流水线意味着什么？]

它意味着大部分改动一次就过，少部分需要两三次。 #strong[这是一个健康的分布] ------ 如果它接近 1.0，说明检查太松； 如果它超过 3，说明失败信息不够，或者规则太严。

#strong[而它的趋势比它的值重要]（#ref(<sec-measure-the-loop>, supplement: [第])）。

#strong[1.4 小时的中位转绿时间说明什么？]

流水线本身的中位耗时远小于这个数。 #strong[所以这一个多小时里，大部分不是在等机器。]

这个观察在第四部会变成一个具体的建议 （#ref(<sec-delay-breakdown>, supplement: [第])）：#strong[回路延迟里最大的一块， 可能在"失败信息的质量"上，而不在基础设施上。]

== 两堵墙之前发生了什么
<sec-before-the-walls>
有一件事值得补充，因为它容易被跳过：

#strong[在撞第一堵墙之前，有一段时间是没有这些问题的。]

那时候 Agent 的产出还不多，人审得过来， 所有的规矩都在人的脑子里和评审的对话里。

#strong[而那段时间的做法是完全正确的] ------ 在那个产出速率下，建一套判定系统是过度工程 （#ref(<sec-when-not-to>, supplement: [第]) 那四条里的第一条）。

#strong[这本书讲的所有东西，都是被产出速率逼出来的。] 而不是因为它们在抽象意义上"更好"。

这有一个实际推论：#strong[如果你现在没有撞墙， 那么这本书对你的价值主要是"知道墙在哪"， 而不是"现在就把墙拆了"。]

#ref(<sec-not-scale>, supplement: [第]) 讲过，墙会比预期更早出现 ------ 但它还没到的时候， 提前建墙的成本是真实的，而收益是零。

#strong[唯一值得提前做的是那种成本极低的]： 比如给每条规则写下失败形态、比如退出码三分。 这些即使在撞墙之前也不亏。

== 为什么"人来做机械性审查"注定失败
<sec-mechanical-review-fails>
#ref(<sec-wall-one>, supplement: [第]) 那个决定 ------ 不再用人做机械性的代码审查 ------ 值得再给一个理由，因为它是这本书唯一一个"关于人"的论断。

#strong[人在机械性判断上的表现，会随连续工作时长而下降， 而且下降是不被察觉的。]

一个人连续看三十个 diff 之后，对"依赖方向对不对"的判断准确率 会掉到什么程度，#strong[没有人愿意测量] ------ 而正因为没人测量，这个下降不会出现在任何指标上。

#strong[结果是：审查通过率保持稳定，而审查质量在下降。]

这正好是形状 A：#strong[你以为你在测量"代码质量"， 实际上你在测量"审查者的疲劳程度"。]

而机器在这类判断上有一个人永远没有的性质： #strong[它的第三十次判断和第一次完全一样。]

#strong[这不是"机器更聪明"，是"机器不累"] ------ 而对于有明确答案的问题，不累就够了。

== 那条线该画在哪
<sec-where-to-draw>
#ref(<sec-wall-one>, supplement: [第]) 给了两个例子，这里给一个可以操作的判据：

#quote(block: true)[
#strong[两个不同的人，在不知道对方答案的情况下， 会给出同一个答案吗？]
]

- #strong[会] → 有明确答案，交给机器
- #strong[不会] → 需要判断，留给人

这个判据的好处是它可以被#strong[实际执行] ------ 挑十个评审意见，找两个人各自判断一遍，看重合度。

而大部分团队做完这个实验会发现： #strong[重合度高的那些，恰恰是最占用评审时间的那些] （格式、位置、命名、明显的重复）。

#strong[而重合度低的那些 ------ 方案取舍、需求理解、边界完整性 ------ 在评审里得到的时间反而最少]，因为它们排在后面， 而那时候注意力已经被前面消耗掉了。

#strong[这就是"交给机器"的真正收益：不是省了那点时间， 是把注意力从重合度高的部分，转移到了重合度低的部分。]

== 第三堵墙在哪
<sec-third-wall>
两堵墙都是"判定跟不上产出"。而按 #ref(<sec-same-wall>, supplement: [第]) 那个框架， 可以预测第三堵墙的位置。

增益还在涨（Agent 数量、并行度）。而这一次， #strong[判定这一侧还能怎么扩容？]

- 换执行者：已经做了（人 → 机器）
- 缩小测量范围：已经做了（全量 → 只测受影响的）
- 加带宽：一直在做，但有物理下界

#strong[三条路都走过了之后，剩下的是什么？]

#ref(<sec-delay-breakdown>, supplement: [第]) 会给出一个答案：#strong[回路延迟里最大的一块， 可能已经不在基础设施上了，而在"Agent 读懂失败并修好"这一段。]

如果这个推测成立，那么第三堵墙的形态会是：

#quote(block: true)[
#strong[流水线不排队了，机器也够，但每个改动要跑更多轮才能合入。]
]

而它的解法不在基础设施上，在#strong[失败信息的质量]上 ------ 一个带着 owner、证据和下一步的失败， 和一个只说"不允许"的失败，中间差的是好几轮迭代。

#strong[这本书后面的很多内容，回头看都是在为这堵墙做准备：] #ref(<sec-incident-hint>, supplement: [第]) 那两个字段、#ref(<sec-real-interception>, supplement: [第]) 那四步、 #ref(<sec-minimal-checks>, supplement: [第]) 那个最小重跑集合 ------ 它们全都在压缩同一段延迟。

== 一个常见的误解：这两堵墙不是"规模问题"
<sec-not-scale>
容易被读成"仓库大了才会有这些问题"。不是的。

#strong[两堵墙的触发条件是产出速率与判定速率的比值， 和仓库大小、团队人数都没有直接关系。]

一个两个人的团队，如果两个人各开三个 Agent， 每天产出十几个改动，而判定仍然靠两个人互相审 ------ #strong[它已经撞上了第一堵墙]，只是墙比较近，撞得比较轻。

而这个观察有一个实际推论：#strong[这两堵墙会比大部分人预期的更早出现。]

它们不是"等我们做大了再考虑"的问题， 而是#strong[在引入 Agent 的那一刻，比值就已经开始变了。]

区别只在于，小团队撞墙时的表现比较温和： 不是流水线排队，而是"最近合并的东西好像没人仔细看过"。

#strong[而这两种表现，本质上是同一件事。]

#block[
#callout(
body: 
[
书里会反复出现"最近三十个改动""最近五百次失败"这类样本。 它们都是真实的，但样本量不大，当趋势看没问题，当结论用会偏薄。 凡是我知道样本不够的地方，都会说明。

]
, 
title: 
[
一个提醒
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== 这一章的三个数，一年后该变成什么
<sec-two-walls-targets>
这一章给的三个数 ------ 27% 的拦截率、1.7 条流水线、1.4 小时转绿 ------ 它们的#strong[目标值]是什么？

这是一个值得问的问题，因为#strong[没有目标值的指标会被当成"越高越好"或"越低越好"]， 而这三个都不是。

#strong[拦截率]：不该趋近于零。趋近于零意味着检查太松， 或者 Agent 已经学会了绕过。#strong[一个健康的值是稳定在某个区间]， 而它的变化比它的值更有信息量。

#strong[流水线次数]：应该缓慢下降 ------ 随着规则的失败信息变好、 随着更多规则被#strong[前馈化] ------ 也就是从「事后检查」变成 「事前就走不到错的路上去」（#ref(<sec-ground-and-walls>, supplement: [第]) · #ref(<sec-rule-endgame>, supplement: [第])）。 #strong[如果它在上升，那是第三堵墙的信号]（#ref(<sec-third-wall>, supplement: [第])）。

#strong[转绿时间]：这个数由两部分组成，而它们该往不同方向走。 流水线耗时应该随稀疏测量的改进而下降； 而"Agent 理解并修正"的那部分#strong[取决于失败信息的质量]。

#strong[三个数里，只有第二个有明确的方向。] 另外两个是区间指标， 而区间指标最容易被误用 ------ 因为它们没法被"优化"， 只能被观察。

#strong[这本身也是一条一般的经验]：一个不知道目标值的指标， 不要放进任何人的考核里。它会被优化到一个你没想要的方向。

== 这一章为什么从数字开始
<sec-why-numbers-first>
这本书的第一章没有从理念开始，从两个具体的排队现象开始。 这是刻意的，理由有两条。

#strong[一、这两堵墙是可以被识别的，而理念不能。]

"我们需要确定性的基建"这句话， 没有任何一个团队能判断它现在适不适用。

#strong[而"我们的审查队列在变长"可以被观察， "流水线在排队"可以被观察。]

#strong[所以这本书的入口是两个症状，不是一个主张。]

#strong[二、这两堵墙决定了后面所有内容的必要性。]

如果你没有撞上这两堵墙，那么后面的大部分内容 对你来说是过度工程（#ref(<sec-before-the-walls>, supplement: [第])）------ 而这本书宁可你现在不建，也不希望你建一套 你还不需要的东西然后维护它。

#strong[所以第一章的实际功能是一个筛子]： 它让读者判断自己在不在这本书的适用范围里。

== 两堵墙之外的第三种可能
<sec-third-possibility>
有一种情况这一章没讲，但它在实践中很常见：

#quote(block: true)[
#strong[产出速率没有变，但质量下降了。]
]

这不是这两堵墙里的任何一堵 ------ 队列没有变长， 流水线没有排队，#strong[只是合并进去的东西变差了。]

#strong[而它的成因通常是：判定的形式还在，实质没了。]

具体表现：评审仍然在做，但评审的人已经不逐行看了； 测试仍然在跑，但新加的测试没有断言； 检查仍然是绿的，但没有人问它检查了什么。

#strong[这是形状 A 在流程上的形态]，而它比排队更危险， 因为#strong[排队是可见的，而这个不是。]

#strong[识别它的方式]：不看队列长度， 看#strong["从提交到合并"这个过程里，有多少个环节 会因为提交者的态度不同而给出不同的结果。]

那些环节就是实质正在流失的地方。

#strong[而这本书讲的所有机制，共同的性质是： 它们的结果不取决于任何人的态度。]

== 这一章能被压成的三句话
<sec-two-walls-three-lines>
#strong[一、两堵墙的形状是一样的：一侧的速率提高了，另一侧的带宽没跟上。]

而两次的解法不同 ------ 一次是换判定的执行者， 一次是缩小判定的范围 ------ #strong[是因为两次的瓶颈性质不同]： 一次是带宽绝对不足，一次是测量冗余（#ref(<sec-same-wall>, supplement: [第])）。

#strong[二、"加更多"解决不了排队，先问排队的是修正还是判定。]

如果排队的是判定，#strong[加修正端的产能只会让队列更长] ------ 而这恰恰是引入 Agent 时最自然的动作。

#strong[三、判定的第四类（元判定）最容易被漏掉。]

前三类（结构、行为、不变量）的失败会主动表现出来， #strong[而"这些判定本身可不可信"的失败是静默的] （#ref(<sec-what-verdict-does>, supplement: [第])）。

== 一个提前的说明
<sec-early-note>
这本书后面会反复回到这一章的三个数 （27% 拦截率、1.7 条流水线、1.4 小时转绿）， 而每一次都会从一个新的角度重读它们。

#strong[这不是重复，是因为同一组数在不同的框架下说的不是同一件事：]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([在哪章], [这三个数说明什么],),
  table.hline(),
  [本章], [判定在工作],
  [#ref(<sec-no-escape-rate>, supplement: [第])], [#strong[它们全是过程指标，没有一个是结果指标]],
  [#ref(<sec-delay-breakdown>, supplement: [第])], [#strong[1.4 小时里大部分不是在等机器]],
  [#ref(<sec-measure-the-loop>, supplement: [第])], [它们的#strong[趋势]比值更有信息量],
)
#strong[四种读法，而第二种是最重要的那个] ------ 因为它指出了这本书证据链上最大的一处缺失。

= 不确定性到底在哪里
<不确定性到底在哪里>
= 不确定性到底在哪里
<sec-where-uncertainty-lives>
在讨论怎么对付不确定性之前，得先搞清楚它住在哪。

这一章会先讲一个#strong[几乎正确、但错在关键处]的模型 ------ 因为它是大多数人 （包括本书作者很长一段时间）实际在用的模型，而且它错的方式很有教育意义。

== 一个很有诱惑力的模型：模型是编解码器
<sec-codec-model>
这个模型是这么说的：

#quote(block: true)[
大模型本质还是编解码，和视频、音频一样。不一样的是解码过程不确定， 所以才有了提示词和 harness 这类技术。
]

这个说法比大多数人的直觉更接近对，而且#strong[它有几分不是比喻，是字面事实]。

Transformer 最初就是一个编码器-解码器结构，GPT 那一系在文献里的正式名称 就叫 decoder-only。自回归生成在论文里的术语就是 decoding ------ 贪心解码、 束搜索、核采样、温度，全都叫解码策略。

更深的一层：训练一个语言模型，等价于学一个概率分布，而学一个概率分布 等价于构造一个最优编码。#strong[交叉熵损失的单位就是比特] ------ 它字面上就是期望码长。

而「和视频、音频一样」这句话比它看起来的更准。把一个大语言模型当作概率模型 接上算术编码，它压缩图像的效果可以好过专门的图像编解码器，压缩音频的效果 可以好过专门的音频编解码器。#strong[一个语言模型能在图像和音频编解码器自己的赛道上 赢它们。] 这不是类比，这是同一件事。

=== 这个模型的实践价值：它剥掉了拟人化
<这个模型的实践价值它剥掉了拟人化>
在指出它错在哪之前，得先说清楚它对在哪，因为这一点非常重要。

Agent 工程里最普遍的失败，是把模型当成一个"能理解"的同事。一旦这么想， 修法就会变成：我再解释清楚一点、让它仔细一点、加一句"请认真思考"。

#strong[编解码器这个框架让这类修法一眼看上去就很蠢：你不会请求一个解码器再努力一点。]

这个框架直接导向本书的一条核心主张 ------ #strong[把规则写进结构，而不是写进文档]。 如果对面是一个解码器，那你能控制的只有两样：喂进去的东西，和对吐出来的东西 做什么检查。#strong["让它记住"根本不在选项里。]

这条直觉是对的。这本书的整个第二部都建立在它上面。

== 但它错在三处，一处比一处要紧
<sec-codec-broken>
=== 一、编解码器的编码与解码是对某条消息的互逆，这里不是
<一编解码器的编码与解码是对某条消息的互逆这里不是>
视频编解码器编的是#strong[这一段视频]，解出来还是那段视频 ------ 存在一个 真值消息，编解码器是它上面的一个（有损或无损的）双射。

语言模型没有这个东西。压缩发生在训练时，压的是#strong[一个分布]，不是一条消息。 推理时，提示词#strong[不是输出的压缩表示]，你没法"解出原本想要的那个答案"， 因为从来就不存在那个答案。

#strong[编解码器这个框架暗示着"有一个正确答案正在被重建"。没有。 只有一个分布正在被采样。]

=== 二、不确定性不是解码器的缺陷，而是构成性的
<二不确定性不是解码器的缺陷而是构成性的>
这是最要紧的一点，而且有一个干净的实验可以证伪那个模型：

#strong[你今天就可以把解码完全确定化。] 温度设零、贪心解码、固定随机种子、 用确定性的算子。做完之后 ------ 同样的输入，逐字节相同的输出。

#strong[然后问题一点都没有解决。]

贪心解码的模型照样会给出错误的实现，照样会在提示词的微小改动下给出 完全不同的答案，照样会自信地写出一个编译得过、跑得起来、逻辑是错的函数。

#strong[把解码器变确定，并不带来结果的确定。] 这是那个模型预测不了的事实， 而它是整件事的关键。

真正的不确定性来源不是采样在掷骰子。是#strong[从提示词到输出分布的这个映射， 本身就是你无法完整指定的]。这是一个规格问题，不是一个解码问题。

打个不那么严谨但很说明问题的比方：一个随机数生成器的不确定性， 换个种子就没了；而一个你不知道它在算什么的函数，你把输入固定住， 它依然会给你一个你预测不了的结果 ------ #strong[只是这次它每次都给同一个 你预测不了的结果。]

=== 三、提示词不是编码，harness 也不是在补偿解码噪声
<三提示词不是编码harness-也不是在补偿解码噪声>
编码器是有规范的：给定这一帧，按标准产出这段码流，任何符合标准的实现 产出的结果都一样。

提示词没有这样的规范，也#strong[没有逆]。两个"意思一样"的提示词会给出不同的 分布，而你无法从输出反推出应该给什么提示词。

harness 这一侧更明显。#strong[如果问题真的出在"解码器会掷骰子"，那修法就应该 在解码器上] ------ 约束解码、语法约束、结构化输出、logit 偏置。这些东西确实有用， 但请注意：#strong[它们不是本书讲的那套系统在做的事。]

本书讲的那套系统做的是：#strong[拿外部的真值去验证输出] ------ 测试、类型检查、 依赖图查询、退出码。#strong[这不是在修编解码器。这是把编解码器放进一个带测量的 回路里。]

== 换一个模型
<sec-control-model>
把上面三条错误反过来，就得到一个能用的模型：

#quote(block: true)[
模型是一个#strong[对分布的有损压缩]。推理不是解码某条消息， 而是#strong[从一个你无法完整指定的条件分布里采样]。
]

于是三个概念各归其位：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([概念], [编解码器框架说], [实际是],),
  table.hline(),
  [提示词], [编码], [#strong[条件化] ------ 选中分布的一个区域，无逆，无规范],
  [采样], [解码], [解码，这一条是对的],
  [harness], [降噪], [#strong[给一个开环对象闭环] ------ 加测量与反馈],
)
最后一行是全书的枢纽。用控制论的语言说：

#quote(block: true)[
#strong[模型是一个高增益、非线性、无法完整建模的被控对象。 你不试图让它变确定，你在它外面闭一个回路。]
]

这句话里的每一个术语在 #ref(<sec-appendix-glossary>, supplement: [附录]) 都有一句话的解释， 而第四部会逐个展开。#strong[现在不需要全懂] ------ 只需要接受一件事： 这是一个有名字的东西，而那个名字带着七十年的现成经验。

这句话不是修辞。它有一个可以检验的推论 ------ #strong[如果这个说法成立，那么这套系统应该长得像一个标准的控制回路， 包括控制论里那些不显然的部件。]

第四部会逐条检验这件事，结论是：它确实长成了那个样子， 而且长出了几个作者当时并不知道有名字的部件。

== 一个常见的反驳，以及它为什么不成立
<sec-objection-temperature>
前面那个"把温度调到零"的论证，最常见的反驳是：

#quote(block: true)[
贪心解码确实还会出错，但错误变得#strong[可复现]了 ------ 而可复现的错误是可以被逐个修掉的。
]

这个反驳听起来有力，但它在实践中不成立，原因有两层。

#strong[第一层：可复现性绑定在整个输入上，而输入每次都不一样。]

同一个提示词加同样的种子，输出确实一样。但真实的 Agent 工作流里， 提示词从来不是同一个 ------ 它包含了当前的文件内容、之前几轮的对话、 工具返回的结果。#strong[这些每次都在变。]

所以你得到的不是"可复现的错误"，是 "#strong[在一个你永远不会再次遇到的精确输入下可复现的错误]"。 这种可复现性没有工程价值。

#strong[第二层：它假设错误的数量是有限且可枚举的。]

修掉一个可复现的错误，前提是这类错误的总数不太多。 而模型的错误不是从一个有限清单里抽出来的， #strong[它们是从一个连续空间里生成的] ------ 修掉这一个， 下一个是它的邻居，长得不一样但成因相同。

#strong[这两层合起来解释了为什么"确定化解码"这条路走不通]： 它把不确定性从"输出层"移到了"输入层"，而输入层的变化你控制不了。

== 那些真正有用的确定化手段在哪一层
<sec-where-determinism-helps>
说清楚这一点很重要，因为这一章不是在反对所有的确定化努力。

有一类确定化是#strong[真正有效]的，而它们的共同点是： #strong[它们作用在输出的形状上，不作用在输出的内容上。]

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([手段], [它保证什么], [它不保证什么],),
  table.hline(),
  [结构化输出 / 语法约束], [输出#strong[能被解析]], [输出#strong[是对的]],
  [工具调用的参数校验], [调用#strong[格式合法]], [调用#strong[该不该发生]],
  [有限的动作空间], [它只能做这几件事], [它做的是对的那件],
)
#strong[这些都值得做，而且成本很低。] 它们消除了一整类噪声 ------ 解析失败、格式错误、参数缺失。

但它们消除的是#strong[形式上的不确定性]，而这本书讲的是 #strong[语义上的不确定性] ------ 一个格式完美、参数合法、 在允许的动作空间之内、#strong[而且完全错误]的输出。

#strong[后者是形式手段够不着的，而它需要的是外部的真值。] 这就是整本书的方向。

== 三个模型的对照
<sec-three-models>
把三种常见的心智模型放在一起，看它们各自会导向什么动作：

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([模型], [它把模型看成], [于是修法是], [它的盲区],),
  table.hline(),
  [#strong[拟人化]], [一个会理解的同事], [解释得更清楚、让它更认真], [#strong[它不会因为被说服而改变行为]],
  [#strong[编解码器]], [一个解码器，只是解码不确定], [把解码确定化、优化提示词], [#strong[确定化解码不解决问题]],
  [#strong[被控对象]], [一个高增益非线性系统], [#strong[在外面闭一个带测量的回路]], [需要外部真值，而真值不总是有],
)
#strong[第一行是最普遍的，也是最贵的。]

它贵在两个地方：一是它导向的动作（改提示词、加强调） 收益递减得非常快；二是它会让人#strong[在系统失败时归因错误] ------ "是我没说清楚"而不是"我没有验证手段"。

而这两个模型的差别在实践中有一个很好的判别式：

#quote(block: true)[
#strong[当一个 Agent 做错了一件事，你的第一反应是什么？]

- "我得把要求写得更清楚" → 你在用拟人化模型
- "我得让它做错这件事变得不可能" → 你在用被控对象模型
]

#strong[第二种反应会导向结构性的解法，第一种不会。]

== 这个模型对读者的直接用处
<sec-model-utility>
理论部分容易读起来像装饰，所以说清楚它的三个直接用处：

#strong[一、它告诉你哪些努力是徒劳的。]

优化提示词的收益有上限，而且上限比大部分人以为的低。 一旦你接受"这是一个规格问题而不是解码问题"， 你就不会在提示词工程上无限投入。

#strong[二、它告诉你该建什么。]

一个开环系统需要的是#strong[测量]。 所以问题从"怎么让它输出更好"变成"#strong[怎么知道这次输出好不好]"------ 而后者是一个工程问题，有确定的解法。

#strong[三、它告诉你什么时候可以停。]

#ref(<sec-when-to-stop>, supplement: [第]) 讲过：当瓶颈不在判定这一侧时， 继续加固判定是在优化一个不是瓶颈的环节。 #strong[而"哪里是瓶颈"这个问题，只有在有了系统模型之后才能回答。]

没有模型的时候，人们优化的是最容易优化的那个部分， 而那通常不是瓶颈。

== 为什么"外部真值"是这套方法的前提
<sec-external-truth>
被控对象模型有一个前提，而这个前提值得被明确说出来， 因为#strong[它决定了这套方法的适用范围]：

#quote(block: true)[
#strong[你需要一个不依赖模型的真值来源。]
]

在这本书的场景里，这个真值是： 测试的执行结果、编译器的判断、依赖图的查询、退出码。

#strong[它们的共同点是：它们的正确性不依赖于模型说了什么。]

而这个前提在某些场景下不成立：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([场景], [有没有外部真值],),
  table.hline(),
  [写代码], [#strong[有] ------ 编译器、测试、类型检查],
  [数据处理], [#strong[有] ------ schema、约束、对拍],
  [写文档], [#strong[部分] ------ 链接有效性、术语一致性可测，内容质量不可测],
  [创意写作], [#strong[基本没有]],
  [开放式研究], [#strong[基本没有]],
)
#strong[这本书的方法在有真值的场景里有效，在没有的场景里不适用。]

而这解释了一个现象：#strong[为什么"用 Agent 写代码"比 "用 Agent 写别的东西"更早成熟。]

不是因为代码更简单，是因为#strong[代码这个领域自带了一整套 不依赖人的判断的验证工具] ------ 而这套工具是几十年积累出来的。

=== 那没有真值的场景怎么办
<sec-no-truth-case>
这本书给不出完整答案，但可以指出一个方向：

#strong[把不可判定的目标，拆成一部分可判定的约束。]

写这本书就是一个例子。"这本书写得好不好"没有真值。 #strong[但下面这些有：]

- 每章有没有声明一个可证伪的承诺
- 交叉引用有没有指向不存在的东西
- 术语有没有前后不一致
- 每个形状有没有至少一个非 Agent 领域的实例

#strong[这些约束不保证书写得好，但它们排除了一批确定写得不好的形态。]

而这正是 #ref(<sec-constraint-not-tracking>, supplement: [第]) 那一节的核心： #strong[约束满足不等于目标达成，但它是在没有真值时能做的最好的事。]

== 一个更早的类比也失败了
<sec-earlier-analogy>
在编解码器模型之前，还有一个更常见的类比值得一并处理， 因为很多人现在还在用它：

#quote(block: true)[
#strong["把 Agent 当成一个初级工程师。"]
]

这个类比比拟人化好一些 ------ 它至少承认了需要审查、需要指导、 需要明确的规范。

#strong[但它在三个地方失败，而三个都很关键：]

#strong[一、初级工程师会积累。] 你指出一次问题，他下次会记得。而 Agent 不会 ------ 每个会话都是第一天（#ref(<sec-rule-present>, supplement: [第])）。

这一条直接推翻了"带新人"那套方法： #strong[口头指导、逐步放权、犯错后复盘 ------ 全都依赖积累。]

#strong[二、初级工程师知道自己不知道。] 他会问、会犹豫、会说"我不确定这样对不对"。 #strong[而 Agent 的置信度和它的正确性相关性很弱] ------ 它会用同样的语气给出正确和错误的实现。

#strong[三、你不会同时带四十个初级工程师。] 而这正是这套系统的实际状态（260 个并行的工作区）。

#strong[在那个规模下，任何依赖"人来指导"的机制都会成为瓶颈] ------ 这正是第一堵墙（#ref(<sec-wall-one>, supplement: [第])）。

== 三个类比的共同错误
<sec-analogy-common-error>
拟人化、初级工程师、编解码器 ------ 三个类比错在不同的地方， 但它们有一个共同点：

#quote(block: true)[
#strong[三个都把注意力引向了"怎么让它输出更好"， 而不是"怎么知道输出好不好"。]
]

- 拟人化 → 说得更清楚
- 初级工程师 → 指导得更好
- 编解码器 → 解码得更确定

#strong[三条路都是在优化生成，而不是在建立验证。]

而这本书的全部主张就是：#strong[在这个问题上， 验证的边际收益远高于生成。]

理由在 #ref(<sec-external-truth>, supplement: [第])：#strong[生成的正确性没有上界可言， 而验证有一个明确的、可以被工程化的目标 ------ 让每一次产出都能被判断。]

#strong[而后者是一个有限的、可以完成的工程问题。]

== 这个模型改变什么
<sec-model-consequences>
一个模型的价值在于它改变你的动作。这个替换至少改变三件事：

#strong[第一，它告诉你工程投入该放在哪一侧。]

如果不确定性是解码器的属性，那前沿就是更好的解码。 如果它是规格问题，那前沿是#strong[更便宜、更密的验证] ------ 因为你无法指定要什么， 就只能不断地问"这是不是我要的"。#strong[后者是本书全部内容的方向。]

#strong[第二，它解释了为什么"环境"比"检查"更重要。]

控制论里有一个基本结论：#strong[前馈决定性能，反馈只提供鲁棒性。] 一个纯反馈的系统，性能上限由回路延迟决定，再怎么调都超不过去。

翻译过来就是本书第二部的那句话 ------ #strong[检查本身不产生质量，环境才产生质量。] 这句话在实践里是撞出来的，但它在理论上是可以被证明的。

#strong[第三，它把"不确定"和"不可控"分开了。]

一个系统可以是随机的，但完全可控（比如一个带反馈的温控器， 外界扰动是随机的，但室温稳在设定点）。也可以是确定的，但完全不可控 （比如一个你没有测量手段的确定性过程）。

#strong[Agent 属于第一类。] 它的输出是随机的，这件事永远不会变， 也不需要变。你要建的不是一个让它不随机的东西， 是一个#strong[让随机性不影响结论]的东西。

== 这个模型对"提示词"的定位
<sec-prompt-role>
说清楚这本书对提示词的态度，因为它容易被误读成"提示词不重要"。

#strong[提示词是重要的，它就是那个条件化的动作]（#ref(<sec-control-model>, supplement: [第])）------ 它决定了你在分布的哪个区域采样，而区域之间的差别可能很大。

#strong[但它有三个性质，决定了它不能是系统的主要保障：]

#strong[一、它的效果无法被验证，除非有外部真值。] 你怎么知道提示词 A 比提示词 B 好？ #strong[只能通过输出的质量，而那正是你要验证的东西。]

#strong[二、它的收益递减很快。] 从"没有提示词"到"一份清楚的提示词"，收益巨大。 从"清楚"到"非常清楚"，收益小得多。 而从那之后，多写的每一句都在稀释前面的（#ref(<sec-why-carriers-work>, supplement: [第])）。

#strong[三、它不随规模复用。] 一份好的提示词是针对一类任务的。而一个仓库里有几十类任务， #strong[每一类都需要它自己的提示词] ------ 这就是为什么会有 skill 这种载体（#ref(<sec-skills>, supplement: [第])）。

#strong[所以正确的定位是：提示词是条件化的手段， 而按到达时机分的那五种载体（#ref(<sec-five-carriers>, supplement: [第])）是提示词工程的工程化形态。]

一份好的常驻文件加上一批 skill，本质上就是 "把提示词工程从一次性的手艺，变成一个有结构、 有取舍、可维护的系统"。

#strong[而这本书讲的其余部分，是当条件化做到极限之后， 仍然需要的那些东西。]

#block[
#callout(
body: 
[
作者原本用的是编解码器模型。这本书里描述的那套系统，是在那个模型下建成的， 而且建对了 ------ #strong[这说明一个错的模型也可以生成正确的行为，只要它错的方向凑巧 指向对的一侧。]

但错的模型有代价，而且代价是具体的：它预测不了下一个失败类在哪。 #ref(<sec-boundaries>, supplement: [章节]) 会讲这个代价在哪几个地方已经显现了。

]
, 
title: 
[
这一章的立场
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
== 一个实验，读者可以自己做
<sec-diy-experiment>
这一章的核心论断 ------ "把解码确定化不解决问题" ------ 可以被读者自己验证，成本大概半小时。

#strong[步骤：]

+ 挑一个你的 Agent 最近做错的任务
+ 把温度设成零、固定种子（如果你的接口支持）
+ 用#strong[完全相同]的输入跑三次 → 确认输出逐字节相同
+ 现在把输入改一个字：加一个空格、换一个同义词、 调整一句话的顺序
+ 再跑一次

#strong[如果第 5 步的输出和第 3 步显著不同 ------ 而它通常会 ------ 那么你刚刚验证了：确定性住在"输入到输出的映射"里， 而不是住在采样里。]

而这个实验还有一个副产品：#strong[它会让你对"提示词调优" 的收益上限有一个直观的感受] ------ 因为你会看到一个字的改动能造成多大的差别， 而你没法穷举那个空间。

#strong[这就是 #ref(<sec-prompt-role>, supplement: [第]) 那三条性质的第一条在实验室里的形态： 提示词的效果无法被验证，除非有外部真值。]

== 这一章的结构说明
<sec-chapter-two-structure>
这一章的写法有点特别 ------ 它花了一半篇幅讲一个#strong[错的]模型。

这不是为了铺垫。#strong[是因为那个模型正是这套系统建成时用的模型， 而它建对了。]

所以这一章要同时说清楚两件看起来矛盾的事：

+ #strong[那个模型是错的]（三处，#ref(<sec-codec-broken>, supplement: [第])）
+ #strong[它生成的行为是对的]（剥掉拟人化，导向"写进结构"）

而调和这两点的是一个更一般的观察：

#quote(block: true)[
#strong[一个错的模型，如果它错的方向凑巧指向对的一侧， 可以生成正确的行为 ------ 但它无法预测下一步。]
]

编解码器模型把注意力从"模型的意图"移到了"输入和输出"， #strong[这一步移对了。] 它只是把移动的距离算错了 ------ 它以为终点是"更好的解码"，而实际的终点是"外部的验证"。

#strong[这个区分对读者的实际价值是]：

如果你现在用的是编解码器模型（很多人是）， #strong[你不需要推翻你已经建的东西] ------ 大概率它们是对的。

#strong[你需要的是换一个模型来决定下一步建什么。]

而 #ref(<sec-model-consequences>, supplement: [第]) 那三条就是换模型之后 立刻能得到的三个答案。

= 承诺什么
<承诺什么>
= 承诺什么
<sec-what-we-promise>
#ref(<sec-where-uncertainty-lives>, supplement: [章节]) 说清了不确定性住在哪。 这一章说清楚：#strong[在这个前提下，我们到底能承诺什么。]

这不是一个务虚的问题。#strong[承诺什么，决定了你去建什么。] 一个承诺"输出稳定"的系统和一个承诺"验收稳定"的系统， 建出来的东西完全不一样。

== 不承诺同样的代码
<sec-not-same-code>
一个功能有很多种正确实现。

要求 Agent 每次给出同样的代码，等于要求它退化成一个模板引擎 ------ #strong[而那你不如直接写模板，还更快更省。]

这不是妥协，是#strong[把要求放在正确的层次上]。

=== 一个见过的反面做法
<sec-golden-answer>
有一种很自然的想法：给每类任务准备一份"标准答案"， 然后比对 Agent 的产出和标准答案的差距。

这个做法的失败方式是可以精确预测的：

- #strong[所有偏离标准答案的正确实现都被拒绝] ------ 而正确实现的空间远大于标准答案，所以拒绝率会很高
- #strong[所有符合标准答案的错误实现都被接受] ------ 因为标准答案只覆盖了它自己那条路径上的正确性

于是这套东西同时具有高误报和高漏报。而更糟的是它的#strong[动力学]： 被拒绝多了之后，Agent（和人）会学会#strong[朝标准答案收敛] ------ 不是朝正确收敛。

#strong[这是形状 A 的一个变种：判定测的不是你以为的东西。] 它测的是相似度，而你以为它测的是正确性。

== 承诺同样的判定边界
<sec-same-boundary>
那么承诺什么？#strong[承诺每一次产出都能用同一套证据来判断算不算数。]

具体是五条：

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([边界], [换来什么], [在哪一章],),
  table.hline(),
  [行为能够被测试观察], [运行时的事实可查], [#ref(<sec-tests>, supplement: [章节])],
  [结构符合仓库的架构约定], [结构上的事实可查], [#ref(<sec-guardrails>, supplement: [章节])],
  [改动尊重 owner 与不变量], [路径背后的约定不失效], [#ref(<sec-arbiter>, supplement: [章节])],
  [高风险动作保持显式], [不可逆的事不会被悄悄做掉], [#ref(<sec-risk-distribution>, supplement: [第])],
  [失败能定位、修复能复验], [搜索空间能收缩], [#ref(<sec-three-failures>, supplement: [章节])],
)
#strong[这五条就是这本书剩下部分的目录。]

=== 第五条最容易被漏掉
<sec-fifth-matters>
前四条是"拦住什么"，第五条是"拦住之后怎么办"。

而第五条决定了前四条的#strong[实际价值]。

一个只返回"失败"的判定，Agent 只知道#strong[方向错了]， 它下一次的搜索空间和这一次一样大 ------ 于是它会换一个写法再撞一次， 撞到某次侥幸通过为止。#strong[而侥幸通过的那次，通常是因为它绕过了检查， 不是因为它做对了。]

一个返回了 owner、具体证据和最小重跑集合的判定， Agent 的搜索空间会实实在在地收缩。

#strong[所以"失败信息的质量"不是用户体验问题，它决定这套系统收不收敛。]

== 边界之内，自由探索
<sec-freedom-inside>
有一个反直觉的效果值得说清楚：

#quote(block: true)[
#strong[边界越明确，可探索的空间越大，不是越小。]
]

模糊的边界会让 Agent（和人）保守。因为不知道哪里会踩雷， #strong[最安全的策略是只做最像已有代码的事情] ------ 抄一段相邻的实现，改几个名字。

这恰恰是创新的反面，而且它有一个很隐蔽的代价： #strong[它让技术债以"和周围一致"的名义扩散。] 周围有一段重复的机制，新代码就再重复一次，因为那样"看起来最安全"。

而一套明确的边界传递的信息是：#strong[这些线之外的地方，你随便走。]

这是这本书的核心主张之一，也是"不承诺同样的代码"那句话的正面表述： #strong[判定边界不是笼子，是许可。]

== 三个明确的不承诺
<sec-three-non-promises>
一本书的可信度，很大程度上由它明确拒绝承诺的东西决定。三条：

=== 一、不承诺 Agent 不犯错
<sec-not-no-errors>
#strong[只承诺错误在副作用发生之前被发现。]

"副作用发生之前"这个限定很重要，它划出了一条清晰的线：

- 一个错误的实现被写出来了 ------ #strong[可接受]，这是探索的一部分
- 一个错误的实现被合并了 ------ 判定失效了，这是这本书要解决的
- 一个错误的迁移在生产库上跑了 ------ #strong[不可挽回]， 所以那条路径有最高等级的不变量守着

三个阶段的代价差几个数量级，而这套系统的全部设计， 就是#strong[把错误尽量挡在第一个阶段。]

=== 二、不承诺需求是对的
<sec-not-right-requirement>
#ref(<sec-setpoint-outside>, supplement: [章节]) 会详细讲：这是范畴上的事，不是能力上的事。

一个闭环系统不能生成自己的设定点。#strong[这套东西能保证你高效地、 可靠地、可验证地把一件事做完 ------ 它完全不能保证那件事值得做。]

而且它有一个放大效应：#strong[执行效率越高，选错方向的代价越大。]

=== 三、不承诺覆盖到工具链自己
<sec-not-toolchain>
这是目前最大的缺口，而且它是自曝的。

三层判定全都作用在#strong[代码]上。而生产这些判定的工具链 ------ 那 28 条定时任务、近四个月 18 万次执行 ------ #strong[没有任何一层判定在管它们。]

具体的后果：一个空指针崩溃挂了四个月，没有人发现， 因为它坏了不产生任何可见后果。

#ref(<sec-observer>, supplement: [章节]) 会讲这个缺口该怎么补。这里只需要记住这句话， 因为它是全书的枢纽：

#quote(block: true)[
#strong[判定覆盖到哪里，确定性就只到哪里。]
]

== 一个承诺的强度取决于它的证据
<sec-promise-strength>
"我们承诺 X"这句话的含金量，完全取决于后半句"靠什么证据"。

同一个承诺，可以有四种强度：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([强度], [证据], [例子],),
  table.hline(),
  [#strong[希望]], [无], ["我们要求大家写测试"],
  [#strong[约定]], [人的评审], ["评审时会看有没有测试"],
  [#strong[判定]], [一条自动检查], ["覆盖率低于阈值不给合并"],
  [#strong[结构]], [做不到的事], ["没有测试宿主的目标编译不过"],
)
#strong[从上往下，每一层的成本更高，可靠性也更高。]

而最要紧的是第一层和第二层的区别 ------ 它们经常被混为一谈。

"我们要求大家写测试"和"评审时会看"的差别不是态度问题， 是#strong[有没有一个具体的时刻，有一个具体的人，会去做一个具体的检查。] 没有这三样，它就是希望，不是承诺。

#strong[而在 Agent 场景下，第二层（人的评审）的可靠性大幅下降] ------ 因为审查队列会爆，而且 Agent 不会因为上次被指出而记住 （#ref(<sec-rule-present>, supplement: [第])）。这就是为什么这本书的重心在第三层和第四层。

== 承诺的边界会被外部误解，除非你写下来
<sec-boundary-misread>
"不承诺同样的代码"这句话，如果不说清楚，最常见的两种误读是：

#strong[误读一：那就是说质量不可控。]

不是。#strong[判定边界完全可控，而它才是质量的定义。] 两份都通过全部判定的实现，在"这个仓库认可的质量"这个意义上是等价的 ------ 如果你觉得它们不等价，那说明#strong[你的判定边界少了一条]， 而不是说明"代码风格重要"。

这个推论很有用：#strong[每一次你觉得"这两份实现不一样， 虽然都通过了检查"，都是一次发现新规则的机会。]

#strong[误读二：那就是说没有代码规范。]

也不是。规范仍然存在 ------ 它只是从"人来执行的文档" 变成了"结构和检查"（#ref(<sec-feedforward-levels>, supplement: [第])）。

#strong[区别在于：一条无法被自动判定的规范， 在这套系统里不会被写成规范，会被写成一条评审时看的东西， 或者干脆被承认为品味。]

而把品味明确标为品味，比把它伪装成规则要好 ------ 因为规则会被 Agent 当成硬约束去满足，而满足一条品味规则的最快方式 通常是抄一段现有代码。

== 承诺的粒度
<sec-promise-granularity>
一个容易被搞错的地方：#strong[承诺应该在什么粒度上给出？]

三种粒度，各有各的问题：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([粒度], [例子], [问题],),
  table.hline(),
  [太粗], ["代码质量有保证"], [无法证伪，无法验收],
  [#strong[合适]], ["行为能被测试观察"], [可以逐条给出证据],
  [太细], ["每个函数覆盖率高于 95%"], [#strong[把手段当成了承诺]],
)
#strong[第三行的问题最隐蔽。]

覆盖率是一个手段，不是一个承诺。把它当成承诺，会发生两件事：

#strong[一、它会被优化，而不是被满足。] #ref(<sec-coverage-devalued>, supplement: [第]) 讲过，提高覆盖率有一条不经过"验证行为"的捷径。 一旦覆盖率本身成了承诺，走捷径就成了合理行为。

#strong[二、手段变了之后，承诺就没了。] 如果哪天你换了一种更好的验证方式（比如以变异验证为主 ------ 拿掉修复， 测试必须重新变红，见 #ref(<sec-mutation>, supplement: [第])）， 那个以覆盖率表述的承诺就无法迁移。

#strong[正确的粒度是"要达到什么"，不是"用什么达到"。]

而这条在实践中有一个测试：#strong[把你的承诺里所有的工具名、指标名、 阈值都删掉，它还剩下什么？] 剩下的那部分才是真正的承诺。

== 判定边界会随时间变化，而这没问题
<sec-boundary-evolves>
最后一点。这本书讲的五条边界不是固定的。

#ref(<sec-rule-lifecycle>, supplement: [章节]) 讲的整个机制，就是边界演化的机制： 新的失败方式出现 → 变成新的判定 → 边界扩大了一点。

#strong[而这意味着"同样的判定边界"这个承诺， 严格说是"同一时刻的同样边界"。]

这不是文字游戏，它有一个实际后果：

#quote(block: true)[
#strong[一个半年前通过了全部判定的改动， 今天可能通不过 ------ 而这是正常的，不是系统不一致。]
]

所以那些历史违规需要一个专门的机制来处理，而不是被当成"不合格"------ 这正是 #ref(<sec-baseline>, supplement: [第]) 那个债务台账存在的理由： #strong[它承认边界是移动的，而存量不该为边界的移动负责。]

#strong[一个不承认边界会移动的系统，只有两个选择： 永远不加新规则，或者每加一条就让存量全部变成违规。] 两个都不可持续。

== 承诺和信任的关系
<sec-promise-trust>
一个承诺的实际价值，不只取决于它有多严格， 还取决于#strong[别人相不相信它]。

而这里有一个不对称：

#quote(block: true)[
#strong[建立信任需要长时间的一致， 摧毁信任只需要一次不一致。]
]

具体到这套系统：#strong[一次假绿（测试通过但没验证任何行为，见 #ref(<sec-fake-green>, supplement: [第])）， 会让所有绿灯的可信度下降。]

不是下降一点 ------ 因为人（和 Agent）无法区分 "这次是真绿"和"这次是假绿"，所以#strong[一次假绿会让所有绿灯 的可信度按一个未知的比例打折。]

这解释了几件事：

#strong[为什么这本书对假绿如此在意]（#ref(<sec-fake-green>, supplement: [第])）------ 它损害的不是那一条测试，是整个体系的可信度。

#strong[为什么退出码三分值得那半天成本]（#ref(<sec-three-exit-codes>, supplement: [第])）------ 它防的是"Agent 因为一个不该信的红灯而改坏代码"， 而那类事件同样在消耗信任。

#strong[为什么规则的误报要被认真对待]（#ref(<sec-feedback-cost>, supplement: [第])）------ 误报消耗的是同一个池子里的信任。

== 一个承诺清单该长什么样
<sec-promise-list-shape>
给一个可以直接抄的模板：

#Skylighting(([#NormalTok("我们承诺：");],
[#NormalTok("  [承诺 1]  证据：[一条可以跑的命令 / 一个可以查的数]");],
[#NormalTok("  [承诺 2]  证据：...");],
[],
[#NormalTok("我们不承诺：");],
[#NormalTok("  [不承诺 1]  因为：[范畴上做不到 / 成本超过收益 / 还没建]");],
[#NormalTok("  [不承诺 2]  因为：...");],
[],
[#NormalTok("我们正在建（还不能承诺）：");],
[#NormalTok("  [在建 1]  预计什么时候能承诺：...");],));
#strong[第三段是最容易被省掉、也最有价值的一段。]

因为没有它，"在建的东西"会被归到前两段的某一段里 ------ 归到"承诺"里就是撒谎，归到"不承诺"里就是放弃。

#strong[而"在建"是一个真实的、常见的、应该被表达的状态。]

这和这套系统里的报数模式（#ref(<sec-enforce-levels>, supplement: [第])）是同一个思想： #strong[一个规则可以处于"已经在测量、但还不拦人"的中间状态]， 而承认这个中间状态的存在，比强行二选一要诚实得多。

== 写下你自己的那份
<sec-write-your-own>
这一章唯一的动作项：#strong[把你自己系统的判定边界列出来。]

一张两列的表：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([我承诺], [靠什么证据],),
  table.hline(),
  [], [],
)
#strong[右边一列填不出来的那行，你其实没在承诺它，你只是希望它。]

然后再写第二张表，这张更重要：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([我明确不承诺], [为什么],),
  table.hline(),
  [], [],
)
大部分团队从来没写过第二张表，于是发生两件事： #strong[外部的人以为你承诺了你没承诺的东西]， 而#strong[内部的人会花力气去优化一个本来就不在承诺范围内的指标。]

== 一个反面的承诺清单
<sec-bad-promise-list>
给一份常见但有问题的承诺清单，逐条指出问题所在：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([常见的承诺], [问题],),
  table.hline(),
  ["代码质量有保证"], [无法证伪（#ref(<sec-promise-granularity>, supplement: [第])）],
  ["所有代码都经过审查"], [#strong[审查了不等于审出问题了]],
  ["覆盖率高于 80%"], [把手段当承诺],
  ["CI 通过才能合并"], [#strong[没说 CI 检查了什么]],
  ["遵循团队规范"], [规范如果没有可执行的部分，这句话没有内容],
)
#strong[第二行和第四行的问题是同一个：它们承诺的是一个流程发生了， 而不是一个性质成立了。]

流程发生了很容易验证（有审查记录、CI 是绿的）， 而这正是它们受欢迎的原因 ------ #strong[但它们和质量之间的联系没有被建立。]

#strong[改写成有内容的版本：]

- "所有代码都经过审查" → "#strong[每次改动的结构、依赖方向和路径不变量 都被机器验证过，需要判断的部分被人看过]"
- "CI 通过才能合并" → "#strong[CI 验证了行为、结构和路径不变量三类事实， 而且它自己有自检]"

#strong[改写之后的版本更长、更笨拙，但它们可以被检验] ------ 而一个可以被检验的承诺，才是承诺。

== 为什么这一章排在第一部
<sec-why-chapter-three>
"承诺什么"看起来像一个总结性的话题， 但它排在第一部的最后，理由是：

#quote(block: true)[
#strong[承诺清单决定了后面三部要建什么。]
]

具体地说，#ref(<sec-same-boundary>, supplement: [第]) 那五条边界， #strong[一一对应后面的章节]：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([边界], [它在哪一章被兑现],),
  table.hline(),
  [行为能被测试观察], [#ref(<sec-tests>, supplement: [章节])],
  [结构符合架构约定], [#ref(<sec-guardrails>, supplement: [章节])],
  [改动尊重 owner 与不变量], [#ref(<sec-arbiter>, supplement: [章节])],
  [高风险动作保持显式], [#ref(<sec-risk-distribution>, supplement: [第])],
  [失败能定位、修复能复验], [#ref(<sec-three-failures>, supplement: [章节])],
)
#strong[所以这一章不是总结，是提纲。]

而它排在第一部还有第二个理由：#strong[先写下承诺， 再建系统，顺序不能反。]

一个先建系统再总结承诺的团队， #strong[它的承诺会是它已经做到的那些] ------ 而那意味着承诺清单失去了它的主要功能：#strong[指出还缺什么。]

#ref(<sec-three-non-promises>, supplement: [第]) 那三条明确的"不承诺" 就是这个功能的产物 ------ 其中第三条 （不承诺覆盖到工具链自己）#strong[指向的正是这套系统 现在最大的缺口]（#ref(<sec-observer>, supplement: [章节])）。

#strong[如果承诺是事后总结的，那一条不会出现在清单里 ------ 因为总结的人不会主动写下自己没做到的东西。]

= 七个形状
<七个形状>
= 七个形状
<sec-seven-shapes>
这一章是全书的骨架。后面每一章都会回指这里的形状编号。

== 为什么按形状组织，而不是按事故
<sec-why-shapes>
一次事故是一个点。

你的系统里没有这本书里提到的那些具体组件 ------ 没有那套构建系统、 没有那个日志聚合器、没有那个测试框架。所以"某个日志组件的保留期 配了但和容量不匹配"这件事，对你#strong[完全没有用]。

#strong[但四个不同的层上出现同一个形状，就成了可迁移的知识] ------ 因为你的系统里一定有那个形状，只是穿着别的衣服。

所以这一章不讲事故，讲#strong[形状]：一类失败的骨架， 剥掉了所有具体的组件名字之后剩下的那个东西。

七个形状，来自四十多次真实故障和二十多条被沉淀下来的规则。 而它们有一个共同点值得先说：#strong[七个里有五个的失败形态是"静默"的] ------ 系统不会告诉你它坏了，因为#strong[按它自己的标准，它没坏。]

这就是为什么这本书的重心是"判定"而不是"修复"。

== 形状 A · 探针测的不是你以为的东西
<sec-shape-a>
#strong[全书最重要的形状。]

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([层], [现象], [探针实际测的], [你以为它测的],),
  table.hline(),
  [运维], [健康检查返 200，登录返 500], [#strong[读路径]], [服务可用],
  [构建], [过滤器给裸方法名，0 个用例，报通过], [构建目标跑完了], [用例通过了],
  [构建], [界面测试缺可执行宿主], [编译成功], [用例执行了],
  [测试], [无条件跳过], [测试文件还在], [场景被覆盖],
  [定时任务], [自动刷新崩溃四个月，构建全绿], [#strong[什么都没测]], [组件健康],
)
第一行值得展开，因为它最不像软件问题、也因此最能说明形状的普适性：

一个监控服务的健康检查返回 200，而用户登录返回 500。 两个结果都是真的。原因是#strong[磁盘满了] ------ 进程还活着、能读配置、 能响应健康检查，但#strong[写不进去]。而健康检查只走了读路径。

#strong[通用形态]：

#quote(block: true)[
#strong[探针和被测对象之间，存在一条未被验证的因果假设。]
]

- 健康检查假设：#strong[能读 ⇒ 能写]
- 构建报告假设：#strong[任务跑完 ⇒ 用例跑过]
- 测试文件存在假设：#strong[代码在 ⇒ 行为被覆盖]

假设不成立的那天，探针不会告诉你 ------ #strong[因为探针本身没坏。]

#strong[它主要在哪讲]：#ref(<sec-fake-green>, supplement: [第]) · #ref(<sec-sensor-faults>, supplement: [章节])

== 形状 B · 同一份状态有两个写者
<sec-shape-b>
#strong[出现次数最多的形状。] 这套系统里超过一半的路径不变量在回答这一个问题。

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([层], [现象], [两个写者是谁],),
  table.hline(),
  [音频], [录音后播放静默失败], [多方各自配置音频会话，互不知晓],
  [构建], [并发任务同时崩溃], [同节点多进程共享一个输出根],
  [测试], [偶发段错误], [一个#strong[无锁的共享测试替身]],
  [后端], [用户身份串号], [空邮箱被当成同一个身份],
  [数据], [服务端退款一行不进报表], [一端写大写、一端写小写、过滤器比小写],
  [计费], [购买恢复卡死], [注入了统一服务却仍直读系统接口],
)
#strong[通用形态]：

#quote(block: true)[
#strong[写入权没有被显式收敛，于是它被隐式地分给了所有能写的人。]
]

而排查困难在于：#strong[每个写者单独看都是对的，各自的测试也都是绿的。]

倒数第二行是这个形状最漂亮的实例。三方 ------ 服务端、客户端、 数据管道 ------ #strong[各自都有测试，各自都通过]。而服务端的退款 一行都进不了任何报表，因为大小写不一致， 而下游的过滤是等值比较。#strong[现场看起来是"数据管道没开"， 而原始表说它开着。]

#strong[它主要在哪讲]：#ref(<sec-architecture>, supplement: [章节]) · #ref(<sec-ownership-pattern>, supplement: [第])

== 形状 C · 修了实例，没修机制
<sec-shape-c>
#strong[全书最诚实的一节，因为它的主要证据来自这套系统自己。]

演进纪律写得很清楚：同一个问题出现第二次，就该把机制上移。 而在磁盘容量这件事上，#strong[它重复了五次]：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([表象], [那次的根因], [那次的修法],),
  table.hline(),
  [登录 500], [磁盘满导致缓存文件损坏], [清盘],
  [CI 任务失败], [容器磁盘耗尽], [清盘],
  [全站 500], [日志插件缓存撑满], [清盘],
  [监控机满], [日志没有保留期], [#strong[配保留期]],
  [监控机#strong[又]满], [#strong[保留期配了，但与容量不匹配]], [调参],
  [代理机满], [容器日志], [清盘],
  [分析平台满], [快照没有自动清理，880G], [清盘],
)
真正的机制上移 ------ #strong[任何分区的水位告警] ------ 到第五次才被提出来， 而那次的记录里写着"没有磁盘水位告警，潜伏 5 天"。

#strong[这不是打脸。这一节要说的是：]

#quote(block: true)[
#strong[知道原则和执行原则之间隔着注意力，而注意力是有限的。]
]

同一个人，在代码这一侧把"第二次就上移"执行得极其彻底， 在基础设施那一侧执行得很差。#strong[区别不在认知 ------ 认知是同一个人的。 区别在哪一侧有判定覆盖。]

#strong[它主要在哪讲]：#ref(<sec-rule-lifecycle>, supplement: [章节]) · #ref(<sec-observer>, supplement: [章节])

== 形状 D · 配置声明了，但从未生效
<sec-shape-d>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([现象], [声明了什么], [实际发生了什么],),
  table.hline(),
  [资源配额从未生效], [配额], [#strong[配置格式的子表解析吞掉了整段]],
  [保留期配了仍累积], [168 小时保留], [清理速度跟不上写入速度],
  [停用一个环境导致监控全断], [路由文件], [路由文件未被发现],
  [5 条工作流从未运行], [注册表条目], [#strong[注册 ≠ 在跑]],
)
#strong[通用形态]：

#quote(block: true)[
#strong[声明与生效之间缺一层判定。]
]

而最极端的一个变体记在某份策略文件的注释里： #strong[这份清单的文件名不能以某个前缀开头]， 因为版本控制的忽略规则里有一条未锚定的通配 ------ 一旦文件名以它开头，#strong[这份策略对版本控制就直接隐形了]。 规则还在文件里写着，在本地跑也正常，但它根本没被提交。

这不是"配置没生效"，是#strong["配置根本不存在，但你在本地看得见它"。]

#strong[它主要在哪讲]：#ref(<sec-observer>, supplement: [章节]) · #ref(<sec-raw-validated>, supplement: [第])

== 形状 E · 边界处的静默降级
<sec-shape-e>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([层], [现象], [边界], [语义变了什么],),
  table.hline(),
  [网络], [#strong[所有按 IP 的限流塌成一个桶]], [边缘节点], [转发头的右端是代理不是用户],
  [网络], [SSH 连不上], [云厂商边界], [数据包根本不到主机],
  [路由], [内部登录 404], [反向代理], [请求被误路由到另一个服务],
  [埋点], [依赖页面浏览的功能永不触发], [模拟器], [被判非生产环境，事件不发],
)
第一行是全书最好的素材之一。

按 IP 的限流是某个功能唯一的防刷闸。因为代理链路的右端是边缘节点 而不是用户，#strong[所有请求被算成同一个 IP，于是全世界共用一个配额。]

而关键在于：#strong[功能看起来完全正常。限流也确实在工作。] 你去看代码，逻辑是对的；去看日志，限流在触发； 去看监控，请求量正常。#strong[唯一的问题是这个闸门实际上不存在。]

#strong[通用形态]：请求穿过一层边界之后语义变了，而#strong[两侧各自都"正常"]。

#strong[它主要在哪讲]：#ref(<sec-tool-illusion>, supplement: [第]) · #ref(<sec-where-uncertainty-lives>, supplement: [章节])

== 形状 F · 资源无界增长
<sec-shape-f>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([现象], [无界的是什么], [撞上的墙],),
  table.hline(),
  [执行机无法创建进程], [僵尸进程 + 模拟器残留], [进程数],
  [端口耗尽], [30 天的孤儿进程], [连接回收],
  [#strong[一个产品吃掉全部 CI 机器]], [自定义的测试目标名], [CI 并发],
  [代理被系统杀掉], [内存], [全站不可用],
  [分析平台磁盘满], [快照，880G], [磁盘],
)
第三行和别的不一样，值得单独说：#strong[它的"资源"是构建图上的目标数。]

按功能拆测试 bundle 曾把 8 个产品拆成 30 个目标， 而每个目标是一个独占的 CI 任务，再乘系统版本矩阵 ------ #strong[一次共享层改动就要 43 个任务去抢 5 台机器。]

#strong[一个看起来只是"组织方式"的决定，在构建图上是一个无界的资源申请。]

#strong[它主要在哪讲]：#ref(<sec-gain-and-delay>, supplement: [章节]) · #ref(<sec-ui-test-wrapper>, supplement: [第])

== 形状 G · 本地与远端跑的不是同一件事
<sec-shape-g>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([差异源], [具体表现],),
  table.hline(),
  [#strong[并发争用]], [模拟器互相抢资源（最常见）],
  [覆盖率插桩], [改代码生成，翻出只在插桩下崩的问题],
  [环境包装], [语言环境默认值],
  [版本漂移], [CI 的系统更新，界面层级结构随之变化],
  [工具链缺件], [某个编译器组件在新版本里缺失],
  [#strong[手工操作]], [面板全丢：手动启动容器时漏了网络参数、卷挂错],
)
最后一行是唯一一个和"环境差异"无关的： 它是#strong[一次手工操作和一次自动化操作的差异]。

而它的教训和其余五行是同一条：

#quote(block: true)[
#strong[本机绿是必要条件，不是充分条件。]
]

#strong[它主要在哪讲]：#ref(<sec-local-vs-ci>, supplement: [第]) · #ref(<sec-policy-mechanism>, supplement: [第])

== 怎么在自己的系统里找形状
<sec-find-your-shapes>
这一章的价值不在于记住七个名字，在于#strong[能在自己的系统里指认出实例]。

四个可以立刻用的探针：

=== 探针一：找形状 A ------ 问每一道检查"它坏了会怎样"
<sec-probe-a>
#quote(block: true)[
#strong[如果这道检查自己坏了，它会表现成通过还是失败？]
]

答案是"通过"的每一处，都是形状 A 的一个候选。

具体做法：把你的检查列出来，对每一道设想"它测的那个东西 完全失效了，但检查本身没坏"。健康检查还能返回 200 吗？ 测试套件还会报绿吗？

=== 探针二：找形状 B ------ 搜索"配置"和"初始化"
<sec-probe-b>
任何一个可以被多处设置的全局状态，都是形状 B 的候选。 典型的搜索词：设置某某模式、初始化某某、注册某某。

判据：#strong[如果两个地方都调用了它，谁最后调用谁赢吗？] 如果是，你有两个写者。

=== 探针三：找形状 C ------ 翻你的故障记录
<sec-probe-c>
按#strong[表象]分组是没用的（表象每次都不一样）。 按#strong[根因所在的组件]分组。

#quote(block: true)[
#strong[同一个组件出现三次以上，就说明那里该有一个机制而不是三次修复。]
]

这个探针的成本几乎为零 ------ 你的工单系统或者聊天记录里就有数据。 而它通常会给出一个让人意外的结果：#strong[最常出问题的那个组件， 往往不是大家以为的那个。]

=== 探针四：找形状 D ------ 对每一份配置问"怎么证明它生效了"
<sec-probe-d>
不是"它写对了吗"，是"#strong[有什么可观测的东西能证明它在起作用]"。

答不上来的每一份配置，都可能已经失效了很久。

== 形状之间的关系
<sec-shape-relations>
七个形状不是并列的，它们之间有结构：

#strong[A 是其余六个的放大器。] 每一个形状如果被及时发现，代价都是有限的。 而形状 A 让它们#strong[不被发现] ------ 形状 C 的五次重复之所以能发生， 正是因为没有任何探针在测分区水位（形状 A 的缺失版本）。

#strong[B 和 D 是同一件事的两面。] B 是"两个写者"，D 是"零个写者"（声明了但没人执行）。 两者的共同根源都是：#strong[写入权没有被显式地指定给某一个地方。]

#strong[E 和 G 都是"边界两侧不一样"。] E 是空间上的（请求穿过一层边界），G 是环境上的（本机 vs 远端）。 两者的排查方法也相同：#strong[找出那个边界，然后分别测两侧。]

#strong[F 是唯一一个纯粹的量的问题] ------ 而它也因此是最容易被机械检测的： 任何一个"只增不减"的量，都需要一个上界和一个#strong[观测器] （用模型加上你能测到的量，去估计你测不到的状态，见 #ref(<sec-not-more-sensors>, supplement: [第])）。

#strong[这个结构有一个实际用处]：当你发现一个形状的实例时， 去看它相邻的形状 ------ 通常那里还有一个。

== 形状不是分类，是诊断工具
<sec-shapes-as-diagnostic>
这七个形状不构成一个分类体系 ------ 它们会重叠， 一次真实的故障经常同时是两三个形状。

#strong[这不是缺陷，因为它们的用途不是归档，是诊断。]

一个诊断工具的好坏，看的是它能不能缩小搜索空间。 而形状做的正是这件事：当你面对一个"看起来没问题但就是不对"的系统时， 七个形状给了你七个具体的地方去看，而不是一片茫然。

用一次真实的排查演示这个过程：

#strong[现象]：某个功能上线后，数据看板上完全没有它的数据。

#strong[逐个形状问一遍：]

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([形状], [问题], [这次的答案],),
  table.hline(),
  [A 探针测错], [看板测的是我以为的那个量吗？], [待查],
  [B 两个写者], [有没有第二个地方在写这个数据？], [待查],
  [C 修了实例], [这类问题以前出现过吗？], [没有],
  [D 声明未生效], [埋点声明了但没生效？], [#strong[可能]],
  [E 边界降级], [数据穿过了哪些边界？], [#strong[可能]],
  [F 资源无界], [有没有东西被丢弃了？], [#strong[可能（队列满）]],
  [G 本地≠远端], [本地能看到数据吗？], [#strong[关键问题]],
)
#strong[七个问题里有四个指向了具体的检查动作]， 而其中"本地能看到数据吗"这个问题最便宜 ------ 应该先做它。

#strong[这就是形状的实际价值：它把"到处找"变成了一个有序的检查清单。]

而这个清单的顺序应该按#strong[检查成本]排，不是按可能性排 ------ 因为在一次排查里，你不知道可能性，但你知道成本。

== 为什么是七个
<sec-why-seven>
不是刻意凑的，但也不是穷尽的。

这七个是从四十多次故障和二十多条规则里归纳出来的， 而归纳的标准只有一条：#strong[它至少在三个不同的层上出现过。]

只在一个层上出现过的模式没有进这张表，因为它们大概率是 那个层的特定问题，不是可迁移的形状。

#strong[所以这张表的完整性是有限的]，而且它偏向于这个系统撞过的那些墙。 一个不同类型的系统（比如高并发的交易系统、或者一个数据密集的批处理管线） 大概率会有它自己的第八、第九个形状。

#strong[用法不是"记住这七个"，是"照着这个方法找出你自己的那几个"] ------ 翻你的故障记录，按根因所在的组件分组， 找出那些在三个以上不同的地方出现过的模式。

那才是你自己的形状表，而它比这七个更有用。

== 每个形状的最小防线
<sec-minimal-defenses>
如果每个形状只能建一道防线，建哪一道？

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([形状], [最小防线], [成本],),
  table.hline(),
  [A 探针测错], [#strong[断言探针的"工作量"不为零]（执行数、扫描数、处理条数）], [半小时],
  [B 两个写者], [给每份关键的可变状态#strong[显式指定一个 owner]，写在代码里], [一天],
  [C 修了实例], [故障记录#strong[按根因组件分组]，出现三次就上机制], [每次半小时],
  [D 声明未生效], [每份配置配一条#strong["它生效了"的断言]], [每份十分钟],
  [E 边界降级], [在每层边界的两侧#strong[分别测一次同一个量]], [每层一小时],
  [F 资源无界], [给每个只增不减的量配一个#strong[上界和告警]], [每个十分钟],
  [G 本地≠远端], [#strong[让本地和 CI 跑同一条命令]], [半天到几天],
)
#strong[七道防线，总成本大概三到五天。]

而它们的共同特点是：#strong[每一道都是"加一个测量"， 而不是"改一段逻辑"。] 这是这本书全部内容的缩影 ------ 判定先于修复。

== 三个形状会连锁
<sec-shape-chains>
有三条常见的连锁路径，值得单独记：

=== 链条一：D → A → C
<sec-chain-dac>
配置声明了但没生效（D）→ 没有任何东西测量它（A）→ 于是同类问题反复出现，每次都在症状点修（C）。

#strong[磁盘那五次就是这条链。] 而它的入口是 D： 第一次的修复（配保留期）本身就是一个"声明了但没验证生效"的动作。

=== 链条二：F → E
<sec-chain-fe>
某个资源无界增长（F）→ 到达上限后开始丢弃 → 而丢弃发生在某层边界上，两侧看起来都正常（E）。

#strong[队列积压导致的数据丢失几乎总是这条链。]

=== 链条三：B → G
<sec-chain-bg>
同一份状态有两个写者（B）→ 而两个写者在本地和 CI 上的 执行顺序不同 → 表现为"只在 CI 上失败"（G）。

#strong[大部分"诡异的 CI flake"是这条链]，而它经常被误诊成 "CI 环境的问题"，然后靠重试掩盖过去。

#strong[知道链条的用处]：当你确认了一个形状之后， #strong[去它的上下游看看] ------ 通常那里还有一个， 而且修上游比修下游便宜。

== 形状 A 的四个变体
<sec-shape-a-variants>
形状 A 出现得太频繁，值得把它的内部结构拆开。 四个变体，#strong[排查方法完全不同]：

=== 变体一：探针测的是另一个量
<sec-variant-wrong-quantity>
健康检查测读路径，你以为它测服务可用性。

#strong[特征]：探针本身完全正常，它一直在正确地测量它测量的那个东西。 #strong[排查]：写下"它实际测什么"和"你想知道什么"，对比两句话。 #strong[这是四个变体里唯一无法用机制解决的] ------ 它需要一次人的检查。

=== 变体二：探针没有执行
<sec-variant-not-run>
零个用例、缺可执行宿主、任务被跳过。

#strong[特征]：探针的"工作量"为零。 #strong[排查]：断言工作量不为零（执行数、扫描数、处理条数）。 #strong[这是最容易机制化的一个变体]，而它也最常见。

=== 变体三：探针执行了但覆盖面缩小了
<sec-variant-shrunk>
规则的匹配范围因为重构而变小（#ref(<sec-death-drift>, supplement: [第])）。

#strong[特征]：工作量非零，但比应该的小。 #strong[排查]：把工作量记成时间序列，看变化率。

=== 变体四：探针失效但仍在输出
<sec-variant-zombie>
一条从来不会失败的测试。

#strong[特征]：工作量正常，输出正常，#strong[但它没有失败的能力]。 #strong[排查]：主动注入已知故障（变异验证、机内自检）。

=== 四个变体的排查成本
<sec-variant-cost>
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([变体], [检测方式], [成本], [能否自动化],),
  table.hline(),
  [测错量], [人工对照], [中], [#strong[不能]],
  [没执行], [断言工作量非零], [#strong[极低]], [能],
  [覆盖缩小], [工作量的时间序列], [低], [能],
  [失效但输出], [主动注入故障], [中], [部分],
)
#strong[从上往下看，第二行的成本最低而收益最高 ------ 这就是为什么"断言测试执行数不为零"是全书投入产出比最高的一条建议。]

== 形状与这本书的结构
<sec-shapes-and-structure>
最后说明这七个形状和后面各部的关系，因为它决定了怎么读：

#strong[第二部（环境）主要防形状 B、E、F] ------ 它们的共同点是"结构性的错误"，可以通过让错误的结构无法表达来消除。

#strong[第三部（判定）主要防形状 A、G] ------ 它们的共同点是"测量的问题"，需要对测量本身施加检查。

#strong[第四部（回路）主要防形状 C、D] ------ 它们的共同点是"缺乏#strong[可观测性]"（#ref(<sec-observability>, supplement: [第])）------ 需要建立观测器和反馈。

#strong[七个形状，三部书，一一对应。]

而如果你只关心某一个形状，可以直接跳到对应的那一部 ------ 这本书的章节之间有引用，但没有强依赖。

== 一个形状为什么值得被命名
<sec-why-name>
给一类现象起一个名字，看起来只是修辞。它不是。

#strong[名字改变的是"这件事能不能被讨论"。]

三个具体的效果：

#strong[一、名字让类比成为可能。]

在有"形状 A"这个名字之前，"健康检查只测读路径" 和"测试跑了零个用例"是两件毫不相干的事。 有了名字之后，它们是同一件事的两个实例 ------ #strong[而这意味着解决其中一个的方法，可能适用于另一个。]

#strong[二、名字让"我们以前遇到过这个"变成可查的。]

一份故障记录如果只按表象归档， 那么"磁盘满"和"登录 500"是两个条目。 按形状归档，它们是同一条（#ref(<sec-probe-c>, supplement: [第])）。

#strong[三、名字让预测成为可能。]

#ref(<sec-shape-chains>, supplement: [第]) 那三条连锁 ------ 没有名字就写不出来， 因为你没法说"D 会导致 A"如果 D 和 A 都还没有名字。

== 但名字也有它的风险
<sec-naming-risk>
诚实地说一句：#strong[一套分类会让人只看见分类里的东西。]

七个形状是从一个特定系统的失败里归纳的 （#ref(<sec-why-seven>, supplement: [第])），所以它偏向于那个系统撞过的墙。

#strong[而一个不同的系统会有它自己的第八、第九个形状] ------ 如果读者只用这七个去套，就会漏掉它们。

#strong[所以这一章最后那句"照着这个方法找出你自己的那几个" 不是客气话，是这一章唯一真正重要的建议。]

而"这个方法"具体是三步：

#Skylighting(([#NormalTok("① 翻你的故障记录");],
[#NormalTok("② 按根因所在的组件（不是表象）分组");],
[#NormalTok("③ 找出在三个以上不同层出现过的模式");],));
#strong[第②步是关键，也是最容易做错的一步] ------ 因为故障记录天然是按表象写的（那是发现它时的样子）， 而按表象分组会把同一个形状的实例分散到七八个类别里。

== 形状 B 为什么出现得最多
<sec-why-b-most>
#ref(<sec-distribution-meaning>, supplement: [第]) 那个统计显示： 整个规则体系里超过 40% 在回答"这块状态归谁写"。

#strong[这个比例值得解释，因为它不是偶然。]

三个原因，每一个都在 Agent 场景下被放大：

#strong[一、写入权是隐式分配的默认状态。]

一个新加的模块，如果没有人显式规定"这块状态只能由 X 写"， 那么#strong[它的写入权默认属于所有能访问它的地方。]

而"能访问"通常是宽松的 ------ 一个全局单例、一个公开的属性、 一个系统 API。#strong[所以形状 B 是默认发生的，不是需要被制造的。]

#strong[二、每个写者单独看都是对的。]

这是它最难被发现的原因。A 模块设置音频会话的代码是对的， B 模块的也是对的，#strong[它们各自的测试也都是绿的。]

#strong[问题只在它们同时存在时出现，而没有任何一方的视角能看到这一点。]

#strong[三、并行的 Agent 让它更容易发生。]

几十个 Agent 同时工作，它们#strong[看不到对方在改什么] （#ref(<sec-parallel-coordination>, supplement: [第])）。人的团队里， "我在改这块你别动"这类沟通拦下了一部分； #strong[而 Agent 之间没有这个机制。]

#strong[所以这个形状不只是最常见的，它还是唯一一个 会因为 Agent 规模化而变得更常见的。]

== 形状表的一个用法：事后复盘的模板
<sec-postmortem-template>
每次故障之后，用七个形状过一遍，产出一份结构化的复盘：

#Skylighting(([#NormalTok("这次故障是哪个（哪些）形状？");],
[#NormalTok("  → 如果找不到匹配的，可能是你的第八个形状，记下来");],
[],
[#NormalTok("同一个形状，在别的层还有实例吗？");],
[#NormalTok("  → 这个问题通常能挖出一到两个还没爆的");],
[],
[#NormalTok("这个形状的最小防线是什么（@sec-minimal-defenses）？");],
[#NormalTok("  → 建它，成本通常是半小时到一天");],
[],
[#NormalTok("有没有连锁（@sec-shape-chains）？");],
[#NormalTok("  → 上游还有一个的话，修上游更便宜");],));
#strong[四个问题，十五分钟，而它的产出比一份自由格式的复盘可行动得多。]

因为自由格式的复盘会停在"根因是 X，我们修了 X"， #strong[而这四个问题会把它推到"这一类问题的防线在哪"。]

而这正是 #ref(<sec-shape-c>, supplement: [第]) 那个形状要防的东西 ------ #strong[修了实例，没修机制。]

== 七个形状的共同点
<sec-shapes-common>
把七个放在一起，有三件事值得注意。

#strong[第一，五个是静默的。]

A（探针测错）、C（修了实例）、D（配置未生效）、E（边界降级）、 F 的一部分 ------ 这些失败发生的时候，#strong[系统不会告诉你]， 因为按它自己的标准，它没坏。

只有 B 和 G 会主动表现出来（崩溃、测试红）， #strong[而这正是它们通常被更快修好的原因。]

#strong[第二，它们在层与层之间高度同构。]

同一个形状会出现在网络层、构建层、测试层、业务层。 这意味着#strong[在一层学到的教训可以直接迁移到另一层] ------ 一个知道"健康检查只测了读路径"的人， 更容易看出"这个测试只测了构造函数"。

#strong[第三，它们全都是"判定"的问题，不是"实现"的问题。]

七个形状里没有一个是"代码写错了"。它们全都是 #strong["我们以为我们知道，但我们不知道"] ------ 测量错了、覆盖漏了、机制没上移、配置没生效、语义变了、 资源没有界、环境不一样。

#strong[所以这本书的其余部分讲的是怎么建立可信的判定， 而不是怎么写出正确的代码。]

== 七个形状按"发现成本"排序
<sec-shapes-by-cost>
最后给一个实用的排序 ------ 按"发现它需要多大力气"， 因为这决定了你该先查哪个：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([形状], [发现成本], [为什么],),
  table.hline(),
  [B 两个写者], [#strong[低]], [通常会崩溃或产生错误数据],
  [G 本地≠远端], [#strong[低]], [有明确的对照（本地 vs CI）],
  [F 资源无界], [低], [撞上限时会有明确的错误],
  [E 边界降级], [中], [需要在边界两侧分别测],
  [D 声明未生效], [中], [需要主动验证"它生效了"],
  [C 修了实例], [#strong[高]], [需要跨越多次故障才能看出模式],
  [#strong[A 探针测错]], [#strong[最高]], [#strong[它的全部表现就是一片绿色]],
)
#strong[排序和重要性正好相反。]

A 最难发现，而它是最重要的（#ref(<sec-shapes-common>, supplement: [第]) 里 "它是其余六个的放大器"）。

#strong[所以正确的投入顺序不是按重要性，而是按"发现成本 ÷ 收益"] ------ 而 A 的最小防线（断言探针的工作量不为零）恰好成本极低， #strong[这就是为什么它排在所有建议的第一位。]

== 一个形状表的使用示范
<sec-shapes-walkthrough>
用一个假想但典型的场景，完整走一遍这张表怎么用。

#strong[场景]：你们的部署流水线有一步是"等服务健康后继续"。 最近开始偶发地在这一步之后失败，但重跑就好了。

#strong[逐个形状问：]

#strong[A（探针测错）]：那个健康检查测的是什么？ 如果它测的是"进程起来了"而不是"能处理请求了"， #strong[那么"健康"和"可以继续"之间有一条未被验证的假设。] → #strong[高度可疑。]

#strong[B（两个写者）]：这一步之后有没有两个地方在写同一份状态？ → 待查，但没有明显迹象。

#strong[C（修了实例）]：这类问题以前出现过吗？ → 如果出现过而且每次都是"重跑一下"， #strong[那么真正的问题从来没被修过。]

#strong[D（声明未生效）]：那个"等待"的超时配置生效了吗？ → 值得花两分钟验证，因为验证成本极低。

#strong[E（边界降级）]：健康检查和真实请求走的是同一条路径吗？ 如果健康检查走内网直连而真实请求走代理， #strong[两者测的不是同一个东西。] → #strong[高度可疑。]

#strong[F（资源无界）]：有没有连接池、队列之类的东西在这时候还没准备好？ → 待查。

#strong[G（本地≠远端）]：本地能复现吗？ → #strong[最便宜的检查，应该第一个做。]

#strong[结论]：七个问题里，A 和 E 高度可疑，G 最便宜。 #strong[顺序：先做 G（几分钟），再查 A 和 E（各半小时）。]

而如果 A 或 E 命中了，#ref(<sec-shape-chains>, supplement: [第]) 提示去看 #strong[它的上游有没有 D] ------ 通常"健康检查测错了" 的背后是"健康检查的配置从来没被验证过"。

#strong[十五分钟的结构化排查，替代了一次漫无目的的"到处看看"。]

== 这七个形状和"AI 特有问题"的关系
<sec-not-ai-specific>
一个可能的疑问：#strong[这七个形状里， 有几个是 Agent 场景特有的？]

#strong[严格说，一个都不是。] 它们全都在人的团队里也存在， 而且存在了几十年。

#strong[但有三个在 Agent 场景下被显著放大：]

#strong[形状 A（探针测错）] ------ 因为 Agent 的工作循环 把"检查通过"当作终止条件（#ref(<sec-agent-stops-here>, supplement: [第])）， 而人会有一些说不清的怀疑。

#strong[形状 B（两个写者）] ------ 因为并行的 Agent 之间 没有任何非正式的协调（#ref(<sec-parallel-coordination>, supplement: [第])）， 而人的团队里那部分工作由沟通承担。

#strong[形状 C（修了实例）] ------ 因为 Agent 不积累 （#ref(<sec-rule-present>, supplement: [第])）。一个人修过三次同一类问题， 第四次会说"这个我们该从根上解决了"； #strong[而 Agent 每次都是第一次。]

=== 而这有一个重要的推论
<sec-implication>
#strong[这本书讲的东西，大部分对纯人类团队也有效] ------ 它们只是在 Agent 场景下从"有用"变成了"必需"。

#strong[所以如果你的团队还没有大规模用 Agent， 这本书仍然可读] ------ 只是那些"必须"可以读成"值得"。

而反过来说：#strong[如果你的团队在用 Agent 之后 突然发现一批以前没有的问题，那大概率不是新问题] ------ 是原本被人的积累和沟通兜住的老问题，现在没人兜了。

#strong[这个认识很实用]，因为它意味着： 解法通常也不是新的 ------ 而是把原本隐式的东西显式化。

#part[第二部 · 环境]
= 环境为什么先于检查
<环境为什么先于检查>
= 环境为什么先于检查
<sec-environment-first>
这一部讲四块环境。在进入具体内容之前，得先回答一个问题： #strong[为什么是环境先，而不是检查先？]

这个问题不是排版顺序问题。它决定你把有限的投入放在哪一侧， 而两侧的回报率不一样 ------ 差得还不是一点。

== 一个把因果讲反了的说法
<sec-wrong-causality>
这套东西最初被叫做「三层基建」，指的是测试、结构检查和路径不变量。

用了一段时间之后发现这个说法把因果讲反了：

#quote(block: true)[
#strong[检查本身不产生质量，环境才产生质量；检查只是让质量变得可以确认。]
]

一个 Agent 之所以能把事情做对，主要不是因为有人在后面挑错， 而是因为#strong[它工作的地方本身就把"该怎么做"表达清楚了。]

这个自我修正值得单独说一句，因为它比结论本身更能说明问题： #strong[一个先建成、后被重新理解的系统，说明它是长出来的，不是设计出来的。] 而长出来的系统有一个特点 ------ 它的每一部分都对应过一次真实的失败， 所以里面很少有装饰。

这本书后面会再出现一次同样的修正（#ref(<sec-where-uncertainty-lives>, supplement: [章节]) 里 那个编解码器模型），形态完全一样：#strong[实践是对的，解释是后补的， 而补上正确的解释之后，能看到一些原本看不到的东西。]

== 环境靠什么把话说清楚
<sec-rule-present>
靠#strong[把规则写进结构]。

不写在文档里，写进目录层级、依赖方向、类型定义和 owner 归属。

这两种写法的区别在于#strong[生效的时刻]：

- 写在文档里的规则，#strong[要等人想起来去查才生效]
- 写进结构里的规则，#strong[在 Agent 落笔的那一刻就已经在场了]

后者不是一条需要被记住的条文，而是 #strong[Agent 一读代码就接收到的事实。]

这个区别在人的团队里也存在，但没这么致命 ------ 因为人会积累。 一个人在仓库里待了半年，那些没写下来的规矩他也知道了。

#strong[而 Agent 每次都是新来的。] 它不会积累，也不会因为上次被指出来 而在下次记得。所以一条"需要被记住"的规则， 对它来说的生效概率约等于它出现在当前上下文里的概率 ------ 而这个概率会随着上下文变长而下降。

== 四块环境，四种结构
<sec-four-structures>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([环境], [回答的问题], [它是什么的结构],),
  table.hline(),
  [Codebase], [新代码该放哪、能依赖谁？], [#strong[目录]的结构],
  [架构], [一次改动会穿过哪些层？], [#strong[依赖]的结构],
  [工作指导], [规则怎样在正确的时刻到达？], [#strong[到达时机]的结构],
  [工具链], [Agent 够得着什么？], [#strong[可达性]的结构],
)
后面四章分别讲这四种结构是怎么把规则装进去的。

#strong[第四块是最容易被漏掉的。] 前三块决定 Agent 知道什么， 第四块决定它能做什么 ------ 而这一块光靠约束长不出来， 只能靠有没有人一件一件把工具造出来。

== 一个比喻，以及它为什么不只是比喻
<sec-ground-and-walls>
#quote(block: true)[
#strong[前四块是 Agent 站的地面和它手里的工具，后三层是围着它的墙。 只有墙没有地面，Agent 会不停撞墙，却不知道该往哪走。]
]

这个比喻可以再精确一点，而精确之后它就不是比喻了。

在控制论里，一个系统对付扰动有两条路：

- #strong[前馈]：你事先知道扰动的结构，在它产生影响之前就补偿掉
- #strong[反馈]：你测量输出，发现偏差之后再修正

四块环境是#strong[前馈]。你已经知道 Agent 会往哪些方向出错 ------ 会把文件放错目录、会自己造一个日志器、会绕过配置层直接写偏好设置 ------ 所以你在它落笔之前就把这些路堵上。

三层检查是#strong[反馈]。测量它交出来的东西，不合格就退回去。

而控制论里有一条结论，它把上面那句经验之谈变成了一个可以证明的事实：

#quote(block: true)[
#strong[前馈决定性能，反馈只提供鲁棒性。]
]

一个#strong[纯反馈]的系统，性能上限由回路延迟决定，再怎么调都超不过去。

翻译成这里的语言：#strong[如果你的判定延迟是 15 分钟， 那么无论检查多严，Agent 每次犯错的成本下界就是 15 分钟] ------ 除非你在它犯错之前就拦住它。

这就是为什么同样一套检查，装在两个不同的仓库上效果会差一个数量级： #strong[检查是一样的，前馈不一样。] 一个把边界写进了目录和类型的仓库， Agent 压根走不到大部分错误路径上去；而一个只有检查的仓库， Agent 会把每一条错误路径都走一遍，每一次付一个回路延迟。

#ref(<sec-gain-and-delay>, supplement: [章节]) 会把这条结论展开，并用它解释这个仓库撞过的两堵墙。

== 那检查还有什么用
<sec-why-check-then>
前馈有一个根本限制：#strong[它只能处理你已经知道的扰动。]

你没预料到的失败方式，前馈补偿不了 ------ 因为你没有为它设计补偿。 而这类失败在 Agent 场景下不会少，因为 Agent 出错的方式和人不一样， 你的直觉不覆盖它们。

#strong[反馈的价值就在这里：它不需要你事先知道扰动是什么。] 它只需要能测量输出。

所以两者的分工是清楚的：

- #strong[前馈处理已知的失败方式] ------ 便宜、快、在错误发生前
- #strong[反馈处理未知的失败方式] ------ 贵、慢、但不需要预知

而两者之间有一条流动的路径，这本书会反复讲到： #strong[每一次反馈抓到的新失败，都是一个可以被转化成前馈的候选。]

第一次撞到"Agent 会自己造日志器"，是反馈抓到的（评审时发现）。 第二次之后，它变成一条结构检查（还是反馈，但便宜了）。 而真正的终点是把日志器的构造放进一个只有 owner 能访问的地方 ------ #strong[那时候它变成前馈，问题彻底消失。]

#ref(<sec-rule-lifecycle>, supplement: [章节]) 会讲这条路径的完整形态。

== 前馈的三个层次
<sec-feedforward-levels>
"把规则写进结构"这句话可以再分层，因为#strong[三个层次的强度差别很大]：

=== 层次一：信息在场
<sec-level-info>
规则以信息的形式出现在 Agent 的上下文里 ------ 常驻文件里的一条、路径清单里的一段。

#strong[它降低了做错的概率，但没有消除做错的可能。] Agent 仍然可以读了之后不照做（通常是因为上下文里有别的东西压过了它）。

=== 层次二：默认路径正确
<sec-level-default>
正确的做法是最省事的做法。

比如"共享的测试替身放在协议旁边的第四格"------ 如果那个替身已经存在、已经是公开目标、已经被别人用着， 那么#strong[复用它比自己写一个更省事]。

#strong[这一层不靠约束，靠成本。] 它把"做对"变成了阻力最小的路径。

=== 层次三：做错是不可能的
<sec-level-impossible>
#ref(<sec-rule-endgame>, supplement: [第]) 里那四个例子都在这一层： 两个冲突的目标在加载期就报重复，已校验的类型在模块外无法构造， 哨兵（一条规则声明它至少应该看到多少个事实，见 #ref(<sec-sentinel>, supplement: [第])）在类型上不能为零。

#strong[这一层不需要任何人遵守，因为它不存在"不遵守"这个选项。]

=== 三个层次的取舍
<sec-level-tradeoff>
#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([层次], [建设成本], [可靠性], [适用范围],),
  table.hline(),
  [信息在场], [低], [中], [任何规则],
  [默认路径正确], [中], [高], [有替代方案的场景],
  [做错不可能], [#strong[高]], [#strong[完全]], [少数能被类型或构建系统表达的],
)
#strong[大部分规则只能停在第一层，而这没问题。]

重要的是知道第二层和第三层存在，并且在设计一条新规则时问一句： #strong[这条能不能往上走一层？]

而这个问题在实践中有一个很省事的问法： #strong["如果我不写这条规则，有没有办法让做错这件事变得更麻烦？"]

== 反馈的成本必须被算进来
<sec-feedback-cost>
前面说"前馈决定性能"，容易被读成"反馈不重要"。补一句平衡。

#strong[反馈的价值是不可替代的，但它的成本是持续的：]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([成本项], [具体是什么],),
  table.hline(),
  [机时], [每次改动都要跑一遍],
  [延迟], [每次失败都要等一个回路],
  [注意力], [每条规则都要有人维护],
  [#strong[信任]], [每一次误报都在消耗它],
)
#strong[最后一项最容易被忽略，也最难恢复。]

一个总是误报的检查系统，它的实际效果不是"拦住了一些问题"， 而是"教会了所有人忽略它的输出"。而一旦这个习惯形成， #strong[那些真正的失败也会被一起忽略。]

这就是为什么 #ref(<sec-forbid-tuning>, supplement: [第]) 那一节要花那么多篇幅 讲"为什么不禁掉某个语句" ------ 那不是在讲宽容， #strong[是在保护这套系统唯一的、不可再生的资源。]

== 一个容易被误读的推论
<sec-misread-feedforward>
"前馈决定性能"这句话有一个错误的推论，值得提前堵住：

#quote(block: true)[
#strong[误读]：那我们应该把所有精力放在前馈上，检查可以少建一点。
]

#strong[这是错的]，而且它错在一个具体的地方：

#strong[前馈只能处理你已经知道的扰动。] 而你怎么知道有哪些扰动？ #strong[大部分是反馈告诉你的。]

一条规则的完整历程（#ref(<sec-rule-endgame>, supplement: [第])）是：

#Skylighting(([#NormalTok("反馈发现一个新的失败方式");],
[#NormalTok("  → 变成一条自动检查（还是反馈，但便宜了）");],
[#NormalTok("    → 最终变成结构（前馈，问题消失）");],));
#strong[没有第一步，就没有第三步。]

所以正确的推论不是"少建反馈"，而是：

#quote(block: true)[
#strong[反馈的产出，应该被持续地转化成前馈。]
]

而这个转化如果不发生，会有一个明确的症状： #strong[规则的数量单调增长，而没有任何一条因为"问题已经在结构上消失了" 而被删除]（#ref(<sec-rule-count>, supplement: [第])）。

== 环境和检查的投入比例
<sec-investment-ratio>
有一个可以参照的实际数字，虽然它不该被当成目标。

在这套系统里：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([投入], [行数],),
  table.hline(),
  [工具链（环境层的一部分）], [225,192],
  [检查器运行时（检查层的全部）], [67,113],
)
#strong[工具链是检查器的三倍多。]

而环境层的其余部分（目录结构、架构约束、载体安排） 是"零代码"的 ------ 它们不体现为行数，体现为#strong[没有被写出来的代码]： 没有被写重的机制、没有被放错的文件、没有被绕过的边界。

#strong[这个"看不见的投入"是环境层最大的一块，也是最难被计量的一块。]

而它的存在有一个间接的证据：这套系统的检查器只有六万七千行， 而它要管三百万行代码 ------ #strong[比例是 1:46。]

#strong[一个环境很差的仓库，需要的检查器会大得多]， 因为它要拦的错误路径更多。检查器的大小，某种程度上是环境质量的一个反向指标。

== 环境的四块为什么是这四块
<sec-why-four>
不是随便切的。这四块对应 Agent 在动手之前必须回答的四个问题， #strong[而这四个问题是穷尽的]：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([问题], [哪一块],),
  table.hline(),
  [我要写的东西#strong[放哪]？], [Codebase],
  [它#strong[会影响谁]？], [架构],
  [有什么#strong[我必须知道]的？], [载体],
  [我#strong[能做到什么]？], [工具链],
)
而"穷尽"的意思是：#strong[任何一个 Agent 做不好的事情， 都可以被归到这四个问题之一没被回答好。]

试着反证一下：一个 Agent 写出了错误的实现，可能因为 ------

- 它把代码放在了错误的位置 → 第一块
- 它没意识到这个改动会影响另一个模块 → 第二块
- 它不知道这条路径上有一个特殊约定 → 第三块
- 它没法验证自己的界面改动 → 第四块

#strong[而如果四个问题都答好了，剩下的错误就是"它算错了"] ------ 而那正是判定层（第三部）的对象。

#strong[所以这四块加上三层判定，覆盖了 Agent 出错的全部空间。]

（这个说法当然是粗糙的 ------ 它假设了错误可以被这样分类， 而 #ref(<sec-seven-shapes>, supplement: [章节]) 那七个形状说明真实的失败经常跨越多块。 但作为一个组织框架，它够用。）

== 环境层最容易被跳过的一块
<sec-most-skipped>
四块里，#strong[工具链最容易被跳过]，而且原因很具体：

前三块的投入都可以被"顺手做"------ 调整一次目录结构、加一条依赖规则、改一份常驻文件， #strong[这些都可以在做别的事情的时候顺带完成。]

#strong[而工具链不行。] 它需要专门的时间、专门的代码、 而且它的收益在膝点之后才出现（#ref(<sec-toolchain-curve>, supplement: [第])）。

#strong[所以它在资源紧张时永远是第一个被砍的] ------ 而砍掉它不会违反任何规则，不会让任何检查变红， 它的缺席是静默的（#ref(<sec-why-not-constraint>, supplement: [第])）。

#strong[这是形状 A 在投入决策上的形态]，而认出它是这一章 唯一想让读者记住的东西：

#quote(block: true)[
#strong[一块没有判定覆盖的投入，会被系统性地低估。]
]

== 这一部怎么读
<sec-part-two-reading>
四章的顺序不是重要性排序，是#strong[依赖顺序]：

- #ref(<sec-codebase>, supplement: [章节]) 定义"东西放在哪"，这是后面所有讨论的坐标系
- #ref(<sec-architecture>, supplement: [章节]) 定义"东西之间怎么连"，它建立在坐标系之上
- #ref(<sec-carriers>, supplement: [章节]) 定义"规则放在哪"，它需要前两章来判断"能不能写进结构"
- #ref(<sec-toolchain>, supplement: [章节]) 定义"手能伸到哪"，它是唯一一块不依赖前三块的

#strong[如果你只读一章，读 #ref(<sec-carriers>, supplement: [章节])。] 它零基建成本， 而且它能立刻改善任何一个正在用 Agent 的团队 ------ 包括一个人的项目。

#strong[如果你的团队还很小，跳过 #ref(<sec-depgraph>, supplement: [第]) 那一节。] 那是这一部里唯一需要重基建的地方。

== 一句容易被记错的话
<sec-easily-misremembered>
"检查不产生质量，环境才产生质量"这句话， 最容易被记成"检查不重要"。

#strong[准确的表述是]：

#quote(block: true)[
#strong[检查不产生质量，它让质量变得可以确认。 而不可确认的质量，在一个几十个 Agent 并行的系统里， 等价于不存在。]
]

后半句是这句话的另一半，而它同样重要。

一个环境完美但没有任何检查的仓库，它的代码可能真的很好 ------ #strong[但没有人（也没有任何机器）能知道这一点]， 所以每一次合并仍然需要人来看，第一堵墙照样撞上。

#strong[所以正确的理解是]：环境决定质量的上限， 检查决定你能利用多少这个上限。

#strong[两者的关系是乘法，不是加法。]

环境为零时，再多的检查也只能挡住格式问题； 检查为零时，再好的环境也没法被规模化利用。

== 这一部的四章各自能被压成一句
<sec-part-two-oneliners>
作为这一部的导航，先把结论给出来 ------ 四章各一句，读完之后再回来对照：

#strong[#ref(<sec-codebase>, supplement: [章节])]： \> 目录结构是你写给 Agent 的第一份文档， \> 而且是唯一一份它必然会读的。

#strong[#ref(<sec-architecture>, supplement: [章节])]： \> 每一条架构边界都必须换来一种可测性； \> 换不来的那条是装饰。

#strong[#ref(<sec-carriers>, supplement: [章节])]： \> 问题不是"这条规则重不重要"， \> 是"它什么时候需要到达"。

#strong[#ref(<sec-toolchain>, supplement: [章节])]： \> 前三块降低 Agent 做错的概率， \> 这一块决定它能不能知道自己做对了。

#strong[四句话，而它们的共同底色是同一个]：

#quote(block: true)[
#strong[把需要被记住的东西，变成一读就接收到的事实。]
]

目录让"这是什么"成为事实， 架构让"会影响谁"成为可查的， 载体让规则在正确的时刻在场， 工具让"我做对了没有"从猜测变成观察。

#strong[四种"变成事实"的方式，而它们都不依赖任何人记得什么。]

= Codebase：把边界写进目录
<codebase把边界写进目录>
= Codebase：把边界写进目录
<sec-codebase>
Agent 动手之前要回答两个问题：#strong[这段新代码该放在哪里，它能依赖谁。]

这两个问题答不上来的时候，再多的检查也只是在反复报错 ------ 它会告诉你"放错了"，却不会告诉你该放哪。

所以这一章讲的不是"我们的目录长什么样"，而是#strong[怎么让目录本身回答这两个问题]。

== 一个先要说清楚的区别
<sec-doc-vs-structure>
大部分团队处理这件事的方式是写一份《代码组织规范》。

这个做法的问题不在于文档写得好不好，在于#strong[生效时刻]： 一条写在文档里的规则，要等人（或 Agent）想起来去查才生效。 而"想起来"是一个概率事件，这个概率随文档变长而下降， 随任务紧急程度而下降，随写代码的人是不是新来的而下降。

#strong[而一条写进目录结构的规则，在 Agent 落笔的那一刻就已经在场了。] 它不需要被记住 ------ Agent 打开这个目录，看到里面有什么、没有什么， 就已经接收到了这条规则。

这一章后面的每一条，都可以用这个标准去检验： #strong[它是一条需要被记住的条文，还是一个一读代码就接收到的事实？]

== 路径模板与「被挣得」原则
<sec-earned-level>
客户端产品的路径模板长这样：

#Skylighting(([#NormalTok("Modules/{Product}/[{Platform}/][{Deployable}/]<角色分桶>");],
[#NormalTok("                   ↑ 可选        ↑ 可选");],));
关键在中间那两个可选层：#strong[它们必须被一个真实存在的第二个实例「挣得」。 既不为了对称而加，也不为了预期中的将来而加。]

这条规则听起来很小，但它是这个仓库两年没长歪的主要原因。

=== 三个真实判例
<sec-three-cases>
规则的价值不在措辞，在它能不能被机械地应用。看仓库里的三个实际形态：

#strong[判例一：两个平台都有的产品]

#Skylighting(([#NormalTok("Modules/Riff/");],
[#NormalTok("├── Android/");],
[#NormalTok("└── iOS/");],));
平台层出现了，因为第二个平台#strong[真的存在]。

#strong[判例二：多个进程的产品]

#Skylighting(([#NormalTok("Modules/QuipKey/");],
[#NormalTok("├── App/");],
[#NormalTok("├── Keyboard/");],
[#NormalTok("└── Shared/");],));
部署件层出现了，因为这个产品真的有两个独立的进程 ------ 一个主 App，一个输入法扩展。而 #NormalTok("Shared/"); 存放的#strong[只有被两个兄弟部署件 共同消费的代码]，它自己不能有组合根。

#strong[判例三：单平台、单进程的产品]

#Skylighting(([#NormalTok("Modules/InkBoard/");],
[#NormalTok("├── Launch/");],
[#NormalTok("├── Libraries/");],
[#NormalTok("├── Localization/");],
[#NormalTok("├── Services/");],
[#NormalTok("└── UI/");],));
#strong[两层可选层都没有。角色分桶直接展开在产品目录下。]

这三个例子放在一起，规则就不再是一句话，而是一个可以对照的模式。 一个 Agent（或一个新来的人）看到 #NormalTok("Modules/InkBoard/"); 下面直接是角色分桶， 就知道这个产品目前只有一个平台一个进程 ------ #strong[这个信息不需要任何人告诉它。]

=== 为什么"预期中的将来"是禁止的
<sec-no-speculative-layers>
最容易被违反的是第二半：不为了预期中的将来而加。

理由不是"你可能猜错"。就算你猜对了，提前加也是错的，原因有两个：

#strong[第一，目录层级一旦加上，就再也没人敢删了。] 删一个空目录看起来是零风险的操作，但做这个操作的人需要确认 "真的没有人计划往里放东西" ------ 而这个确认成本比留着它高。 于是它会一直在那儿。

#strong[第二，每一层空目录都在稀释结构本身的信息量。]

这一点更要紧。上面判例三之所以能传递信息， #strong[恰恰是因为那两层不在]。如果每个产品都有 #NormalTok("iOS/"); 层（不管它有没有第二个平台）， 那么这一层就不再携带任何信息 ------ 它从"这个产品有多个平台"的证据， 退化成了纯粹的仪式。

#strong[结构能传递信息，靠的是它在不需要的时候不出现。]

这是一条可以推广的原则，后面讲规则（#ref(<sec-rule-lifecycle>, supplement: [章节])）和 讲载体（#ref(<sec-carriers>, supplement: [章节])）时会以不同形态再出现三次： #strong[任何为了"以后可能用到"而提前建立的东西，都在削弱现有东西的信息量。]

== 角色分桶：按怎么获取，不按关于什么
<sec-role-buckets>
角色分桶是固定的五个：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([分桶], [是什么],),
  table.hline(),
  [#NormalTok("Launch");], [组合根 ------ 唯一知道自己 owner 全部服务与界面的地方],
  [#NormalTok("Libraries");], [直接 import，调用方自己管生命周期],
  [#NormalTok("Services");], [经微内核注册，通过协议解析],
  [#NormalTok("UI/{Components,Pages}");], [界面],
  [#NormalTok("Localization");], [文案],
)
这里有一条容易被误解的判据：#strong[角色由"怎么获取"决定，不由"关于什么"决定。]

也就是说，判断一个包该放 #NormalTok("Libraries"); 还是 #NormalTok("Services");， 问的不是"它是干什么的"，而是"使用它的人怎么拿到它"：

- 通过微内核注册取得 → #NormalTok("Services");
- 直接 import、生命周期归调用方 → #NormalTok("Libraries");

#strong[这条区分能消掉大量"这个该放哪"的争论]，因为它把一个品味问题 变成了一个事实问题 ------ 而事实问题有唯一答案。

配套的还有一条命名约束：#strong[共享层里 #NormalTok("Services/"); 下的每个包都必须以 #NormalTok("Service"); 结尾。一个不能诚实地取这个后缀的包， 说明它属于 #NormalTok("Libraries/"); 或 #NormalTok("Pages/");，或者必须按生命周期边界拆开。]

这条约束的巧妙之处在于它把判定交给了命名的直觉： 你在给一个包起名的时候，如果 #NormalTok("XxxService"); 这个名字念着别扭， 那通常不是名字的问题，是位置的问题。

== 共享层：按能力组织，不按角色
<sec-foundation-layout>
共享层的顶层结构和产品层不一样，值得对比：

#Skylighting(([#NormalTok("Foundation/iOS/");],
[#NormalTok("├── Commerce/          ├── Media/");],
[#NormalTok("├── Configuration/     ├── Navigation/");],
[#NormalTok("├── Identity/          ├── Networking/");],
[#NormalTok("├── Intelligence/      ├── Notifications/");],
[#NormalTok("├── Legal/             ├── Presentation/");],
[#NormalTok("├── Localization/      ├── Runtime/");],
[#NormalTok("├── Location/          └── Serialization/");],));
#strong[顶层是能力，不是角色。] 角色在第二层：

#Skylighting(([#NormalTok("Foundation/iOS/Commerce/");],
[#NormalTok("├── Libraries/");],
[#NormalTok("└── Services/");],
[#NormalTok("    ├── CommerceOperationService");],
[#NormalTok("    ├── PaywallOperationService");],
[#NormalTok("    └── StoreService");],));
这个顺序（能力在外、角色在内）是刻意的。

如果反过来 ------ #NormalTok("Foundation/iOS/Services/"); 下面平铺几百个服务 ------ 那么"跟支付相关的东西有哪些"这个问题就没法通过看目录回答， 只能靠搜索或者靠记性。

#strong[而 Agent 最需要的恰恰是"跟这件事相关的东西都在哪"。] #ref(<sec-carriers>, supplement: [章节]) 会讲到，Agent 的第一个动作应该是"先看看共享层里有没有现成的" ------ 而这个动作能不能便宜地完成，完全取决于共享层是不是按能力组织的。

== 四件套的第四格
<sec-testing-slot>
一个服务的内部结构是固定的四格。这是真实的目录：

#Skylighting(([#NormalTok("Modules/InkBoard/Services/InkBoardDocument/");],
[#NormalTok("├── BUILD");],
[#NormalTok("├── Protocol/");],
[#NormalTok("├── Service/");],
[#NormalTok("├── Testing/");],
[#NormalTok("└── Tests/");],));
#NormalTok("Protocol"); / #NormalTok("Service"); / #NormalTok("Tests"); 很好理解。#strong[最容易被忽略的是 #NormalTok("Testing/");。]

它和 #NormalTok("Tests/"); 的区别是：

- #NormalTok("Tests/"); 是#strong[这个服务自己的测试]
- #NormalTok("Testing/"); 是#strong[给别人用的测试替身] ------ 一个 testonly 的公开目标， 挨着它实现的那个协议

实测：整个仓库里有 #strong[178 个这样的 #NormalTok("Testing/"); 目录]。

=== 这一格解决什么
<sec-testing-slot-why>
没有它会发生什么，是可以准确预测的：

某个模块的测试需要一个支付服务的假实现，于是它在自己的测试目录里写一个。 下个月另一个模块也需要，于是它也写一个。半年后， #strong[同一个协议有五个略有不同的假实现]，散在五个模块的测试目录里。

而它们的差异是渐进产生的：A 模块的 fake 在某次改动里加了一个状态， B 模块的没加。这时候两个模块的测试#strong[在断言不同的行为]， 而没有任何东西会告诉你这件事。

#strong[下一次 flake 就来自这里。] 而且它会表现成"某个模块的测试偶尔失败"， 排查方向会指向那个模块 ------ 而根因在半年前另一个模块的一次改动里。

这是形状 B（同一份状态两个写者）在测试替身上的形态。 #NormalTok("Testing/"); 这一格做的事情就是：#strong[给替身一个 owner。]

== 演进纪律：机制什么时候上移
<sec-promotion>
判断标准很直白：#strong[同一个问题出现第二次，就该把机制升到共享层。]

配套的是：每一份可变状态收敛到单一 writer， 出了问题在 owner 那里修，而不是在调用点打补丁。

最后这条尤其重要 ------ #strong[当你发现自己在不同地方做着相似的局部修复， 那本身就是"这个机制该上移了"的信号，而不是"再修一次就好了"。]

=== 一个诚实的反例
<sec-promotion-counter-example>
这条规则说起来容易，做起来很难，而这本书的作者自己就是证据。

在这个系统的运维侧，"磁盘满"这一类问题#strong[在几个月内出现了五次]： 一次是缓存文件因为磁盘满而损坏导致登录失败，一次是容器磁盘耗尽导致 CI 任务失败， 一次是日志插件的缓存撑满导致全站错误，一次是监控机因为日志没有保留期而满， 一次是#strong[保留期配了、但和磁盘容量不匹配，于是又满了一次]。

前四次的处理都是清盘或者调参。#strong[真正的机制上移 ------ 任何分区的水位告警 ------ 到第五次的记录里才被提出来]，而那次记录里写着： "没有磁盘水位告警，潜伏 5 天"。

这不是打脸，这是这本书里最有信息量的一节：

#strong[知道原则和执行原则之间隔着注意力，而注意力是有限的。]

同一个人，在代码这一侧把"第二次就上移"执行得非常彻底 （这一章讲的每一条都是它的产物），在基础设施那一侧执行得很差。 区别不在认知 ------ 认知是同一个人的 ------ #strong[区别在哪一侧有判定覆盖。]

代码有三层检查盯着，每一次违反都会立刻变成一个红灯。 基础设施没有，于是"下次注意"就成了唯一的机制，而它不工作。

#ref(<sec-observer>, supplement: [章节]) 会讲这个缺口该怎么补。

== 模块化：按变更原因拆，不按行数
<sec-modularity>
文件尽量控制在 200 行以内，#strong[但拆分的依据是"变更原因"而不是行数] ------ 两段代码如果总是因为同一个理由一起改，那它们就该待在一起， 哪怕加起来超过 200 行。

实测：Swift 文件里超过 200 行的占 #strong[10.9%]。

=== 检查器对自己更严，而且严得不完全对
<sec-guardrails-self-limit>
检查器自己那部分设了硬顶：#strong[697 个 Rust 文件，无一超过 200 行。]

作者对这个选择的解释是："它是检查别人的那一方，尤其不能自己先松掉。"

这个态度是对的。但这里有一处值得指出的不一致：

#strong[那 697 个文件里，最大的几个分别是 200、200、200、199、199 行。]

一个按"变更原因"拆分的代码库，文件长度分布应该是连续的、 在 200 附近没有特别的堆积。而#strong[紧贴上限的堆积说明这些文件是按行数拆的， 不是按变更原因拆的。]

这不是什么严重问题 ------ 200 行的上限本身是个合理的启发式， 而检查器的代码高度同质，按行数拆的代价很低。

但它说明了一件更普遍的事：#strong[一条"按 A 判断而不是按 B 判断"的规则， 如果只有 B 是可以自动检查的，那么实践会向 B 漂移。]

这是本书会反复回到的一个张力。#ref(<sec-rule-lifecycle>, supplement: [章节]) 会讲， 它不是靠"更严格地要求自己"能解决的 ------ 得靠让 A 也变得可检查， 或者接受这个漂移并明确它的代价。

== Code is the SSOT
<sec-code-ssot>
用#strong[命名、类型、代码结构、schema] 承载意图和数据模型， 只保留解释"为什么"的注释（约束 / 取舍 / 引用）， 删掉复述"做了什么"的注释。

这条有一个可核验的数字：#strong[在 310 万行 Swift、Rust、Go 代码里， #NormalTok("TODO"); 有 23 个，#NormalTok("FIXME"); 有 0 个。]

约每十三万行一个 #NormalTok("TODO");。而一般代码库的密度是每两百到五百行一个。

#strong[这个数字只能靠强制得到，不可能靠自觉。] 它的意义不在于"很干净"， 而在于：#strong[当 #NormalTok("TODO"); 稀少到这个程度时，它重新变成一个信号。]

在一个有五千个 #NormalTok("TODO"); 的代码库里，#NormalTok("TODO"); 是噪声 ------ 没有人会去读它们， grep 出来的结果没法行动。而在这里，二十三个 #NormalTok("TODO"); 是一份可以在一小时内 读完并处理掉的清单。

== worktree 隔离与一条反直觉的约束
<sec-worktree>
分支模型是主干开发：只有一条长期分支， 另外一百多个远端分支全部是短生命周期的，一律经合并请求汇入。

这个选择在 Agent 并行度上来之后变得格外重要 ------ #strong[长期分支意味着长期的分歧，而分歧的合并成本是人在付。]

实测：同一时间有 #strong[260 个工作区并存]，单日最多 48 个分支同时推进， 峰值一天合入 52 次。每个工作区独占自己的构建输出根和验证 owner。

=== 一条会咬人的约束
<sec-recursive-danger>
这里有一条反直觉但很要紧的事实：#strong[这些工作区就住在仓库树内部。]

所以任何对仓库根目录的递归命令都是危险的 ------ 一次 #NormalTok("grep -r");，或者一次看起来无害的批量替换， #strong[会一路走进几十个不相干的检出，改到你从没打开过的分支。]

这条约束的处理方式值得学。它没有被写成"请小心使用递归命令"， 而是被写成了一条带着#strong[具体验证动作]的规则：

#quote(block: true)[
把每一次递归读取和每一次批量编辑限定到任务拥有的具体目录， 并在动作之前#strong[确认匹配列表里没有工作区路径]。
]

#ref(<sec-carriers>, supplement: [章节]) 会讲这个写法为什么重要： #strong[一条规则如果只说"要小心"，它对 Agent 等于不存在； 只有当它给出一个可执行的验证步骤时，它才是一条规则。]

== Designs：设计也是 Agent 能读的规格
<sec-designs>
最后一块容易被忽略。设计资产的链路是：

#Skylighting(([#NormalTok("PRD → 信息架构 → 设计系统 → 高保真原型 → 视觉资产");],));
这条链上最关键的一步是原型的格式：#strong[那些原型是 HTML 文件，不是设计稿截图。]

这个选择的意义在于，Agent 可以直接读懂它的结构和交互 ------ 按钮在哪、点了之后去哪、状态怎么变，#strong[都在代码里写着]， 不需要人先看一遍图再转译成文字描述给它。

#strong[设计因此从"给人看的东西"变成了"可被消费的输入"。]

这是这一章那条主线的又一个实例：把信息放进一个 Agent 能直接读的载体里， 而不是放进一个需要人转译的载体里。转译这个动作本身， 就是规模化时第一个断掉的环节。

== 目录结构作为一种压缩
<sec-directory-as-compression>
把这一章的内容抽象一层，会看到一个统一的视角： #strong[目录结构是一种对"这个系统是什么形状"的压缩编码。]

而所有关于压缩的直觉在这里都适用：

#strong[一、冗余降低信息密度。] 每一层为了对称而加的空目录，都是一个不携带信息的符号。 读者（人或 Agent）仍然要花注意力去处理它，却得不到任何东西。

#strong[二、编码方案必须是双向的。] 你能从目录推出结构，也应该能从结构推出目录。 "角色由怎么获取决定"（#ref(<sec-role-buckets>, supplement: [第])）之所以重要， 是因为它保证了这个映射是#strong[函数]，而不是一个需要查表的约定 ------ 给定一个新包，它该放哪只有一个答案。

#strong[三、压缩率的上限由规律性决定。] 一个到处是特例的仓库，目录结构无法承载太多信息， 因为读者不能从它推出任何东西。#strong[而规律性是被规则维持的]， 这就是为什么"被挣得"原则要被强制执行 ------ 它维持的不是整洁，是这套编码的可解码性。

这个视角能解释一件事：为什么"要不要加一层目录"这种看起来 鸡毛蒜皮的问题，值得写进常驻文件、值得设一条规则来守。

#strong[因为它不是关于目录的，是关于 Agent 每次读代码时能免费获得多少信息。]

== 三个可以立刻自查的信号
<sec-codebase-signals>
不用读完整章，这三个信号出现任意一个，说明结构在腐化：

#strong[一、有人问"这个该放哪"，而答案取决于问谁。] 说明分桶的判据不是事实问题。修法是找出那个能把它变成事实问题的维度 （这套系统用的是"怎么获取"）。

#strong[二、有一层目录，你说不出它的第二个实例是什么。] 它没有被挣得。

#strong[三、同一个接口有超过一个测试替身。] 它们的差异会在某天变成一次难以定位的失败（#ref(<sec-testing-slot-why>, supplement: [第])）。

三条都不需要工具，用眼睛看十分钟就能查完。

== 目录之外：还有哪些结构能承载规则
<sec-other-structures>
这一章讲的是目录，但"把规则写进结构"这条原则不止目录这一种载体。 把它们列全，因为#strong[选错载体的成本很高]：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([结构], [它能表达什么], [例子],),
  table.hline(),
  [#strong[目录层级]], [归属、可见性、依赖方向], [角色分桶],
  [#strong[类型]], [合法状态的集合], [三态判定枚举、非零哨兵],
  [#strong[可见性修饰]], [谁能构造、谁能调用], [已校验配置只能在模块内构造],
  [#strong[构建目标]], [什么能依赖什么], [协议与实现分成两个目标],
  [#strong[命名约定]], [角色], [共享服务必须以 #NormalTok("Service"); 结尾],
  [#strong[文件名]], [唯一性], [一个 target 一个 logger 定义文件],
)
#strong[类型那一行是最强的]，因为它的违反是编译期的 ------ 而编译期的反馈是所有反馈里最快的，快到它不像反馈，像前馈。

#strong[而命名约定那一行是最弱的]，因为它需要一条额外的检查来执行。 但它有一个别的结构没有的优点：#strong[它在阅读时零成本地传递信息。] 一个叫 #NormalTok("XxxService"); 的包，读者立刻知道它的获取方式。

=== 一条实用的选择顺序
<sec-structure-priority>
面对一条要写进结构的规则，按这个顺序试：

#Skylighting(([#NormalTok("能用类型表达吗？          → 用类型（编译期，最强）");],
[#NormalTok("不能 → 能用可见性表达吗？  → 用可见性（编译期）");],
[#NormalTok("不能 → 能用构建目标表达吗？ → 用目标（构建期）");],
[#NormalTok("不能 → 能用目录表达吗？    → 用目录（人和 Agent 一读就知道）");],
[#NormalTok("不能 → 能用命名表达吗？    → 用命名 + 一条检查");],
[#NormalTok("不能 → 才写进常驻文件");],));
#strong[大部分团队直接跳到最后一步。]

而这个顺序有一个副作用值得注意：#strong[越往上，规则越不需要被"知道"。] 一条用类型表达的规则，新来的人不需要读任何文档 ------ 他写错了，编译器会告诉他。

== 一个反面案例：过度分层的代价
<sec-over-layering>
前面讲了"被挣得"原则，这里给一个它防住的具体场景， 因为抽象的原则不如一个具体的代价有说服力。

设想一个只有一个平台、一个进程的产品，但目录里有完整的 平台层和部署件层（"以后可能会有 Android 版"）。

代价有五层，一层比一层深：

#strong[一、每个文件的路径长了两级。] 这是最表面的，也是最不重要的。

#strong[二、每一次新建文件都要做一次无意义的决定。] "这个该放 #NormalTok("iOS/App/"); 下面还是……"------ 而因为只有一个平台一个进程， 这个决定没有信息量，但它仍然消耗一次判断。

#strong[三、结构不再传递信息。] #ref(<sec-no-speculative-layers>, supplement: [第]) 讲过：看到平台层的人会以为有多个平台。 #strong[一个错误的信息比没有信息更糟。]

#strong[四、真的要加第二个平台时，还得重来一遍。] 因为提前建的那层，几乎必然和真实需要的形状不一样 ------ 你在没有第二个实例的情况下设计的抽象，是猜的。

#strong[五、没有人敢删。] 这是最深的一层。 删一个空目录看起来零风险，但做这个操作的人需要确认 "真的没有人计划往里放东西"，而这个确认成本高于留着它。

#strong[五层代价里，只有第一层是显性的。] 而这就是为什么这条规则需要被写成规则 ------ 如果靠直觉，人们只会权衡第一层。

== 目录结构的两个隐藏成本
<sec-hidden-costs>
这一章讲了很多"该怎么组织"，但组织本身也有成本， 而其中两项通常不被计入。

=== 隐藏成本一：每一次移动都是一次全局改动
<sec-cost-moving>
在一个有严格目录规则的仓库里，#strong[把一个包从 #NormalTok("Libraries"); 挪到 #NormalTok("Services"); 不是一次移动，是一次涉及所有引用方的改动。]

这个成本随仓库规模增长，而且它是#strong[超线性]的 ------ 引用越多，需要检查的地方越多。

#strong[这带来一个实际后果：目录规则越严，"先放着看看"的成本越高。] 而"先放着看看"在探索性的工作里是有价值的。

这套系统的处理方式是：#strong[规则只约束共享层和产品层的顶层结构， 不约束一个包内部怎么组织。] 内部是自由的， 只有跨越边界时才受约束 ------ 探索发生在包内部，代价可控。

=== 隐藏成本二：规则和现实之间的滞后
<sec-cost-lag>
一次业务上的变化（比如一个功能从一个产品扩展到两个产品）， 在代码上的正确形态会立刻改变（它该下沉到共享层了）， #strong[但实际的移动会滞后。]

而在滞后期内，仓库处于一个"按规则应该是 A，实际是 B"的状态。

#strong[这个状态是不可避免的，问题是怎么对待它。]

两种做法：

- #strong[把它当违规] → 每次业务变化都会引发一批红灯， 而这些红灯不指向任何人的错误
- #strong[把它记账] → 这正是债务台账（#ref(<sec-baseline>, supplement: [第])）的用途， 只是这次记的是"结构债"而不是"违规债"

#strong[这套系统用的是第二种]，而这也解释了为什么 #NormalTok("PRODUCT-ISOLATION"); 那条规则是报数模式却零违规 ------ 它在等一个还没到来的时刻，而不是在容忍一个存量。

== 一个反常识：不要追求"完美的目录结构"
<sec-not-perfect>
这一章的最后一句提醒。

目录结构的价值是#strong[传递信息]，不是#strong[正确]。

一个"更正确"但没人能一眼读懂的结构，比一个稍有妥协但一目了然的结构差。 而"一眼读懂"的判据很具体：

#quote(block: true)[
#strong[一个新来的人（或 Agent）看到一个路径， 能不能推出它是什么、能依赖谁？]
]

按这个判据，#ref(<sec-role-buckets>, supplement: [第]) 那五个固定的角色分桶是好的 （五个，可穷举，且角色由获取方式决定）； 而一个有十五个分类、每个分类都有充分理由的结构是坏的 ------ #strong[因为没有人能记住十五个。]

#strong[结构的可读性上限，由人的工作记忆决定，而不是由领域的复杂度决定。]

== 命名作为最轻的一种结构
<sec-naming-as-structure>
#ref(<sec-other-structures>, supplement: [第]) 那张表把命名列为"最弱"的结构载体， 但它有一个别的载体都没有的性质，值得单独说：

#quote(block: true)[
#strong[它在阅读时零成本地传递信息。]
]

一个叫 #NormalTok("XxxService"); 的包，读者不需要打开它、 不需要查目录、不需要读文档，#strong[就知道它的获取方式]。

而这个"零成本"在 Agent 场景下被放大了： Agent 每次读代码都是从零开始， #strong[所以任何"不需要额外查询就能获得的信息"，价值都比对人高。]

=== 一条好的命名约定长什么样
<sec-good-naming>
三个特征：

#strong[一、它编码的是一个稳定的事实，不是一个分类。] "以 #NormalTok("Service"); 结尾表示它经微内核注册"编码的是获取方式 ------ 而获取方式是这个包的一个#strong[结构性事实]。 而"以 #NormalTok("Manager"); 结尾表示它管理某个东西"编码的是一个模糊的角色。

#strong[二、它有一个明确的否定形式。] "一个不能诚实地取 #NormalTok("Service"); 后缀的包，说明它属于别处"------ #strong[这条否定形式让命名约定变成了一个诊断工具]： 起名困难时，问题通常在位置上，不在名字上。

#strong[三、它可以被机器检查。] 一条无法被检查的命名约定，会在半年内漂移到 60% 的遵守率， 而那时候它已经不传递信息了。

=== 一个反例：过度命名
<sec-over-naming>
命名约定也会过度。判据是：

#quote(block: true)[
#strong[一个新来的人，需要记住几条命名规则才能读懂路径？]
]

超过三到四条，它就从"零成本传递信息"变成了 "需要先学习一套编码"。

而这套系统的命名约定实际上只有两三条 （角色后缀、平台目录的大小写、文件与它定义的类型同名）， #strong[其余的信息都由目录结构承载] ------ 因为目录结构是可见的， 而命名规则需要被记住。

== 目录结构的一个非显然收益
<sec-non-obvious-benefit>
最后一个观察，它和 Agent 的工作方式直接相关。

#strong[一个规律的目录结构，让"我该读哪些文件"变成一个可计算的问题。]

一个 Agent 接到"给某产品加一个页面"的任务时， 如果目录结构是规律的，它可以直接推出需要看的位置： 那个产品的页面目录、它的路由库、它的本地化表。

#strong[而如果结构不规律，它只能靠搜索] ------ 而搜索的结果是一个按相关度排序的列表， #strong[列表里没有"完整性"这个保证。]

这个差别在实践中的表现是：#strong[结构规律的仓库里， Agent 更少遗漏；结构混乱的仓库里，它会漏掉那些 名字不像但实际相关的东西。]

#strong[而遗漏是静默的] ------ 它不会导致编译失败， 它会导致一个功能只做了一半。

== 目录结构和判定层的连接
<sec-codebase-verdict-link>
这一章讲的东西看起来很"软" ------ 目录、命名、分层。 但它们和判定层有一条硬连接：

#quote(block: true)[
#strong[一条依赖规则能不能被自动检查， 取决于依赖关系能不能从目录结构推出来。]
]

具体地说，"产品之间不能互相依赖"这条规则的可执行版本是：

#Skylighting(([#NormalTok("查询构建图 → 找出所有 Modules/A → Modules/B 的边 → 报违规");],));
#strong[而这条查询之所以能写出来，是因为"哪些是产品" 可以从路径推出来] ------ #NormalTok("Modules/"); 下面每个目录是一个产品。

#strong[如果目录结构不规律，这条规则就无法被表达。]

同样的连接还有几处：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([结构约定], [让哪条规则成为可能],),
  table.hline(),
  [每个产品在 #NormalTok("Modules/"); 下一个目录], [产品互不依赖],
  [服务包以 #NormalTok("Service"); 结尾], [服务必须经注册取得],
  [协议与实现是两个目录], [契约与实现必须分目标],
  [组合根固定叫 #NormalTok("Launch");], [生产目标不得依赖组合根],
)
#strong[四条结构约定，四条可执行的规则。]

而反过来说：#strong[一个结构混乱的仓库， 它的架构规则大多只能停在文档层] （#ref(<sec-feedforward-levels>, supplement: [第]) 的第一层）， #strong[因为没有一个可靠的方式把"这是什么"从路径推出来。]

#strong[这是"环境先于检查"（#ref(<sec-environment-first>, supplement: [章节])） 最具体的一个含义]：不是"环境更重要"， 而是#strong[环境决定了检查能不能被写出来。]

== 一个反过来的观察
<sec-reverse-observation>
有了上面那条连接，可以反过来用它做一个诊断：

#quote(block: true)[
#strong[看看你有多少条架构规则是自动检查的， 多少条只写在文档里。]
]

如果后者远多于前者，通常不是因为"没时间写检查", 而是因为#strong[结构不足以支撑那些检查] ------ 你没法可靠地判断一个文件属于哪一层、哪个模块、哪个角色。

#strong[而那时候正确的第一步不是写检查，是先把结构理顺。]

这也是这一章排在第二部第一位的原因： #strong[它是后面所有内容的前提。]

== ⚙️ 小规模怎么做
<sec-codebase-small>
这一章里没有任何一条需要重基建。三条今天就能用的：

#strong[一、把"被挣得"原则用在你现有的目录上。] 遍历一遍，找出那些只有一个子项的中间层。每一个都问： 它是被第二个实例挣得的，还是为了对称/将来加的？后者删掉。

小项目更容易犯这个错，因为小项目更容易为了"以后会用到"而提前分层 ------ 而且代价更大，因为在一个只有三十个文件的项目里， 一层空目录稀释掉的信息量占比更高。

#strong[二、给你的测试替身找一个 owner。] grep 一下你的测试目录，看同一个接口有几个假实现。 如果超过一个，把它们合并到一个地方 ------ 不需要什么框架， 一个共享的测试工具目录就够。

#strong[三、数一下你的 #NormalTok("TODO");。] 如果超过一百个，那么它们已经是噪声了。 不需要一次清完，但要停止增长 ------ 加一条 CI 检查， 不允许新增（这就是 #ref(<sec-baseline>, supplement: [第]) 讲的单调收敛，最小形态）。

== 这一章的一句话
<sec-codebase-oneline>
#quote(block: true)[
#strong[目录结构是你写给 Agent 的第一份文档， 而且是唯一一份它必然会读的。]
]

它不会读你的 README（除非被指向）， 不会读你的架构文档（除非被指向）， #strong[但它一定会看到路径 ------ 因为它必须知道文件在哪。]

而这意味着：#strong[每一个能被目录结构承载的信息， 都是零成本传递的]；每一个不能的，都需要另一个载体 （#ref(<sec-carriers>, supplement: [章节])），而另一个载体都有它自己的到达概率。

#strong[所以"能写进目录的就不要写进文档"这条建议， 不是为了整洁，是为了到达率。]

== 一次真实的目录重构
<sec-real-refactor>
版本历史里有一次提交，标题是 #strong["把某产品未被挣得的 App 层摘掉，按获取方式拆进组装根与库"]。

这次改动值得拆开看，因为#strong[它同时演示了这一章的三条原则]：

#strong[一、它执行的是"被挣得"原则]（#ref(<sec-earned-level>, supplement: [第])）。 那个产品只有一个部署件，所以 #NormalTok("App/"); 这一层从来没有被 第二个实例挣得过。

#strong[二、拆分的依据是"怎么获取"]（#ref(<sec-role-buckets>, supplement: [第])）。 标题里"按获取方式拆进组装根与库"------ 不是按功能拆，不是按大小拆，是按角色拆。

#strong[三、它是一次纯结构改动，没有业务变化。]

而第三点带来一个值得讨论的问题：

=== 纯结构改动值不值
<sec-structural-refactor-worth>
一次不改变任何行为的改动，怎么论证它的价值？

#strong[三条，按可验证程度排：]

#strong[一、它让结构重新开始传递信息。] 在改之前，看到 #NormalTok("App/"); 的人会以为这个产品有多个部署件 （#ref(<sec-no-speculative-layers>, supplement: [第])）。改完之后，结构说的是真话。

#strong[二、它让规则重新可用。] 一条"兄弟部署件不许直连"的规则，在只有一个部署件时 是空转的。而更麻烦的是：#strong[这条规则的存在， 会让人以为这个产品的部署件边界被守着 ------ 而实际上没有东西可守。]

#strong[三、它降低了未来的成本。] 真的要加第二个部署件时，现在的形状是对的 （因为它反映了真实的一个部署件）， #strong[而之前那个形状是猜的]（#ref(<sec-not-perfect>, supplement: [第])）。

#strong[而这三条里，只有第一条是立刻可见的。]

这就是纯结构改动难以被排优先级的原因， 也是为什么它需要一条规则来强制 ------ #strong[否则它永远排在"有可见收益"的事情后面。]

=== 这次改动的代价
<sec-refactor-cost>
诚实地说：这类改动有一个隐藏代价，#ref(<sec-death-drift>, supplement: [第]) 讲过 ------ #strong[所有以路径通配符定义范围的规则，它们的匹配范围都变了。]

而没有任何机制会告诉你"这次重构让某条规则的覆盖面掉了一半"。

#strong[所以一次目录重构之后，应该主动检查各条规则的扫描数] （那个数就在每次运行的输出里）。

#strong[这是这本书对源系统的第六条建议]， 而它和前五条一样：数据在手边，缺的是把它接进一条判定。

== 这一章能被压成的三句话
<sec-codebase-three-lines>
#strong[一、每一层结构必须被一个真实的第二个实例挣得。]

而这条的价值不在整洁，在于 #strong[结构能传递信息，靠的是它在不需要的时候不出现] （#ref(<sec-no-speculative-layers>, supplement: [第])）。

#strong[二、角色由"怎么获取"决定，不由"关于什么"决定。]

这条把一个品味问题变成了事实问题， #strong[而事实问题在不同的人（和不同的 Agent）之间 能得到一致的答案]（#ref(<sec-role-buckets>, supplement: [第])）。

#strong[三、目录结构决定了哪些检查能被写出来。]

这是"环境先于检查"最具体的含义 （#ref(<sec-codebase-verdict-link>, supplement: [第])）------ #strong[不是环境更重要，是结构不足以支撑的检查根本写不出来。]

== 一个留给读者的练习
<sec-codebase-exercise>
十分钟，三步：

#strong[一、随便挑五个文件，看它们的路径。] 问：#strong[只看路径，你能说出它是什么、能依赖谁吗？]

答不出来的每一个，都是一次信息传递的失败。

#strong[二、找出所有只有一个子项的中间目录。] 每一个都问：它被第二个实例挣得了吗？

#strong[三、grep 你的测试目录，看同一个接口有几个假实现。] 超过一个 → 它们的差异会在某天变成一次难以定位的失败 （#ref(<sec-testing-slot-why>, supplement: [第])）。

#strong[三步做完，你会有一份具体的清单] ------ 而这份清单比读完这一章更有用， 因为它是关于你自己的仓库的。

= 架构：让行为可以被断言
<架构让行为可以被断言>
= 架构：让行为可以被断言
<sec-architecture>
#ref(<sec-codebase>, supplement: [章节]) 讲的是代码放在哪里，这一章讲它跑起来之后是什么样子。

整个系统按构建期、运行期、交付期分成三段，每一段都有一个明确的方向：

- #strong[构建期]：一份声明派生出多端
- #strong[运行期]：依赖只向一个方向流动
- #strong[交付期]：触发权收敛到唯一入口

方向一旦确定，Agent 改动任何一处，都能沿着这个方向推出"会影响到谁" ------ #strong[这正是它自己判断影响面所需要的东西。]

而这一章真正想说的是最后一节的那句话：#strong[架构在这里不是审美选择。 每一条边界都对应一种"这次改动对不对"能被机器验证的能力。] 说不出这种能力的边界，是装饰。

== 构建期：一份声明 → 多端派生
<sec-derive>
这一段是整套基建里最根本的一环，因为它不是在事后挑错， #strong[而是在源头上把出错的机会消掉] ------ 把"改 4 个地方"压成"改 1 个地方"。

=== 它解决的是什么问题
<sec-derive-problem>
原始状态是这样的：

#quote(block: true)[
iOS 上有 5 个手写的 HTTP 客户端，约 109 个接口在服务端处理器、 客户端调用点、前端请求三处重复。#strong[每加一个接口是 4 个地方的改动 ------ 一处漂移会悄悄弄坏其它几处。]
]

"悄悄"是关键词。类型不一致不会让任何一端编译失败， 它只会在运行时表现成一个字段是空的、一个枚举值没有匹配上、 一个日期格式被解析成了 1970 年。

而这类问题的排查成本极高，因为#strong[每一端单独看都是对的]。 这是形状 B 的一个变种：同一份契约有四个写者。

改完之后是：

#quote(block: true)[
编辑一个声明片段，跑构建，四个平台从同一个逻辑模块重新派生类型。
]

实测：仓库里有 #strong[694 个这样的声明文件]， 而同样的"声明 → 生成"结构在别处又复制了 #strong[11 遍]， 覆盖接口契约、产品元数据、设计变量等等。

=== 管线的形状
<sec-pipeline-shape>
支撑它的是一个约三千行的 Rust 程序，管线分成五段：

#Skylighting(([#NormalTok("lexer → parser → assembly → ir → emit");],));
前四段是通用的，只有最后一段 #NormalTok("emit"); 分语言 ------ 而且 emit 走模板：

#Skylighting(([#NormalTok("templates/swift.tera  templates/go.tera  templates/ts.tera  templates/kotlin.tera");],));
#strong[每种目标语言一个模板，所以要调整生成结果通常是改模板， 而不是改编译器本身。] 这是机制与策略分离在代码生成上的形态： 编译器是机制，模板是策略。

它的命令行接口把这个结构暴露得很清楚：

#Skylighting(([#KeywordTok("enum");#NormalTok(" Cmd ");#OperatorTok("{");],
[#NormalTok("    Swift  ");#OperatorTok("{");#NormalTok(" inputs");#OperatorTok(",");#NormalTok(" output ");#OperatorTok("},");],
[#NormalTok("    Go     ");#OperatorTok("{");#NormalTok(" inputs");#OperatorTok(",");#NormalTok(" output");#OperatorTok(",");#NormalTok(" package ");#OperatorTok("},");],
[#NormalTok("    Ts     ");#OperatorTok("{");#NormalTok(" inputs");#OperatorTok(",");#NormalTok(" output ");#OperatorTok("},");],
[#NormalTok("    Kotlin ");#OperatorTok("{");#NormalTok(" inputs");#OperatorTok(",");#NormalTok(" output");#OperatorTok(",");#NormalTok(" package ");#OperatorTok("},");],
[#NormalTok("    ");#CommentTok("/// Validates the declared fragments as one logical module.");],
[#NormalTok("    Check  ");#OperatorTok("{");#NormalTok(" inputs ");#OperatorTok("},");],
[#OperatorTok("}");],));
注意最后那个 #NormalTok("Check");。#strong[它可以只校验、不生成。] 这意味着"这份声明合不合法"是一个独立于"生成什么"的问题， 可以在任何时候单独问 ------ 包括在编辑器里、在提交钩子里、在 CI 的最便宜那一层里。

=== 错误枚举就是不变量清单
<sec-errors-as-invariants>
这个编译器最值得学的地方不在管线，在它的错误类型。

#strong[一个程序拒绝什么，比它接受什么更能说明它守着哪些不变量。] 组装阶段的错误枚举是这样的：

#Skylighting(([#KeywordTok("pub");#NormalTok(" ");#KeywordTok("enum");#NormalTok(" AssemblyError ");#OperatorTok("{");],
[#NormalTok("    Empty");#OperatorTok(",");#NormalTok("                                       ");#CommentTok("// 逻辑模块至少要有一个片段");],
[#NormalTok("    Lex ");#OperatorTok("{");#NormalTok(" path");#OperatorTok(",");#NormalTok(" source ");#OperatorTok("},");#NormalTok("                        ");#CommentTok("// 词法错误，带上是哪个文件");],
[#NormalTok("    Parse ");#OperatorTok("{");#NormalTok(" path");#OperatorTok(",");#NormalTok(" source ");#OperatorTok("},");#NormalTok("                      ");#CommentTok("// 语法错误，带上是哪个文件");],
[#NormalTok("    NamespaceMismatch ");#OperatorTok("{");#NormalTok(" path");#OperatorTok(",");#NormalTok(" expected");#OperatorTok(",");#NormalTok(" actual ");#OperatorTok("},");#NormalTok(" ");#CommentTok("// 片段之间必须同意命名空间");],
[#NormalTok("    DuplicateName ");#OperatorTok("{");#NormalTok(" path");#OperatorTok(",");#NormalTok(" name ");#OperatorTok("},");#NormalTok("                ");#CommentTok("// 跨片段不许重名");],
[#OperatorTok("}");],));
逐条读一遍，这五个变体就是五条不变量：

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([变体], [它守的不变量],),
  table.hline(),
  [#NormalTok("Empty");], [一个逻辑模块必须有内容，空模块不是合法状态],
  [#NormalTok("Lex"); / #NormalTok("Parse");], [错误必须带上#strong[哪个文件] ------ 多片段组装时这是唯一有用的定位信息],
  [#NormalTok("NamespaceMismatch");], [#strong[多个片段组成一个模块，它们必须同意自己属于谁]],
  [#NormalTok("DuplicateName");], [#strong[同一个名字不能有两个定义] ------ 单一 writer 用在了类型定义上],
)
后两条尤其值得说。它们的存在意味着：#strong[声明是可以拆成多个文件的， 但拆开之后它们仍然被当作一个整体来校验。]

这是一个刻意的设计取舍。允许拆分是为了让不同的人（和不同的 Agent） 能并行编辑不同的接口而不互相冲突；而在组装阶段做整体校验， 是为了不让这种并行制造出不一致。#strong[拆分是为了并发，组装校验是为了一致 ------ 两者必须同时存在，只有前者就是形状 B。]

类型检查阶段只有一个错误变体，但它写得很讲究：

#Skylighting(([#KeywordTok("pub");#NormalTok(" ");#KeywordTok("enum");#NormalTok(" CheckError ");#OperatorTok("{");],
[#NormalTok("    ");#AttributeTok("#[");#NormalTok("error");#AttributeTok("(");#StringTok("\"unknown type reference {name:?} at {span} (defined types: {defined:?})\"");#AttributeTok(")]");],
[#NormalTok("    UnknownRef ");#OperatorTok("{");#NormalTok(" name");#OperatorTok(",");#NormalTok(" span");#OperatorTok(",");#NormalTok(" defined");#OperatorTok(":");#NormalTok(" ");#DataTypeTok("Vec");#OperatorTok("<");#DataTypeTok("String");#OperatorTok(">");#NormalTok(" ");#OperatorTok("},");],
[#OperatorTok("}");],));
注意 #NormalTok("defined: Vec<String>"); ------ #strong[错误消息里带着"你本来可以用哪些类型"。]

这不是锦上添花。#ref(<sec-incident-hint>, supplement: [第]) 讲过，一个只说"错了"的判定 只提供了误差的符号，而一个带着可选项的错误提供了#strong[方向] ------ 读到这条错误的人（或 Agent）不需要再去翻文档找有哪些类型可用。

#strong[这条纪律从检查器一直贯穿到编译器：失败的时候，把下一步一起给出去。]

=== 生成物的漂移检测
<sec-drift-detection>
这套东西还给自己加了一道自检。构建规则里有一条测试， 它的文档字符串只有一句：

#quote(block: true)[
Fails when a checked-in API client differs from its Bazel output.
]

签入仓库的生成代码，和构建系统当场重新生成的产物，必须一致。

#strong[它防的是这样一种失效：有人手改了生成物，但源声明没动。]

这是最难查的一类问题，因为改完之后代码能编译、测试能通过、行为可能也对。 #strong[唯一坏掉的是"生成物由声明派生"这条不变量] ------ 而它坏了之后，下一次重新生成会把手改的部分静默地抹掉。

#ref(<sec-analytical-redundancy>, supplement: [第]) 会从控制的角度重新讲这个机制。 在这里只需要记住它的结构：#strong[用第二个独立通道去验第一个。]

== ⚙️ 依赖图：影响面变成可以计算的东西
<sec-depgraph>
这一节需要统一构建系统。#strong[没有它，本节的方法不成立] ------ 但第 #ref(<sec-carriers>, supplement: [章节])、#ref(<sec-tests>, supplement: [章节])、#ref(<sec-guardrails>, supplement: [章节])、#ref(<sec-rule-lifecycle>, supplement: [章节]) 四章 完全不依赖它，可以跳过这一节继续读。

单仓加上统一构建系统，换来的最有价值的东西其实不是构建速度， 而是#strong[一张覆盖全仓的依赖图]。构建加速只是这张图的副产品， 真正的产出是"影响面变成了可以计算的东西"。

这张图能回答四类问题，每一类都换来一种能力：

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([问什么], [得到的能力],),
  table.hline(),
  [谁依赖了这个目标（反向依赖）], [CI 只跑受影响的目标，不跑全量；测试按目标分片并行],
  [这个目标依赖了谁（正向依赖）], [架构规则变成可执行的查询，禁止的方向当场拦下],
  [这次构建的输入是什么（密封 + 内容寻址）], [远程缓存跨机复用，没变的不重跑，结果可复现],
  [生成器的输出归谁], [改一处，下游产物自动重新派生，漂移即失败],
)
#strong[对 Agent 来说，这一点的意义比对人更大。]

人改代码时会凭经验估计影响范围。估得准不准取决于他在这个仓库里待了多久， 而估错了就在评审或线上被发现 ------ 这个过程是有反馈的， 所以一个人的估计会随时间变准。

#strong[而 Agent 没有这个积累。] 它每次都是新来的。 让它去"估计"影响范围，等于让它每次都从零开始猜， 而且它的猜测不会因为上次猜错了而变好。

所以对 Agent 来说，正确的做法不是让它估得更准，而是#strong[让它根本不需要估] ------ 影响面是查出来的，不是想出来的。

这也是 #ref(<sec-wall-two>, supplement: [第]) 那堵墙的真正解法。#ref(<sec-gain-and-delay>, supplement: [章节]) 会从控制的角度 重新讲一遍：这不是给测量扩容，是#strong[把测量收缩到本次真正变化的那个子空间]。

== 运行时：三条链路，各只有一个方向
<sec-runtime>
=== 客户端：装配链是固定的
<sec-client-assembly>
整条链是：#strong[Protocol-first 定接口 → Assembly 负责注册 → 运行时通过依赖注入解析。]

值得看一眼这个微内核的实现，因为它的核心是一个很小的状态机：

#Skylighting(([#KeywordTok("private");#NormalTok(" ");#KeywordTok("enum");#NormalTok(" Entry ");#OperatorTok("{");],
[#NormalTok("    ");#ControlFlowTok("case");#NormalTok(" pending");#OperatorTok("(");#NormalTok("ProcessAssembly");#OperatorTok(")");],
[#NormalTok("    ");#ControlFlowTok("case");#NormalTok(" assembling");#OperatorTok("(");#NormalTok("ProcessAssembly");#OperatorTok(")");],
[#NormalTok("    ");#ControlFlowTok("case");#NormalTok(" resolved");#OperatorTok("(");#NormalTok("Any");#OperatorTok(")");],
[#OperatorTok("}");],));
三个状态。而整个类的注释只有一句：

#quote(block: true)[
线程安全的服务容器；#strong[装配在锁外执行]，并由状态机保证每个服务只有一个装配者。
]

"装配在锁外执行"是这里的关键。装配一个服务会调用业务代码， 而#strong[在锁内调用业务代码是死锁的标准配方] ------ 那段业务代码可能会去解析另一个服务。

状态机解决的正是这个：先在锁内把条目标记成 #NormalTok("assembling");（这一步是原子的， 保证只有一个装配者），然后#strong[在锁外]跑装配，最后再拿锁把结果写回。

写回的时候还有一道检查：

#Skylighting(([#ControlFlowTok("guard");#NormalTok(" ");#ControlFlowTok("case");#NormalTok(" ");#OperatorTok(".");#NormalTok("assembling ");#OperatorTok("=");#NormalTok(" entries");#OperatorTok("[");#NormalTok("key");#OperatorTok("]");#NormalTok(" ");#ControlFlowTok("else");#NormalTok(" ");#OperatorTok("{");#NormalTok(" ");#KeywordTok("return");#NormalTok(" ");#OperatorTok("}");],));
#strong[只有在这个条目仍然属于本次装配时才发布结果。] 这防的是： 装配进行到一半时，有人调用了 #NormalTok("reset()");（测试的清理路径）， 或者别的什么把这个条目清掉了 ------ 这时候把结果写回去， 会往一个已经被重置的容器里塞一个幽灵服务。

这三十行代码是这一章那句话的最好例子：#strong[它换来的可测性是"装配只发生一次"。] 而这条不变量在测试里是被直接断言的：

#Skylighting(([#NormalTok("XCTAssertEqual");#OperatorTok("(");#NormalTok("assembleCounter");#OperatorTok(".");#NormalTok("value");#OperatorTok(",");#NormalTok(" ");#DecValTok("1");#OperatorTok(",");#NormalTok(" ");#OperatorTok("...)");],));
并发地解析同一个服务，装配计数必须恰好是 1。这是一个#strong[能失败]的断言 ------ 如果状态机写错了，它会红。

=== 这一层禁止三件事
<sec-client-forbidden>
- 跨模块直接实例化具体类型
- 绕过协议访问器直接解析
- #strong[给服务加兜底 fallback]

前两条好理解。第三条值得多说一句。

#strong[只要有兜底，就存在一条不经过正常装配的隐藏路径。] 行为就不再唯一，而测试断言的也就不再是真实运行时会走的那条路。

而它在实践中的形态是这样的（这是一条真实沉淀下来的规则的原话）：

#quote(block: true)[
缺失的服务注册被转成正常业务值或第二实现， 会掩盖组合根错误并制造分裂状态。
]

"掩盖组合根错误"是关键。一个服务没被注册，这是#strong[组装的 bug]， 应该在启动时就炸掉。而一个兜底会把这个 bug 转换成一个看起来合理的默认值， 于是应用照常启动、照常运行，#strong[只是某个功能悄悄不工作了]。

这是形状 A 在运行时的形态：#strong[系统不报错，因为按它自己的标准它没出错。]

#ref(<sec-semantic-rules>, supplement: [第]) 讲过，检查这条规则的分析器有五层过滤 ------ 那五层的复杂度，就是这条边界的价值的度量。

=== 后端：三条禁令是同一个决定的三个面
<sec-backend>
- 不新增数据库外键
- 不依赖数据库的级联行为
- 账号不硬删除，必须软删并清空个人信息

这三条其实是同一个决定的三个面：#strong[删除、解绑、匿名化的引用完整性， 全部在应用层的同一个事务里显式保证，而不是交给数据库的约束去隐式触发。]

好处是删除行为变得可控、可测。而"可测"这里有一个很具体的含义：

#strong[数据库级的级联一旦触发，你既看不到它删了什么，也没办法给它写一条断言。]

你能断言的只有"删完之后这张表是空的" ------ 但那不是行为断言， 那是状态断言，而且它没法告诉你级联的顺序对不对、有没有多删。 把这套逻辑放在应用层的一个事务里，你就能对每一步写断言。

== 交付期：最不可逆的动作，收进唯一一个 owner
<sec-delivery>
前两个阶段出了问题都还能重来，交付这一段不行。

打包、上传、上架、改线上配置 ------ #strong[这些动作一旦做错，重试是挽回不了的]， 所以它们的 owner 必须唯一。

配置文件里那行注释把这件事说得很直白：

#quote(block: true)[
#NormalTok("release/*/v*"); excluded: Mainline owns release builds via API
]

#strong[连看起来最像发布分支的分支模式都被排除在外]， 因为发布的触发权不在分支上，在唯一的那个发布入口手里。

而这个约束在实现上是这样的：五个发版动作 ------ 打包、上传、改元数据、 报符号表、提审 ------ #strong[只接受一种触发模式]。没有 webhook 入口， 没有定时触发，没有裸 API。

#strong[不可逆的动作，连触发方式都要被收窄。]

值得注意的是 Agent 在这条链上能做的事其实不少：建一个新产品 （包括那些不可逆的标识符与签名配置）、出上架截图、调关键词和元数据、 接订阅、提交并盯流水线。

#strong[它能把发布准备到完全就绪的状态 ------ 但最后按下去那一下，始终是人的决定。]

这不是对 Agent 能力的不信任。#ref(<sec-setpoint-outside>, supplement: [章节]) 会说明： 这是一类按定义就在这套系统能力之外的判断。

== 贯穿三个阶段的同一条约束
<sec-assertable>
把上面这些边界连起来看，会发现它们指向同一件事：#strong[让行为可以被断言。]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([架构选择], [换来的可测性],),
  table.hline(),
  [Protocol-first 定接口], [可注入替身，不必起真实依赖],
  [四件套第四格 #NormalTok("Testing/");], [替身有归属，一个 testonly 目标，不各存一份],
  [领域层只依赖抽象], [脱离数据库测业务规则],
  [禁止服务兜底], [没有隐藏路径，行为唯一可断言],
  [契约由声明派生], [四端类型同源可对拍，漂移即失败],
  [构建目标粒度], [测试可分片、只跑受影响的],
  [装配在锁外 + 三态机], ["装配恰好一次"成为可断言的不变量],
  [发布触发权收窄], [不可逆动作的发生是显式的、可审计的],
)
#strong[这张表是本章唯一需要读者记住的东西。]

它给出一个可执行的自检：#strong[拿你自己架构里的每一条规则， 在右边这一列填一个词。填不出来的那条，大概率是装饰。]

装饰性的架构规则不是无害的。它们和真规则长得一样， 消耗同样的注意力去遵守、去审查、去在重构时维护 ------ #strong[而它们不产生任何可验证的东西。] 在 Agent 规模化的场景下， 这个成本会被乘上并行度。

== 三个方向为什么是三个
<sec-why-three-directions>
构建期"一份声明派生多端"、运行期"依赖单向流动"、 交付期"触发权收敛到唯一入口" ------ 这三条看起来是三件事， 但它们是同一件事在三个时间尺度上的形态：

#quote(block: true)[
#strong[让"谁能改变这个东西"这个问题，在每个阶段都只有一个答案。]
]

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([阶段], [那个东西], [唯一的改变者],),
  table.hline(),
  [构建期], [四端的接口类型], [那份声明],
  [运行期], [一个服务的实例], [装配链],
  [交付期], [线上的状态], [发布入口],
)
#strong[三条禁令也因此同构]：

- 构建期禁止手改生成物 ------ 绕过了声明这个唯一改变者
- 运行期禁止跨模块直接实例化 ------ 绕过了装配链
- 交付期禁止旁路触发 ------ 绕过了发布入口

#strong[三次都是同一个形状：一条不经过唯一 owner 的旁路。]

而这三条旁路的共同特点是：#strong[走它们的时候，一切看起来都正常。] 手改的生成物能编译，直接实例化的服务能工作， 旁路触发的发布能发出去。#strong[它们的代价都在以后。]

== 边界的成本要诚实地算
<sec-boundary-cost>
这一章讲了很多边界的好处，但每一条边界都有成本， 而这本书如果不算这笔账就不诚实。

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([边界], [成本],),
  table.hline(),
  [协议优先], [每个服务多一个目标、一层间接],
  [禁止跨模块实例化], [有些"就用一下"的场景要走完整装配],
  [声明派生], [多一个编译步骤，改接口要重新生成],
  [发布触发权收窄], [紧急发布也必须走那条通道],
)
#strong[最后一条的成本最实在]：出线上事故时，那条通道就是关键路径上的额外一环。

而这套系统接受了这个成本，理由在 #ref(<sec-delivery>, supplement: [第])： #strong[打包、上传、上架这些动作做错了重试挽回不了。] 一次错误发布的代价，高于所有紧急发布加起来多花的那几分钟。

#strong[但这个判断依赖于具体场景。] 一个改一行配置就能回滚的服务端系统， 这笔账可能算出相反的结果 ------ 那时候正确的做法是收窄"不可逆"的那部分， 而不是收窄所有发布。

#strong[边界的价值来自不可逆性，不是来自严格本身。]

== 可测性作为架构的唯一裁判
<sec-testability-judge>
#ref(<sec-assertable>, supplement: [第]) 那张表是这一章的核心，但它有一个更强的用法 值得单独说：#strong[把它当成架构讨论的终结器。]

架构讨论最容易陷入的僵局是两个人各有一套说法， 而双方的论据都是"这样更清晰""这样更灵活""这样更符合某某原则"------ #strong[这些都不是可以被检验的命题。]

而"这条边界换来什么可测性"是可以被检验的：

#quote(block: true)[
你说这样分层更好。#strong[那么分层之后， 有什么原来测不了的东西现在能测了？]
]

三种可能的回答，各自意味着不同的事：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([回答], [意味着],),
  table.hline(),
  [具体说出了一样东西], [#strong[这条边界有价值，讨论结束]],
  [说不出，但坚持它更"清晰"], [这是品味，应该被明确标记为品味],
  [说不出，而且承认], [这条边界大概率是装饰，删掉],
)
#strong[第二种是最需要被诚实对待的。]

品味不是坏东西 ------ 可读性、一致性、符合团队习惯， 这些都有真实价值。#strong[但它们不该被伪装成架构规则]， 因为一旦被写成规则，Agent 会把它当成硬约束去满足， 而满足一条品味规则最快的方式通常是抄一段现有代码。

#strong[把品味明确标为品味，Agent 反而能处理得更好] ------ 它知道这里有自由度。

== 三段之间的接缝在哪
<sec-seams>
构建期、运行期、交付期各自的规则讲清楚了， 但#strong[最容易出问题的地方是接缝]，值得单独看。

=== 接缝一：生成物进入运行期
<sec-seam-generated>
一份声明生成了四端的类型，然后这些类型被运行期的代码使用。

#strong[接缝上的问题]：如果有人手改了生成物， 运行期的代码用的是手改后的版本，而下一次重新生成会把它抹掉。

#strong[这个接缝的守卫是对拍测试]（#ref(<sec-drift-detection>, supplement: [第])）------ 它是唯一一个能发现"签入的和生成的不一致"的机制。

=== 接缝二：运行期状态进入交付期
<sec-seam-release>
打包时会把当前的配置、当前的资源、当前的版本号一起打进去。

#strong[接缝上的问题]：这些"当前"的东西从哪来？ 如果它们可以被环境变量覆盖、被本地配置影响， 那么#strong[同一份代码在两台机器上会打出不同的包]。

#strong[这个接缝的守卫是密封构建]：构建的输入被完整声明， 不受环境影响。而这是那个 ⚙️ 依赖图小节里 "密封 + 内容寻址"那一行的实际价值 ------ 它不只是让缓存能复用，它让"这个包里到底是什么"变成一个确定的问题。

=== 接缝三：交付期反馈回构建期
<sec-seam-feedback>
线上出了问题，需要定位到是哪次改动。

#strong[接缝上的问题]：如果构建产物和源码版本之间没有确定的对应关系， 这个定位就是猜的。

#strong[这个接缝的守卫是证据绑定版本]：每个判定都绑在它实际观察到的那个版本上。 而它在这一层的形态是：每个发布产物能追溯到唯一一个源码版本。

#strong[三个接缝的共同点：它们都是"同一份东西在两个阶段之间传递"， 而守卫全都是"确保两边说的是同一件事"。]

== 为什么架构约束在 Agent 场景下更重要
<sec-architecture-agent>
同一套架构约束，在人的团队和 Agent 的团队里，价值不一样。

#strong[三个原因，每一个都指向同一个方向：]

=== 一、Agent 的"影响面直觉"是零
<sec-no-blast-intuition>
一个在仓库里待了半年的人，改一处代码时会有一个模糊的感觉： "这个改动可能会影响到那边"。这个感觉不精确，但它非零， 而且它会随经验变准。

#strong[Agent 每次都是零。]

所以架构约束对它的价值不是"防止它做错"， 而是#strong["给它一个可以查询的影响面模型"] ------ 依赖只向一个方向流动，意味着影响面是可以沿着方向推出来的。

=== 二、Agent 会同时改很多地方
<sec-wide-changes>
人改代码倾向于局部，因为读代码有成本。 #strong[Agent 没有这个阻力] ------ 它可以毫不犹豫地同时改二十个文件。

这让"一次改动穿过了哪些层"这个问题从一个偶尔需要问的问题， #strong[变成了每次都需要回答的问题。]

而架构约束的作用正是让这个问题有一个确定的答案。

=== 三、几十个 Agent 并行时，约束是唯一的协调机制
<sec-parallel-coordination>
人的团队有一个 Agent 没有的东西：#strong[互相知道对方在干什么。]

站会、聊天、"我在改这块你别动"------ 这些非正式的协调在人的团队里承担了大量的边界维护工作。

#strong[几十个并行的 Agent 之间没有任何这类沟通。]

所以那些原本由沟通维护的边界，必须被显式化 ------ 要么写进结构，要么写进检查。#strong[没有第三条路。]

这解释了一个现象：#strong[很多团队在引入 Agent 之后， 才发现自己的架构约束其实一直很松] ------ 不是它变松了，是原本兜住它的那层沟通消失了。

== 架构决定了 Agent 能自主到什么程度
<sec-autonomy-ceiling>
最后一个观察，它把这一章和整本书连起来。

一个 Agent 能自主完成一个任务的前提是： #strong[它能自己判断"我做完了没有"。]

而这个判断需要三样东西：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([需要], [由什么提供],),
  table.hline(),
  [知道该改哪里], [目录结构（#ref(<sec-codebase>, supplement: [章节])）],
  [知道改动会影响谁], [#strong[架构的方向性]],
  [知道改对了没有], [判定层（第三部）],
)
#strong[中间那一行是这一章的全部价值。]

一个依赖方向混乱的系统里，Agent 无法回答"我还需要改什么"， 于是它要么改少了（漏掉了下游），要么改多了（动了不该动的）。

而两种错误的表现是不同的：#strong[改少了会被测试抓到，改多了不会。] 一次多余的改动能编译、能通过测试，它只是#strong[扩大了这次改动的影响面]------ 而影响面的扩大是静默的。

#strong[所以架构的方向性守住的，是一个测试守不住的东西。]

== 一个具体的取舍：什么时候不该抽象
<sec-when-not-abstract>
这一章讲了很多"收敛到唯一 owner"，但收敛本身是一种抽象， 而抽象有它的适用条件。

#strong[判据和目录层级那条是同一个]（#ref(<sec-earned-level>, supplement: [第])）：

#quote(block: true)[
#strong[抽象必须被第二个真实的用例挣得。]
]

而这条在架构上比在目录上更重要，因为#strong[一个过早的抽象比一层空目录贵得多]：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([代价], [空目录], [过早的抽象],),
  table.hline(),
  [直接成本], [一层路径], [#strong[一层间接、一个接口、一批适配代码]],
  [认知成本], [低], [#strong[每个读者都要理解这个抽象]],
  [修改成本], [删掉就行], [#strong[改抽象要改所有实现]],
  [#strong[错误的代价]], [低], [#strong[高 ------ 一个猜错的抽象会扭曲所有后来的代码]],
)
#strong[最后一行是关键]：一个基于单个用例设计的抽象， 它的形状是那个用例的形状。而第二个用例来的时候， 它要么被硬塞进那个形状（扭曲），要么迫使抽象重做。

#strong[而"硬塞进去"是默认发生的]，因为它当下更省事。

=== 那"机制第二次出现就上移"和这条矛盾吗
<sec-not-contradictory>
不矛盾，它们是同一条：

- #strong[第一次]：直接写在它需要的地方，不抽象
- #strong[第二次]：现在有两个真实用例了 ------ #strong[这时候上移，形状是对的]
- 第三次及以后：它已经在共享层了

#strong["第二次"这个时机不是随便定的。] 它是"最早的、 你手里有足够信息来设计正确抽象"的那个时刻。

早一次，你在猜；晚一次，你已经付了重复的代价， 而且两份实现已经开始分叉（#ref(<sec-testing-slot-why>, supplement: [第]) 讲的那种分叉）。

== 架构文档为什么可以很少
<sec-few-arch-docs>
这套系统里几乎没有独立的架构文档。这不是疏忽。

#strong[因为这一章讲的每一条边界，都有一个比文档更好的载体：]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([边界], [它住在哪],),
  table.hline(),
  [依赖方向], [构建文件里的依赖声明 + 一条检查],
  [协议优先], [目录结构（#NormalTok("Protocol/"); 和 #NormalTok("Service/"); 是两个目录）],
  [禁止兜底], [一条语义规则],
  [触发权收窄], [配置里的触发模式声明],
  [生成物由声明派生], [一条对拍测试],
)
#strong[五条边界，零份文档。]

而它们的共同点是：#strong[每一条都住在它约束的那个东西旁边]， 而不是住在一份需要被单独查阅的文档里。

这正是 #ref(<sec-carriers>, supplement: [章节]) 那一章的核心，只不过用在了架构上： #strong[规则的载体应该由"什么时候需要到达"决定] ------ 而架构约束需要在"写这段代码时"到达， 所以它该住在代码结构里，不该住在文档里。

#strong[一份架构文档能做而结构做不到的事只有一件：解释为什么。] 所以剩下的那点架构文档，应该只写"为什么"， 不写"是什么"------"是什么"由结构本身回答。

== 三个方向的例外情况
<sec-direction-exceptions>
三条方向性约束都有它的例外，而#strong[把例外写清楚比假装没有例外好] ------ 因为未被承认的例外会以"绕过"的形式出现。

=== 构建期的例外：需要手改生成物的情况
<sec-exception-generated>
有时候生成器还不支持某个特性，而你现在就需要它。

#strong[错误的做法]：手改生成物，等生成器支持了再说。 （对拍测试会当场红 ------ 这是它存在的意义。）

#strong[正确的做法]：#strong[改生成器，或者在生成物之外扩展。] 后者通常可行：生成的类型可以被扩展（大部分语言支持）， 而扩展代码不在生成物文件里。

#strong[这个例外的处理方式本身就是一条可以抄的原则： 不要修改自动生成的东西，要在它旁边扩展。]

=== 运行期的例外：真正可选的能力
<sec-exception-optional>
"禁止兜底"不等于"所有服务都必须存在"。

有些能力#strong[真的是可选的] ------ 一个只在某些设备上可用的传感器、 一个只对付费用户开放的功能。

#strong[区分的方式是显式的]：那套规则里有一条专门规定 #strong[可选的能力必须提供一个命名明确的"可选访问器"]， 而必需的能力用会 fail-fast 的访问器。

#strong[关键不在于"能不能是可选的"，在于"可选性是不是显式声明的"。]

一个隐式的可选（取不到就用默认值）会掩盖组装错误； 一个显式的可选（明确返回"不可用"）不会。

=== 交付期的例外：紧急发布
<sec-exception-hotfix>
#ref(<sec-boundary-cost>, supplement: [第]) 提过这个成本。#strong[而处理方式不是开一个后门。]

正确的做法是：#strong[让那条唯一的通道足够快]， 而不是在它旁边留一条更快的路。

因为一旦有第二条路，它会在#strong[非紧急的情况下也被使用] ------ 理由永远是充分的（这次很小、这次很急、这次是例外）。

#strong[而"唯一入口"这条约束的全部价值， 就在于它是唯一的。]

== 例外的一条元规则
<sec-exception-meta>
三个例外的处理方式不同，但它们遵循同一条：

#quote(block: true)[
#strong[例外必须走和主路径同一个机制，而不是绕过它。]
]

- 生成物：扩展，不是手改
- 可选服务：显式的可选访问器，不是隐式的默认值
- 紧急发布：让主通道更快，不是开后门

#strong[而这条元规则的理由是]：一个绕过主路径的例外， 它不受主路径上的任何守卫保护 ------ 而例外的情况往往正是最需要守卫的时候 （紧急发布尤其如此）。

== ⚙️ 小规模怎么做
<sec-architecture-small>
这一章里需要重基建的只有"依赖图"那部分（见 #ref(<sec-depgraph>, supplement: [第])）， 其余全都不需要。

三条零基建的：

+ #strong[给你最常改的那个契约做"声明 → 生成"。] 不需要写编译器 ------ 一份 JSON Schema 加一个生成脚本就够了。 关键不是工具多好，是#strong[从此只有一个地方可以改]。
+ #strong[给生成物加一条漂移检测。] 就是在 CI 里重新生成一遍，然后 #NormalTok("diff");。 五行脚本。
+ #strong[把兜底找出来。] grep 你的代码里"取不到就用默认值"的地方， 逐个问：这个默认值是业务上真的合理，还是在掩盖一个组装错误？

第三条通常会找出一批东西，而且找出来之后， 你会发现其中有几个"偶发的诡异 bug"从此不再偶发了。

== 架构和判定的一条隐藏依赖
<sec-arch-verdict-dependency>
#ref(<sec-assertable>, supplement: [第]) 那张表列的是"架构选择 → 换来的可测性"。 反过来看，这张表还有另一层含义：

#quote(block: true)[
#strong[判定层能做到什么，被架构层决定了上限。]
]

三个具体的例子：

#strong[一、没有协议优先，就没法注入替身。] 而没有替身，测试就必须起真实依赖 ------ 于是单元测试变成集成测试， 中位耗时从 7.8 分钟涨到更长，#strong[而回路延迟直接决定性能上限] （#ref(<sec-ground-and-walls>, supplement: [第])）。

#strong[二、没有目标粒度，就没法分片。] 一个把整个产品编成一个目标的仓库， 它的测试只能整体跑 ------ #strong[稀疏测量在这里无效]， 因为最小的测量单位就是全部。

#strong[三、没有生成物由声明派生，就没有对拍。] 四端手写的接口客户端之间没有任何一致性可以被验证 ------ #strong[因为它们没有共同的事实源。]

#strong[所以"环境先于检查"这句话在架构这一层有一个更强的版本：]

#quote(block: true)[
#strong[不是环境更重要，而是有些判定在错误的架构上根本写不出来。]
]

而这解释了一个常见的困惑：#strong[为什么同一套检查方法， 在两个仓库上效果差一个数量级] ------ 不是方法的问题， 是那些检查在其中一个仓库里根本无法被表达 （#ref(<sec-codebase-verdict-link>, supplement: [第]) 讲了目录层面的同一件事）。

== 架构债的一个特殊性质
<sec-arch-debt>
最后一个观察，它解释了为什么架构问题值得被单独拦。

#strong[架构债和代码债的还债成本曲线不一样。]

一段写得不好的代码，重写它的成本大致是恒定的 ------ 今天重写和一年后重写，工作量差不多。

#strong[而一条错误的依赖方向，还债成本随时间超线性增长] ------ 因为在这条边上会不断长出新的依赖， 而每一个新依赖都让解开它更贵。

#strong[这就是为什么结构检查的失败率最高却最便宜是一件好事] （#ref(<sec-high-failure-good>, supplement: [第])）：#strong[它拦的正是那类"现在很便宜、 以后极贵"的问题。]

而这也给出了一个判断标准：#strong[一个架构约束值不值得强制执行， 看它的违规成本随时间怎么变。]

- 成本恒定 → 可以先记账（#ref(<sec-baseline>, supplement: [第])）
- #strong[成本超线性增长 → 应该立刻拦]

== 这一章能被压成的三句话
<sec-architecture-three-lines>
#strong[一、方向决定影响面能不能被计算。]

三段各有一个方向（#ref(<sec-derive>, supplement: [第]) · #ref(<sec-runtime>, supplement: [第]) · #ref(<sec-delivery>, supplement: [第])）， 而方向的价值不在"更整洁"，在于 #strong[Agent 可以沿着方向推出"这次改动会影响谁"] ------ 而它自己没有影响面的直觉（#ref(<sec-no-blast-intuition>, supplement: [第])）。

#strong[二、每条边界必须换来一种可测性。]

#ref(<sec-assertable>, supplement: [第]) 那张表是这一章的核心， 而它给出的自检 ------ #strong[在右边那一列填一个词] ------ 是判断一条架构规则是不是装饰的唯一可执行方式。

#strong[三、不可逆的动作，连触发方式都要被收窄。]

而"不可逆"这个判据贯穿全书： 它决定风险等级（#ref(<sec-arbiter-fields>, supplement: [第])）、 决定该不该给 Agent 某个工具（#ref(<sec-apparent-contradiction>, supplement: [第])）、 决定一条规则该不该立刻拦（#ref(<sec-arch-debt>, supplement: [第])）。

#strong[三句话，而它们的共同底色是： 架构在这里不是审美，是让判定成为可能的那个前提。]

== 一个留给读者的问题
<sec-open-question-arch>
这一章讲的所有边界，都来自一个特定的技术栈组合。

#strong[而有一个问题这本书答不了]： 在一个#strong[没有编译期类型系统]的技术栈里 （比如纯动态语言的项目）， #ref(<sec-feedforward-levels>, supplement: [第]) 那三个层次里的第三层 （做错是不可能的）该怎么达到？

#strong[类型是那一层最主要的工具]，而没有它， 大部分约束只能停在第一层（信息在场）或者 靠外部检查（还是反馈）。

#strong[这不是一个修辞性的问题] ------ 它意味着 在那类技术栈里，这本书讲的"环境先于检查" 可能需要一个不同的实现路径。

而这本书没有那个路径，因为#strong[它的样本里没有这类项目。]

= 载体：规则什么时候到达
<载体规则什么时候到达>
= 载体：规则什么时候到达
<sec-carriers>
这一章讲一件容易被忽略的事：#strong[同一条规则，放错载体就等于不存在。]

它不依赖任何基建，所以是全书对小团队最有用的一章。 也因此它是最长的一章。

== 问题不是"这条规则重不重要"
<sec-carrier-thesis>
一条必须无条件生效的规则，如果藏在需要 Agent 主动去查的地方， #strong[它就形同虚设]。反过来，一条只有跨会话才有意义的约定， 塞进单次会话的上下文里也留不住。

所以真正该问的问题不是"这条规则重不重要"，而是：

#quote(block: true)[
#strong[它什么时候需要到达 Agent？]
]

这个问题有答案，而且答案是可判定的。这就是本章的全部内容。

大部分团队没问这个问题，于是所有规则都被塞进同一个地方 ------ 通常是一份不断变长的常驻文件。而那份文件变长的每一步， 都在稀释它里面每一条规则的到达概率。

== 按到达时机分五种载体
<sec-five-carriers>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([到达时机], [载体], [角色],),
  table.hline(),
  [#strong[永远在场]], [常驻文件], [常驻不变量，无条件触发],
  [#strong[被调用时]], [skill（动词）], [可调用的过程，做完一件事],
  [#strong[主动查阅时]], [guide（名词）], [机制说明，边做边查，不抢占上下文],
  [#strong[碰到路径时]], [路径清单的 #NormalTok("read"); 字段], [改到哪，哪的背景自己浮上来],
  [#strong[跨会话]], [迭代契约], [一次会话装不下的长任务],
)
这张表是本章唯一需要记住的东西。下面五节逐个讲， 但先说一条贯穿所有五种的核心约束。

=== 一条约束比这张表更重要
<sec-unconditional-stays>
配套的文档里写着这样一句：

#quote(block: true)[
必须无条件触发的规则要留在常驻文件本体， #strong[不能挪进按需发现的 skill 或 guide。]
]

理由很简单，也很硬：#strong[一条要等人（或 Agent）想起来才生效的规则， 和没有这条规则的区别不大。]

这句话看起来像常识，但它在实践中被违反得非常频繁， 而且违反的动机总是好的：常驻文件太长了，得瘦身； 这条规则很详细，写成一份专门的说明文档更清楚。

#strong[这两个动机都是对的，而按它们行动通常是错的。] 正确的做法不是把规则挪走，是把规则#strong[压缩]到能留在常驻文件里的长度， 然后把展开的部分放进 guide ------ #strong[规则本身留下，细节移出去。]

== 载体一：永远在场
<sec-always-on>
先看一个可核验的数字：

#quote(block: true)[
#strong[一个 310 万行的仓库，常驻上下文 153 行。]
]

比例约 #strong[1:20,000]。

大部分团队的常驻文件会长到一两千行然后变成噪音。 原因不是没人管，而是#strong["加一条"的成本看起来是零] ------ 它不需要评审、不需要测试、不占用任何人的时间。

而它真实的成本是：#strong[稀释了其余每一条的到达概率。]

一份 1,500 行的常驻文件，和一份 150 行的，对 Agent 来说不是 "信息多十倍"的关系。超过某个长度之后，它更像是一份#strong[背景噪音] ------ Agent 会读它，但不会让每一条都影响自己的动作。

（那份 153 行文件的逐行注解在 #ref(<sec-appendix-always-on>, supplement: [附录]) ------ 包括一条禁令的六个组成部分，以及它#strong[没有]包含什么。）

=== 判断一条规则能不能进常驻文件
<sec-always-on-criteria>
三个判据，按顺序问：

#strong[一、它是否必须在 Agent 落笔之前就在场？]

如果这条规则只在特定任务里才相关（比如"怎么加一个新的埋点指标"）， 它属于 skill 或 guide，不属于常驻文件。

#strong[二、不遵守它的后果是否不可逆或静默？]

可逆且会报错的问题，可以让检查去拦 ------ Agent 撞一次就学会了， 成本是一轮流水线。而不可逆的（改坏了一个已经应用过的迁移） 或静默的（限流悄悄塌成一个桶），必须在动手前就在场。

#strong[三、它能否被写成结构，而不是文字？]

#strong[这一条最容易被忽略，也最重要。]

如果一条规则可以被表达成目录结构、类型定义、依赖方向， 或者一条自动检查 ------ 那它就不该占用常驻文件的位置。

#strong[常驻文件应该是"实在没法写进结构"的那些东西的最后归宿， 不是第一选择。]

按这三条筛一遍，大部分团队的常驻文件会掉下去一半以上。

=== 每条规则都要带着它的失败形态
<sec-rule-with-failure>
这是常驻文件质量的分界线，而且差别巨大。对比两种写法：

#strong[写法一（大多数人写的）：]

#quote(block: true)[
不要用 #NormalTok("sed -i"); 做批量替换。
]

#strong[写法二（真实的那份里的）：]

#quote(block: true)[
#strong[绝不用 #NormalTok("sed -i"); / #NormalTok("perl -i"); / #NormalTok("awk"); / 批量正则原地改文件。] 一个为你推理过的那些调用点写的模式，也会重写你没有推理过的： 已经应用过的 SQL 迁移、生成的锁文件、fixture 与 golden 数据、 设计文档、CI 配置。#strong[损坏是静默的] ------ 构建照样通过， diff 大到没法逐行看，#strong[而一个被重写的迁移在已经跑过它的数据库里无法撤销]。 用 #NormalTok("git mv"); 移动文件，然后 #NormalTok("grep"); 剩余引用，逐个打开、逐个改。 一次跨几百个文件的重命名也是这么做：先枚举全部命中， 提交前读一遍每一个非机械文件的 diff。
]

区别不在字数。区别在于：

- 写法一只能挡住#strong[字面匹配]的那一种（用了 #NormalTok("sed -i");）
- 写法二让 Agent 能够#strong[泛化]到没被列举的情况

一个读了写法二的 Agent，在考虑用某个新工具做批量替换时， 会自己识别出这是同一类风险。而读了写法一的不会 ------ 因为它得到的是一条禁令，不是一个机制。

#strong[这条纪律可以直接抄走：常驻文件里的每一条规则， 都要回答"不遵守会怎样"，而且答案要具体到失败的形态。]

=== 一份常驻文件的其它特征
<sec-always-on-traits>
那份 153 行的文件还有两个特征值得学：

#strong[规则被写成决策程序，而不是口号。]

比如目录层级那条（#ref(<sec-earned-level>, supplement: [第])），它不只是说"每层必须被挣得"， 而是紧接着给了三个真实路径作为判例 ------ 双平台的产品长什么样、 多进程的产品长什么样、单一的产品长什么样。

#strong[一个 Agent 读完能够"判断"，而不只是"遵守"。]

#strong[它预判了 Agent 特有的失败方式。]

文件里有这样几句：

#quote(block: true)[
把评审和追问当成提高抽象层级的信号，而不是打点修复的请求。 不要在一个重复的机制之上打磨业务 bug。 有 #NormalTok("Page"); 这个词、或者能被展示，都不足以让它成为一个 Page。
]

#strong[这三句都不是在描述架构，是在描述 Agent 会怎么想错。] 写这三句的人观察过 Agent 在这些地方失败，然后把观察写了进去。

== 载体二：被调用时 ------ skill
<sec-skills>
这里的 skill 不是提示词模板，而是#strong[把产品的整个生命周期做成了 一批可以调用的过程]。实测 21 个，从建产品到上架，中间每一段都有入口：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([类别], [覆盖的动作],),
  table.hline(),
  [建], [新产品（含不可逆的标识符与签名配置）· 新页面 · 新组件],
  [素材], [生成资产 · 应用图标 · 动画 · 上架截图],
  [商业], [关键词与元数据 · 订阅与付费墙],
  [数据], [加埋点指标 · 查日志],
  [质量], [代码审查 · 架构检查 · 界面打磨 · 设计规范],
  [流程], [合并 · 迭代 · 本地化],
)
关键区分：#strong[skill 是动词（做完一件事），guide 是名词（解释一个机制）。]

这个区分决定了它们各自的发现方式和上下文成本。 一个动词需要被"调用"，所以它必须出现在客户端的发现位置； 一个名词只需要被"查阅"，所以它按路径读就行，不占常驻上下文。

=== 载体的发现机制是代码，不是约定
<sec-projection>
这一节是这一章最硬的证据。

skill 的规范形态存放在一个中立的目录里，然后#strong[被投射到各个客户端的 原生发现位置]。校验脚本里的三行常量把这个结构说得很清楚：

#Skylighting(([#NormalTok("CANONICAL_ROOT ");#OperatorTok("=");#NormalTok(" REPO_ROOT ");#OperatorTok("/");#NormalTok(" ");#StringTok("\"agents\"");#NormalTok("  ");#OperatorTok("/");#NormalTok(" ");#StringTok("\"skills\"");#NormalTok("   ");#CommentTok("# 唯一事实源");],
[#NormalTok("CODEX_ROOT     ");#OperatorTok("=");#NormalTok(" REPO_ROOT ");#OperatorTok("/");#NormalTok(" ");#StringTok("\".agents\"");#NormalTok(" ");#OperatorTok("/");#NormalTok(" ");#StringTok("\"skills\"");#NormalTok("   ");#CommentTok("# 投射一");],
[#NormalTok("CLAUDE_ROOT    ");#OperatorTok("=");#NormalTok(" REPO_ROOT ");#OperatorTok("/");#NormalTok(" ");#StringTok("\".claude\"");#NormalTok(" ");#OperatorTok("/");#NormalTok(" ");#StringTok("\"skills\"");#NormalTok("   ");#CommentTok("# 投射二");],));
#strong[一份规范源，两个投射位置。] 这是"每份可变状态收敛到单一 writer" 用在了 Agent 指令上。

而更值得学的是它对规范源施加的约束。校验脚本里有一张 #strong[可移植性模式表] ------ 这些东西#strong[不许出现在规范源里]：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([被禁止的东西], [为什么],),
  table.hline(),
  [#NormalTok(".claude/"); 路径], [绑定了某一个客户端],
  [#NormalTok(".agents/skills/"); 路径], [同上，绑另一个],
  [#NormalTok("$ARGUMENTS");], [某个客户端特有的参数替换语法],
  [#NormalTok("${CLAUDE_*}");], [某个客户端特有的环境变量],
  [特定客户端的交互工具名], [换个客户端就没有这个工具],
  [序列化的 MCP 工具名], [依赖具体的服务器配置],
  [#strong[个人 macOS 路径] (#NormalTok("/Users/xxx/");)], [换台机器就断],
  [供应商署名行], [会被复制进产物],
  [维基风格的双括号链接], [只在特定编辑器里可解析],
)
这张表的意义远超"代码整洁"：

#strong[它是一条施加在载体本身上的守卫。]

规范源必须是#strong[供应商中立]的；客户端特有的部分 （那份包装里只允许四个键：名称、描述、参数提示、是否禁止模型自动调用） 只能出现在投射层。

#strong[机制与策略分离，用在了 Agent 指令上：skill 是机制，投射是策略。]

而它带来的实际好处是可以验证的：#strong[同一批 skill 同时喂给两个不同的 Agent 客户端]。类似地，常驻文件那边用了一个更省事的办法 ------ 一个符号链接，一份内容两个文件名，因为两个客户端读的是不同的文件名。

这一节想说的是：#strong[载体不是一个约定，是一套有校验的机制。] 如果你的"skill 目录"只是一个大家说好放在那儿的文件夹， 那它会在第三个人加入的那天开始漂移。

== 载体三：主动查阅时 ------ guide
<sec-guides>
guide 是机制说明，边做边查，#strong[无投射，按路径读，不抢占上下文。]

最后这半句是它存在的全部理由。

一份讲"模拟器上有哪些坑"的说明可能有两千字。 它必须存在 ------ 否则 Agent 会花两小时去修一个不存在的 bug （见 #ref(<sec-tool-illusion>, supplement: [第])）。但它#strong[不能常驻]， 因为绝大多数任务跟模拟器无关。

guide 解决的就是这个：#strong[内容可以很长，因为它只在需要时被读。]

判断一件事该写成 guide 还是写进常驻文件，用 #ref(<sec-always-on-criteria>, supplement: [第]) 那三条判据的第一条就够：#strong[它是否必须在落笔之前就在场？]

- "改共享协议后要 grep 所有实现" → 必须在场，进常驻文件
- "模拟器上的调试浮层恒在最上层" → 只在做模拟器相关任务时相关，进 guide

== 载体四：碰到路径时
<sec-path-triggered>
这是最巧妙的一种，也是最容易被忽略的一种。

前三种载体都需要一个#strong[主动动作]才能到达：常驻文件靠"永远读"， skill 靠"决定调用"，guide 靠"想起来查"。

而第四种不需要：#strong[Agent 改到哪个路径，那个路径的背景自己浮上来。]

路径清单里有一个 #NormalTok("read"); 字段，列出"动手之前应该先读什么"。 它不依赖 Agent 记得去查 ------ #strong[触发条件是文件路径， 而文件路径是 Agent 必然会碰到的东西。]

这解决了一个根本问题：#strong[一个 owner 脑子里的不变量， 怎么在他不在场的时候仍然生效。]

#ref(<sec-arbiter>, supplement: [章节]) 会详细讲这一层。这里只需要记住它在载体谱系里的位置： #strong[它是唯一一种"零主动动作"的载体。]

== 载体五：跨会话
<sec-cross-session>
任务的形态决定了它需要什么。

一次性的任务开一个会话就够了，前面四种载体足以支撑它把事情做完。 #strong[但周期性的、要跑很多轮的任务不一样 ------ 它必须有契约， 否则每一轮结束之后什么都留不住，下一轮等于从头开始。]

这类任务又分两种，#strong[退出条件完全不同]：

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([类型], [目标], [怎么退出], [典型任务],),
  table.hline(),
  [#strong[收敛型]], [固定], [跑到完成或预算耗尽], [重构、迁移、修 bug],
  [#strong[演进型]], [每轮被改写], [棘轮式前进：锁定进展、重新瞄准。#strong[靠人判"够好了"]], [研究、写作、产品打磨],
)
区分这两种很重要，因为#strong[给演进型任务设一个"成功就停"的条件是有害的] ------ 它会让任务在第一个看起来达标的地方停下，而演进型任务的价值恰恰在于 它每一轮都在重新定义什么叫达标。

（顺带一提：#strong[写这本书本身就是一个演进型任务。]）

=== 把「记忆」拆开，别糊成一个 blob
<sec-memory-split>
这个机制里最值得借鉴的部分，是它#strong[没有把记忆做成一个笼统的状态文件]， 而是拆成六类，每一类各守各的读写纪律：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([文件], [角色], [纪律],),
  table.hline(),
  [不变意图], [这个任务到底想干什么], [#strong[永不被迭代改；改它 = 人的决定]],
  [当前任务态], [现在做到哪了], [覆盖写，#strong[单一 owner]],
  [决策叙事], [这轮为什么改瞄], [只追加，#strong[不可变]，一轮一条],
  [副作用回执], [对外做了什么 + #strong[怎么回滚]], [只追加，一动作一档],
  [蒸馏的教训], [学到了什么], [#strong[\= 编译过的廉价验证器]；去重、冲突时和解],
  [状态检查], [现在情况怎样], [产结构化读数，#strong[退出码当通过/失败]],
)
这六条纪律和仓库里代码那套是同一套思想，只不过用在了记忆上：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([迭代契约里的], [对应仓库里的],),
  table.hline(),
  [不变意图只有人能改], [路径不变量],
  [状态单一 writer], [owner-first],
  [日志只追加不可变], [证据可追溯],
  [副作用带回滚], [发布的预演模式],
  [检查用退出码], [判定的 0/1/2],
)
#strong[第一行是最要紧的。] 一个能修改自己目标的控制器，永远会报告成功 ------ 它会在遇到困难时悄悄把目标改成自己已经做到的那个。 把不变意图设成"只有人能改"，堵死的正是这条路。

#ref(<sec-setpoint-outside>, supplement: [章节]) 会讲，这条原则在整个系统层面同样成立， 而且那一层上它还没有被贯彻。

=== 节奏由外部反馈延迟决定
<sec-cadence>
周期任务的节奏（多久跑一轮）#strong[不是拍脑袋定的， 而是由外部系统的反馈延迟决定] ------ 改动多久能看到效果，观察周期就得多长。

仓库里现有的两个周期任务正好是两种节奏：

- 一个是#strong[日级]：投放报表按日结算、出价改动约一天见效， 日级是最小有效观察粒度
- 一个是#strong[周级]：元数据要走应用商店审核（一到两天） 加上重新索引（数天）才见效

这一条在控制论里叫#strong[采样周期匹配对象时间常数]（见 #ref(<sec-cadence-theory>, supplement: [第])）。

采样快于对象响应，采到的是噪声 ------ #strong[而且更糟的是，你会依据噪声动作。] 大部分人会为了"响应快"把这类回路设成小时级，然后 100% 在追噪声， 把一个本来会自己稳定下来的系统搅成振荡。

== 一份常驻文件是怎么变长的
<sec-how-it-grows>
知道判据还不够，因为常驻文件变长从来不是一次决定， 而是#strong[几十次各自合理的小决定]。逐个看它们长什么样：

#strong["这条很重要，得加进去。"] 重要不是判据。判据是"它必须在落笔前在场"。 一条极其重要但只在特定任务里相关的规则， 放进常驻文件会稀释其余每一条，而它本可以放在那个任务的 skill 里。

#strong["上次出了事，加一条免得再发生。"] 这是最有说服力也最危险的一种。事故之后加一条规则的冲动很强， 但正确的问题是 #ref(<sec-always-on-criteria>, supplement: [第]) 的第三条： #strong[这次事故能不能被写进结构？] #ref(<sec-incident-to-rule>, supplement: [第]) 里那次 就是反例 ------ 不变量在事故前一天写进了常驻文件，第二天照样出事。

#strong["写清楚一点，免得它理解错。"] 于是一条三行的规则变成十五行。而超过某个长度之后， #strong[详细程度和到达概率是反向关系] ------ 一条十五行的规则， Agent 读到的是它的前两行。 正确的做法是压缩规则本身，把展开部分放进 guide。

#strong["这条和那条差不多，一起放着吧。"] 相似的规则应该被合并成一条更一般的，而不是并列摆着。 两条相似的规则并列，意味着#strong[它们背后那条真正的原则没有被找出来。]

#strong[四种冲动的共同点：它们都在回答"该不该有这条规则"， 而正确的问题是"它该放在哪个载体上"。]

== 载体错配的四种典型
<sec-carrier-mismatch>
反过来看，把规则放错载体会发生什么：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([错配], [后果],),
  table.hline(),
  [无条件规则 → guide], [#strong[形同虚设]，只有想起来查的人才受约束],
  [特定任务的规则 → 常驻文件], [稀释其余每一条的到达概率],
  [路径相关的规则 → 常驻文件], [同上，而且它本可以零成本地精确触发],
  [跨会话的状态 → 单次上下文], [#strong[每一轮从头开始]，前面的进展全部丢失],
)
第三行值得单独说，因为它是最容易被忽略的一种浪费。

一条"改数据迁移时要注意 X"的规则，如果放进常驻文件， 它会在#strong[每一个会话]里占用位置 ------ 而其中 99% 的会话根本不碰迁移。 把它挪进路径清单之后，它在那 1% 的会话里#strong[更醒目] （因为它是被专门触发的），在其余 99% 里#strong[不占任何成本]。

#strong[这是一次纯粹的帕累托改进，而它只需要换一个载体。]

== 五种载体的选择流程
<sec-carrier-decision>
把上面的内容压成一个可以照着走的流程：

#Skylighting(([#NormalTok("这条规则必须在落笔前就在场吗？");],
[#NormalTok("├── 是 → 它能写进结构（目录/类型/依赖/检查）吗？");],
[#NormalTok("│        ├── 能 → 写进结构，不进任何载体      ← 首选");],
[#NormalTok("│        └── 不能 → 只在特定路径下相关吗？");],
[#NormalTok("│                   ├── 是 → 路径清单");],
[#NormalTok("│                   └── 否 → 常驻文件（压缩到一两句）");],
[#NormalTok("└── 否 → 它是一个要做完的动作吗？");],
[#NormalTok("         ├── 是 → skill");],
[#NormalTok("         └── 否 → guide");],));
外加一条正交的：#strong[如果这个任务跨会话，无论上面走到哪一支， 都还需要一份迭代契约。]

这个流程的第一个分叉最重要：#strong[首选永远是"写进结构"。] 每一条留在文档里的规则都是一次失败 ------ 它意味着这条规则 没能被表达成一个 Agent 一读代码就接收到的事实。

== 载体分类为什么有效 ------ 一个机制上的解释
<sec-why-carriers-work>
这一章到这里为止讲的都是"怎么做"。这一节讲"为什么"， 因为#strong[这个解释会告诉你在什么情况下它会失效。]

而值得先说一句：#strong[编解码器那个模型解释不了这一节] （#ref(<sec-model-cost>, supplement: [第])）。载体分类之所以有效， 跟解码的确定性没有任何关系。

它依赖的是三个更具体的机制：

#strong[一、上下文里的东西不是等价的。]

一段文字出现在上下文里，不等于它会等权重地影响输出。 位置、重复、与当前任务的相关性，都会改变它的实际权重。 #strong[一份两千行的常驻文件里，中间那一千行的实际影响力接近于零。]

这解释了为什么 153 行这个数字重要 ------ 它不是审美， 是把每一条都保持在"能实际起作用"的范围内。

#strong[二、模型有它自己的先验，而你的规则在和先验竞争。]

Agent 见过海量代码，它对"日志该怎么写""目录该怎么分" 有很强的先验。你的一条规则要压过这个先验， 需要的不只是"出现在上下文里"，而是#strong[足够具体、足够有理由]。

这解释了 #ref(<sec-rule-with-failure>, supplement: [第]) 那条纪律为什么有效： 带失败形态的规则之所以比裸禁令强，#strong[不是因为它更长， 是因为它给出了一个先验里没有的事实]（"这个操作是不可逆的"）， 而事实比禁令更能改变输出分布。

#strong[三、触发时机决定了它是否参与那次决策。]

一条在决策发生之后才到达的规则，无论多正确， #strong[都不参与那次决策] ------ 它只能触发一次返工。

这是路径清单（#ref(<sec-path-triggered>, supplement: [第])）的全部价值： 它把到达时机绑定在了一个 Agent 必然会经过的事件上。

=== 这个解释预测了什么时候会失效
<sec-carriers-failure-modes>
有了机制解释，就能预测失效：

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([失效], [原因],),
  table.hline(),
  [常驻文件很好但规则还是没被遵守], [它在和一个很强的先验竞争，需要更具体的理由],
  [规则在简单任务里有效，复杂任务里失效], [上下文被任务本身占满了，规则的相对权重下降],
  [同一条规则对不同 Agent 效果不同], [先验不同],
  [加了更多规则之后整体效果下降], [稀释],
)
#strong[最后一行是最常见的]，而且它的反直觉之处在于： 每一条新加的规则单独看都是正确的、有用的， 而它们的总和让系统变差了。

== 一份真实的载体分布
<sec-real-distribution>
作为参照，这套系统的实际分布是：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([载体], [数量],),
  table.hline(),
  [常驻文件], [#strong[153 行，一份]],
  [skill（可调用的过程）], [21 个],
  [guide（按需查阅的说明）], [14 篇],
  [路径清单], [20 份],
  [跨会话契约], [2 个在跑],
)
#strong[注意常驻文件那一行和其余四行的比例。]

按字数算，常驻文件大概占全部 Agent 面向材料的百分之几 ------ #strong[而它是唯一一份每次都在场的。]

这个比例本身就是这一章的论点：#strong[永远在场的东西必须极度克制， 因为它的成本乘上了会话数。]

而其余四类的总量可以很大 ------ skill 和 guide 加起来有十几万字 ------ 因为它们的成本只在被使用时才产生。

#strong[这是一个典型的"稀缺资源 vs 廉价资源"的分配问题]， 而大部分团队把所有东西都堆进了稀缺的那一侧。

== 五种载体各自的失效模式
<sec-carrier-failures>
每一种载体都有它特有的坏法，而#strong[知道坏法比知道用法更实用]。

=== 常驻文件：稀释
<sec-failure-dilution>
#strong[症状]：规则都在，但 Agent 好像只遵守其中一部分，而且是随机的一部分。

#strong[原因]：文件太长，实际权重被摊薄了（#ref(<sec-why-carriers-work>, supplement: [第])）。

#strong[检测]：数一下行数。超过两百行就该警惕，超过五百行基本已经在发生。

=== skill：漂移
<sec-failure-drift>
#strong[症状]：skill 里描述的步骤和实际的做法对不上了。

#strong[原因]：skill 是一份被写下来的过程，而#strong[过程会变，文档不会自动跟着变。]

#strong[检测]：这套系统的做法是给 skill 加校验 （#ref(<sec-projection>, supplement: [第]) 里那个可移植性检查）， 但那只检查形式，不检查内容是否过时。

#strong[这是一个没有被解决的问题]，而它的严重程度随 skill 数量增长。

=== guide：无人问津
<sec-failure-unread>
#strong[症状]：写了，但没人（没有 Agent）去读。

#strong[原因]：guide 的到达依赖"主动查阅"，而主动查阅需要 Agent 先知道有这份 guide 存在。

#strong[缓解]：在常驻文件里留一行索引 ------ 不是内容，是#strong[指针]。 一行"改路由相关的东西之前先读某某"，成本是一行， 而它把 guide 从"可能被发现"变成"一定被知道"。

=== 路径清单：范围漂移
<sec-failure-scope-drift>
#strong[症状]：清单还在，但它匹配的路径在一次重构后变了。

#ref(<sec-death-drift>, supplement: [第]) 讲过这个，它是三种规则死法里最阴的一种。

#strong[检测]：把每份清单的命中次数按时间记下来。 一份从来不命中的清单，要么是路径写错了，要么是那类改动不再发生了 ------ #strong[两种情况都需要处理，而它们看起来一模一样。]

=== 跨会话契约：状态腐烂
<sec-failure-rot>
#strong[症状]：契约文件还在，但里面的状态和现实对不上了。

#strong[原因]：中途有人手工改了外部世界，而契约不知道。

#strong[缓解]：那六类记忆里的"副作用回执"就是防这个的 ------ #strong[每一个对外的动作都要记下它做了什么和怎么回滚。]

== 五种失效的共同点
<sec-carrier-failure-common>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([载体], [失效], [有信号吗],),
  table.hline(),
  [常驻文件], [稀释], [#strong[没有]],
  [skill], [漂移], [没有],
  [guide], [无人问津], [没有],
  [路径清单], [范围漂移], [#strong[有]（命中次数）],
  [跨会话契约], [状态腐烂], [有（回执对不上）],
)
#strong[五种里有三种是完全静默的。]

而这一整章讲的是"规则怎样在正确的时刻到达"------ #strong[结果是这套机制本身，大部分处在没有判定覆盖的状态。]

这是 #ref(<sec-biggest-gap>, supplement: [第]) 那个缺口在载体这一层的形态， 而它的解法也是同一个：#strong[给每一种载体找一个可观测的量] （#ref(<sec-observer-patterns>, supplement: [第]) 里那四种形态都适用）。

比如：常驻文件的行数、skill 的最后修改时间与它描述的代码的最后修改时间之差、 guide 的被引用次数、清单的命中次数。

#strong[四个数，全都是现成的，而且全都没有被采集。]

== 一条规则从写下到生效，中间有几步
<sec-rule-to-effect>
这一章讲"什么时候到达"，但"到达"本身还可以再拆。 一条规则真正影响到输出，中间有四步，#strong[每一步都可能断掉]：

#Skylighting(([#NormalTok("① 它被写下来");],
[#NormalTok("   ↓  断点：写的人和用的载体不匹配");],
[#NormalTok("② 它在正确的时刻出现在上下文里");],
[#NormalTok("   ↓  断点：被更长的上下文稀释");],
[#NormalTok("③ 它的权重足够压过模型的先验");],
[#NormalTok("   ↓  断点：规则太抽象，先验太强");],
[#NormalTok("④ 它改变了这次的输出");],));
#strong[四步里，大部分团队只管了第一步。]

而这一章的三个核心建议，正好各针对一个断点：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([建议], [修哪个断点],),
  table.hline(),
  [按到达时机选载体], [②],
  [每条规则带失败形态], [③],
  [常驻文件保持极短], [②],
)
#strong[第③步的断点最容易被误诊。]

症状是"规则明明写了，它就是不照做"。 而人的第一反应是加强语气（"必须""绝对不能""重要！！"）， #strong[这对权重的影响很小。]

有效的做法是给出一个先验里没有的#strong[事实]： 不是"绝对不要用批量替换"，而是 "一个被重写的迁移在已经跑过它的数据库里无法撤销"。

#strong[前者是强调，后者是信息。而只有信息能改变输出分布。]

== 一份 guide 该多长
<sec-guide-length>
常驻文件要短，而 guide 可以长 ------ 但也不是无限。

判据是：#strong[Agent 会不会读完它？]

而这个问题可以被拆成两个更实际的：

#strong[一、它有没有一个明确的入口问题？] 一份好的 guide 开头就说清楚"你在遇到什么问题时该读我"。 没有这个，Agent 读了前几段发现不相关，就不会继续。

#strong[二、它的结论在不在前面？]

这是和给人看的文档最大的区别。给人的文档可以循序渐进， #strong[给 Agent 的应该结论先行] ------ 因为它可能只读前三分之一。

那份关于模拟器的说明就是这么写的： 它没有从"模拟器是什么"讲起， #strong[它直接说"改取窗逻辑一律无效"]，然后才解释为什么。

== 载体之间的引用关系
<sec-carrier-references>
五种载体之间应该怎么互相引用？有一条简单的规则：

#quote(block: true)[
#strong[只允许从"更常驻"的载体指向"更按需"的载体，不允许反向。]
]

也就是：

#Skylighting(([#NormalTok("常驻文件 → guide            ✓（一行索引）");],
[#NormalTok("路径清单 → guide            ✓（read 字段）");],
[#NormalTok("skill    → guide            ✓");],
[#NormalTok("guide    → 常驻文件          ✗（那条规则本来就在场，不用提）");],
[#NormalTok("guide    → 另一份 guide      ⚠️（可以，但链条不要超过两层）");],));
反向引用的问题是：#strong[它假设读者读过那份常驻文件]， 而这个假设在按需查阅的场景下不一定成立 （一个 Agent 可能只被给了这一份 guide）。

#strong[而两层以上的 guide 链条会失效]，因为每一跳都有一个 "它会不会真的去读"的概率，两跳之后这个概率已经很低了。

#strong[所以 guide 应该是自包含的]：它可以引用代码（那是事实源）， 但不应该依赖读者先读过另一份 guide。

== 载体和判定的关系
<sec-carriers-and-verdict>
这一章属于环境层，但它和判定层有一条明确的连接，值得说清楚。

#strong[每一种载体，都对应判定层的一种失败该被送到哪里。]

一次判定失败之后，Agent 需要三样东西才能收敛：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([需要], [由哪个载体提供],),
  table.hline(),
  [我违反了什么], [规则的 #NormalTok("incident"); 字段],
  [这条路径为什么特殊], [路径清单的 #NormalTok("invariant"); 和 #NormalTok("read");],
  [具体怎么修], [规则的 #NormalTok("fix_hint");，或者一个 skill],
)
#strong[所以载体不只是"规则住哪"，也是"失败信息从哪来"。]

而这解释了 #ref(<sec-incident-hint>, supplement: [第]) 那条纪律的实现方式： 失败信息之所以能带着"为什么"和"怎么修"， #strong[是因为那两样东西在规则定义里就是必填字段] ------ 它们不是运行时拼出来的，是设计时写下来的。

#strong[一个没有 #NormalTok("incident"); 字段的规则，它的失败信息里 不可能有"为什么"] ------ 除非有人在那一刻现写。

== 五种载体和五种到达时机的完整对照
<sec-full-mapping>
把整章压成一张表，作为这一章的收尾：

#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([时机], [载体], [成本], [触发方式], [失效形态],),
  table.hline(),
  [永远在场], [常驻文件], [#strong[每次会话]], [无条件], [稀释],
  [被调用时], [skill], [被调用时], [Agent 决定], [漂移],
  [主动查阅时], [guide], [被读时], [Agent 想起来], [无人问津],
  [碰到路径时], [路径清单], [#strong[命中时]], [#strong[文件路径（零主动动作）]], [范围漂移],
  [跨会话], [迭代契约], [每轮], [任务本身], [状态腐烂],
)
#strong[第四行的"零主动动作"是这张表里最特别的一格。]

其余四种都需要某个主体做一个决定： 读（常驻）、调用（skill）、查阅（guide）、继续（契约）。

#strong[而路径清单不需要] ------ 它的触发条件是一个客观事实 （这次改动碰了哪些文件），而不是一个主观决定。

#strong[这就是为什么它值得被单独发明出来]， 而不是让那些内容散在 guide 里： #strong[guide 依赖"Agent 想起来查"，而那是一个概率事件。]

== 一条选载体的元建议
<sec-carrier-meta>
如果记不住那个流程图（#ref(<sec-carrier-decision>, supplement: [第])）， 记住一个问题就够：

#quote(block: true)[
#strong[这条规则如果被忽略了，会有什么后果？]
]

- 后果#strong[不可逆或静默] → 它必须是无条件到达的 （常驻文件或路径清单）
- 后果#strong[会报错，能被修] → 它可以是按需的（skill 或 guide）

#strong[而"会报错"这个判断，取决于你的判定层建到了什么程度] ------ 这也是为什么这两层必须一起设计。

一个判定层很弱的系统，需要一份很长的常驻文件（因为什么都要靠事先说清）。 #strong[而一个判定层很强的系统，常驻文件可以很短] ------ 因为大部分错误会被当场拦下，Agent 撞一次就学会了。

#strong[153 行这个数字，某种程度上是判定层强度的一个反向指标。]

== ⚙️ 小规模怎么做
<sec-carriers-small>
这一章零基建成本，一个人的项目也完全适用。

#strong[一、把你的常驻文件按那三条判据筛一遍。] 大概率会掉下去一半以上。掉下去的分两拨：能写进结构的写进结构， 不能的做成 guide。

#strong[二、给留下来的每一条补上失败形态。] 如果补不出来 ------ 你写不出"不遵守会怎样"------ 那这条规则可能本来就不该存在。这个测试比它听起来严格得多。

#strong[三、一百行有用的常驻文件，胜过一千行没用的。] 这不是审美主张。一千行里的每一条，到达概率都比一百行里的低。

#strong[四、跨会话的任务，至少要有前两类记忆。] 不变意图（人写、Agent 不许改）和当前状态（覆盖写）。 后四类可以等真正需要时再加。

== 一份常驻文件的演化史
<sec-always-on-history>
这一章讲了怎么写，但没讲它是怎么变成现在这样的。 而演化的过程比结果更有信息量。

#strong[大部分常驻文件的演化路径是这样的：]

#Skylighting(([#NormalTok("① 空的");],
[#NormalTok("② 加了几条最明显的约定（缩进、命名）");],
[#NormalTok("③ 出了事故，加一条");],
[#NormalTok("④ 又出事故，再加一条");],
[#NormalTok("⑤ 变长了，有人抱怨 Agent 不遵守");],
[#NormalTok("⑥ 加粗、加感叹号、加\"重要！\"");],
[#NormalTok("⑦ 更长了，效果更差");],
[#NormalTok("⑧ 有人提议\"整理一下\"");],
[#NormalTok("⑨ 把详细的部分挪进单独的文档");],
[#NormalTok("⑩ 那些规则从此不再生效");],));
#strong[第⑥步和第⑨步是两个典型的错误转向。]

第⑥步（加强语气）无效的原因在 #ref(<sec-rule-to-effect>, supplement: [第]) 的第③步： #strong[权重不是靠语气获得的，是靠给出先验里没有的事实。]

第⑨步（挪进单独文档）的错误更隐蔽，因为它#strong[看起来像是在做正确的事] ------ 文件确实短了，内容确实还在。

#strong[但那些规则的到达时机变了]：从"永远在场"变成"想起来才查"。 而如果一条规则原本需要无条件生效， #strong[这个改动等于删掉了它]（#ref(<sec-unconditional-stays>, supplement: [第])）。

=== 正确的第⑧步是什么
<sec-correct-step-eight>
面对"文件太长"这个真实的问题，正确的动作有三个，按优先级：

#strong[一、把能写进结构的写进结构。] 通常能砍掉最多， 而且砍掉之后约束更强了（#ref(<sec-structure-priority>, supplement: [第])）。

#strong[二、把规则压缩，把展开部分移出去。] 注意是"规则留下，细节移出"，不是"整条移出"。

#strong[三、真正只在特定任务里相关的，才移进 skill 或 guide。]

#strong[三个动作的共同点：它们都不改变任何规则的到达时机。]

而这正是判断一次"整理"对不对的唯一标准：

#quote(block: true)[
#strong[整理之后，每一条规则的到达时机变了吗？] 变了 → 你不是在整理，你是在改变系统的行为。
]

== 载体分类的一个边界
<sec-carrier-boundary>
诚实地说一处这套分类不够用的地方。

#strong[它假设"规则"和"知识"可以被清楚地分开。]

而实际上有一类东西介于两者之间：#strong[领域知识。]

比如"这个业务里，一笔退款要经过三个状态， 而中间状态不能被跳过" ------ 这是规则还是知识？

- 当成规则 → 它太具体，进常驻文件会挤掉别的
- 当成知识 → 它需要在改到相关代码时在场，而 guide 依赖主动查阅

#strong[这套系统的答案是：让它进路径清单的 #NormalTok("invariant"); 字段。]

因为路径清单是唯一一种"零主动动作"的载体（#ref(<sec-full-mapping>, supplement: [第])）， 而领域知识恰好有一个天然的触发条件 ------ #strong[相关的代码路径。]

#strong[但这个答案有它的极限]：如果一个领域知识 不对应任何特定的路径（比如一条跨越十几个模块的业务约束）， #strong[那这套分类给不出好答案。]

而实践中的处理通常是：把它写进 guide， 然后在常驻文件里留一行指针 ------ #strong[一个妥协， 而且它的失效方式是可预测的]（#ref(<sec-failure-unread>, supplement: [第])）。

== 载体分类和"上下文工程"的关系
<sec-context-engineering>
这一章讲的东西，和现在常被叫做"上下文工程"的那一批实践 是同一个问题域，但切法不同。值得对照一下。

#strong[常见的切法是按"内容类型"]：系统提示、示例、 工具定义、检索到的文档、对话历史。

#strong[而这一章的切法是按"到达时机"。]

两种切法的差别在于它们能回答什么问题：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([问题], [按内容切], [按时机切],),
  table.hline(),
  [这段该放哪个字段？], [#strong[能答]], [不直接答],
  [这条规则该不该常驻？], [不直接答], [#strong[能答]],
  [为什么它没生效？], [不直接答], [#strong[能答]（#ref(<sec-rule-to-effect>, supplement: [第])）],
  [文件太长了怎么办？], [不直接答], [#strong[能答]（#ref(<sec-correct-step-eight>, supplement: [第])）],
)
#strong[按内容切解决的是"怎么组装一次请求"， 按时机切解决的是"怎么组织一个仓库的知识"。]

前者是单次的，后者是持续的 ------ 而在一个几十个 Agent 持续工作几个月的系统里，#strong[后者才是主要问题。]

=== 两种切法可以叠加
<sec-two-cuts-compose>
它们不冲突。实际的形态是：#strong[时机决定它住在哪个载体， 内容决定它在一次请求里被放进哪个字段。]

一条常驻规则可能进系统提示，一份被查阅的 guide 可能作为检索结果进上下文 ------ #strong[而它们的"住处"是不同的， 这个不同是持久的，而组装方式是每次都可以变的。]

#strong[所以载体分类是更靠上游的一层决定。]

== 一个跨越两章的观察
<sec-carriers-and-shapes>
最后把这一章和形状表连起来。

#strong[载体错配本身会制造形状 A。]

具体地说：一条被放进 guide 的无条件规则， #strong[它看起来是存在的] ------ 文件在、内容对、 甚至被写得很好。

#strong[而它实际上不生效。]

这和"一个坏掉的检查输出一片绿色"是同一个结构： #strong[系统的状态看起来正常，而它实际上没有在做那件事。]

#strong[所以"我们的规范里写了"这句话， 和"我们的测试通过了"一样，需要被追问一层]：

#quote(block: true)[
#strong[写在哪儿？什么时候到达？谁读了？]
]

三个问题，而大部分团队只能答第一个。

== 这一章能被压成的三句话
<sec-carriers-three-lines>
#strong[一、问题不是"这条规则重不重要"，是"它什么时候需要到达"。]

而这个问题有答案，答案是可判定的 ------ #strong[这是这一章唯一的发明，也是全书最可移植的一个抽象。]

#strong[二、必须无条件生效的规则，不能挪进按需发现的地方。]

因为一条要等人（或 Agent）想起来才生效的规则， #strong[和没有这条规则的区别不大]（#ref(<sec-unconditional-stays>, supplement: [第])）。

而违反这一条的动机总是好的（文件太长了、写详细一点更清楚）， #strong[这就是为什么它需要被写成一条明确的约束， 而不是留给判断。]

#strong[三、每条规则都要带着它的失败形态。]

不是为了严谨，是因为#strong[权重不是靠语气获得的， 是靠给出先验里没有的事实]（#ref(<sec-rule-to-effect>, supplement: [第]) 的第三步）。

== 一个练习：重写你的第一条规则
<sec-rewrite-exercise>
拿你常驻文件里的第一条规则，按这个模板重写一遍：

#Skylighting(([#NormalTok("[禁令或要求，一句话]");],
[#NormalTok("[失败机制：不遵守会发生什么，具体到形态]");],
[#NormalTok("[不可逆性：如果它不可逆，说明为什么]");],
[#NormalTok("[替代方案：那该怎么做]");],
[#NormalTok("[例外的堵截：最可能被提出的例外，以及为什么它也不成立]");],));
#strong[五个部分，通常会从一行变成五到八行。]

而重写完之后问一句：#strong[这五个部分里， 有哪一个是我写不出来的？]

- 写不出#strong[失败机制] → 这条规则可能不该存在
- 写不出#strong[替代方案] → 它会制造困惑而不是指导
- 写不出#strong[例外的堵截] → 它会在第一个"但是"面前失效

#strong[三个"写不出"，各自指向一个不同的问题。]

= 工具链：Agent 够得着什么
<工具链agent-够得着什么>
= 工具链：Agent 够得着什么
<sec-toolchain>
前三章讲的是 Agent #strong[知道什么]，这一章讲#strong[它能做什么]。

而这是四块环境里唯一一块#strong[光靠约束长不出来]的： 目录可以规定、依赖方向可以拦、规则的载体可以安排， 但"Agent 够不够得着"只能靠一件一件把东西造出来。

== 一个环境完美的仓库，可能还是瞎的
<sec-reach>
设想一个仓库：目录结构完美、依赖方向清晰、规则都在正确的载体上、 检查严密到没有一条坏代码能进主干。

#strong[而 Agent 只能改文本文件、跑一下构建。]

那么它看不见自己写的界面长什么样，出不了上架截图，读不到线上日志， 不知道自己刚加的那个按钮在真机上是不是被键盘挡住了。

#strong[这条边界不是靠规范划出来的，是靠有没有人去把工具造出来。]

投入比例比预期大得多：工具链目录下有 #strong[225,192 行 Rust， 占全仓 310 万行的 7.4%]，编译出 38 个二进制。

作为对照，前面整整一章讲的那个检查器运行时是 67,113 行 ------ #strong[工具链是它的三倍多。]

这个比例值得记住，因为它和大部分人的直觉相反。 "给 Agent 建规矩"听起来是主要工作量，实际上#strong["给 Agent 造手"才是。]

== 让 Agent 直接操作真机
<sec-device-control>
第一件工具解决的是"看不见"。

它是一个 MCP 服务，让 Agent 能像人一样操作真机或模拟器上正在跑的 App。 架构是两侧对接的：

- #strong[App 内侧]：调试构建里 App 自己起一个 WebSocket 服务， 通过局域网发现协议把自己广播出去。一部分负责触摸模拟、元素定位、 窗口管理、文本输入和截图，另一部分负责连接与心跳。
- #strong[宿主机侧]：把上面那些能力包成工具暴露给 Agent。

一共 20 个工具，分四类：

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([类别], [工具],),
  table.hline(),
  [操作], [点击 · 滑动 · 缩放 · 旋转 · 长按 · 长按拖拽 · 输入文本 · 跳路由],
  [观察], [截图 · 视图层级快照 · 找元素 · 找全部元素 · 录屏开始/停止],
  [读状态], [列目录 · 取文件 · 查日志 · 设备信息],
  [连接], [连接 · 列连接 · 装组件 · 诊断],
)
#strong[这组工具闭上的是"人盯屏幕"那个环。]

在此之前，一个 Agent 改完界面只能靠单元测试和自己脑补。 现在它可以装上、点进去、截个图、查一下视图层级、 读一眼沙盒里写了什么文件、翻一遍日志，然后判断自己改对没有。

=== 两个设计决定值得学
<sec-synapse-design>
代码里有两处注释，各说明一个不显然的决定。

#strong[第一处：工具目录必须能在不碰设备的情况下列出来。]

#quote(block: true)[
不预连 daemon：#NormalTok("list_tools"); 是静态的，首个 #NormalTok("call_tool"); 才按需连接或拉起。
]

这个决定的理由是：#strong[Agent 问"我能做什么"的频率， 远高于它真的去做什么。] 如果列出工具需要先连上设备， 那么每一个会话都要付一次设备连接的延迟 ------ 而且在没有设备接着的时候会直接失败， 于是 Agent 会以为自己没有这些能力。

#strong[工具的存在性，不该依赖工具的可用性。]

这条可以推广：任何"我能做什么"的查询，都应该比"我去做"便宜一个数量级， 而且不应该有前置条件。

#strong[第二处：设备连接收敛到全机单例。]

#quote(block: true)[
socket 转发给全机单例 daemon。自身不持连接。
]

多个进程不能各自持有到同一台设备的连接 ------ 会互相踩。 所以每个客户端进程只是一个转发壳，真正的连接归一个单例守着。

#strong[又是单一 writer，这次用在了设备句柄上。]

这一条在几十个 Agent 并行的场景下不是优化，是必需品： 260 个工作区如果各自去连同一台测试机，得到的不是"慢"，是"全都连不上"。

== 但工具会制造它自己的假象
<sec-tool-illusion>
这一节是这一章最重要的一节。

给了 Agent 一只手之后，会出现一类新问题：#strong[它开始能观察到东西了， 而它观察到的东西可能是假的。]

说明文档里记着两条真实的：

#strong[一、模拟器默认被判为非生产环境]，于是埋点上报短路、 页面浏览事件不发。结果是#strong[所有依赖页面浏览的功能都永不触发] ------ Agent 会看到一个"功能没生效"的现象，然后去修那个功能。

#strong[二、调试浮层恒在最上层]，把提示和奖励横幅盖住。 现象是"逻辑跑了、界面没出来"。

第二条的处理方式很有代表性，原话是：

#quote(block: true)[
改取窗逻辑一律无效 ------ 浮层按设计恒在最上层，主窗口本来就是正确的宿主。 #strong[把它当选窗 bug 去修会改坏正常路径。]
]

注意最后半句。它没有停在"这是个假象"，而是明确写出了 #strong[如果不知道这是假象、去修它会造成什么后果] ------ 一个正确的窗口选择逻辑会被改坏，而且改坏之后不会立刻报错。

#strong[所以：给 Agent 工具的同时，必须把工具的假象一起给它。] 否则它会拿着一只能操作的手，去修一个根本不存在的 bug， 而且修完之后会真的坏掉一个东西。

这是形状 E（边界处的静默降级）在工具链里的形态。工具是一层边界， 穿过它之后语义变了，而两侧看起来都正常。

== 能操作，还得能复现
<sec-reproducible>
只让 Agent 会点还不够。

同一串操作，这次进去是登录态、下次是新用户，得到的结论就不一样。 #strong[这时候"能操作"反而制造了不确定性] ------ Agent 会观察到两次不同的结果， 然后开始寻找一个并不存在的原因。

解法是一份声明式的自动化 profile，#strong[取代所有散落的环境变量约定]， 换成 App bundle 里的一份 JSON。

一份 profile 声明用户状态、数据层引用哪套 fixture、界面初始状态 （含首屏落在哪条路由）。schema 与产品无关，每个产品实现自己的种子器， 把它翻译成具体的 App 内效果。

实测：#strong[45 份 profile、11 个产品的种子器]，命名一看就知道用途 ------ #NormalTok("e2e-paywall");、#NormalTok("appstore-home");、#NormalTok("i18n-audit-default");。

=== 两条契约让它成为确定性的来源
<sec-profile-contracts>
一份配置如果没有这两条，它只是#strong[又一处可变状态]， 而不是确定性的来源：

#strong[一、必须幂等。] 同一份 profile 跑两次，得到同一个状态。

#strong[二、合并遵循标准的 merge-patch 语义。] 整体状态用一份共享 profile， 每页只用一个编码过的补丁覆盖起始路由 ------ 所以"同一个场景的 20 个页面" 不需要 20 份互相抄的配置。

值得注意的是：#strong[这两条契约在测试里是被直接断言的，不是只写在文档里。] 测试文件里能看到这些用例名：

#Skylighting(([#NormalTok("test_is_idempotent");],
[#NormalTok("test_mergePatch_replaces_scalars");],
[#NormalTok("test_mergePatch_deep_merges_objects");],
[#NormalTok("test_mergePatch_null_deletes_key");],));
最后一条尤其说明问题。merge-patch 语义里， #strong[一个字段被设成 null 表示"删除这个键"]，而不是"把它设成空"。 这是个容易实现错的细节，而它有一条专门的测试守着。

#strong[一个"应该幂等"的东西和一个"有测试证明它幂等"的东西， 在 Agent 手里是两个东西。] 前者会在某次改动后悄悄不幂等， 而所有依赖它的截图任务会开始产出随机结果 ------ 那时候没有人会怀疑到这里。

这正是前面几章反复出现的那条纪律，只是这次用在了 App 的启动状态上： #strong[每份可变状态收敛到单一 owner，而这个 owner 的契约要被断言。]

== 发布大脑：一张声明式的表
<sec-release-brain>
第三件工具解决的是"发布是不可逆的"。

发布逻辑集中在一个约三十万行的 Go 服务里， 它的核心是一张#strong[声明式的工作流注册表] ------ 注释写着它是"每一条业务流水线的唯一事实源"， 变更检测、任务注册、回调注册全都读这张表，而不是各自维护一份。

28 条工作流，六种触发模式：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([类别], [怎么触发],),
  table.hline(),
  [签名], [每天两次定时 + 每周一次全量],
  [#strong[发版]], [#strong[只接受发布模式] ------ 没有 webhook、没有定时、没有裸 API],
  [崩溃], [每 5 分钟扫描，扫描结果驱动后续],
  [导入], [webhook + 定时兜底],
)
#strong[发版那一组是这一章的正例。]

打包、上传、改元数据、报符号表、提审 ------ 这五个动作 #strong[没有 webhook 入口、没有定时触发、没有裸 API]， 只能由发布流程本身驱动。

#strong[不可逆的动作，连触发方式都要被收窄。]

=== 这张表实际跑成了什么样
<sec-registry-reality>
每一次执行都被记下来，所以这些不是设计意图，是能查的账：

#strong[近四个月 181,570 次执行，日均约 1,441 次]，整体成功率 98.3%。

流水线那一侧的分布更能说明问题。最近 13 天的 1,200 条流水线：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([触发来源], [条数], [占比],),
  table.hline(),
  [改动事件], [564], [47.0%],
  [#strong[发布大脑自己调起]], [#strong[320]], [#strong[26.7%]],
  [push], [315], [26.2%],
  [人在网页上点], [#strong[1]], [0.1%],
)
#strong[每四条流水线就有一条不是人推出来的。而十三天里，人手动点的只有一次。]

== 一个反例：签名自动修复挂了四个月
<sec-signing-failure>
现在讲这一章的反例，也是全书最重要的一节之一。

签名这一组本来是最想拿出来讲的：证书会过期，过期了构建就红， 常规做法是等它红了人去后台点一遍。这里有三条定时任务顶着 ------ 每天体检、每天自动刷新、每周全量重签，仓库里躺着 46 份配置文件、 4 个团队的证书。听起来这类问题应该被彻底消灭掉。

翻账的时候才发现不是：

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([工作流], [执行], [失败], [失败率],),
  table.hline(),
  [体检], [126], [3], [2.4%],
  [#strong[自动刷新]], [126], [#strong[46]], [#strong[37%]],
  [#strong[全量重签]], [18], [#strong[16]], [#strong[89%]],
)
失败原因很具体。自动刷新的 46 次失败里，#strong[29 次是同一个空指针崩溃， 最早一次到最近一次跨了四个月。]

至于体检，它只在最早的三天失败过，之后 123 天零失败。

#quote(block: true)[
#strong[探测是可靠的，修复是坏的。]
]

=== 为什么四个月没人发现
<sec-why-four-months>
因为#strong[它坏了不产生任何可见后果。]

抽查最近 35 次构建与发布的脚本失败，只有 1 次跟签名有关， 而且不是证书过期，是权限声明与配置文件对不上。 #strong[构建照样在绿，没有人被这个崩溃挡住过路，于是它就一直挂在那里。]

这正是全书那句话的反面：

#quote(block: true)[
#strong[一个不产生判定的动作，坏了你不会知道。]
]

检查失败会返回退出码、CI 会变红、Agent 会被挡住； 而一条定时任务失败，只是记录表里多了一行"失败"， #strong[没有任何人或机器把它当成需要行动的信号。]

=== 但归因还要再深一层
<sec-deeper-attribution>
上面那个诊断是对的，但它不完整。真正该追问的是：

#strong[自动刷新挂了 37%、全量重签挂了 89%，构建为什么一直是绿的？]

如果这三条任务真的在维持签名有效性，那么它们失败到这个程度， 证书应该早就过期了，构建应该早就红了。

最可能的解释是：#strong[这三条任务从头到尾就没起过作用。] 真正在维持签名有效性的是别的东西 ------ 可能是构建工具的自动签名， 可能是证书还没到期，可能是有人手动补过。

所以这不只是"监控缺失"，它同时是：

#quote(block: true)[
#strong[一个新建的自动化上线时，从来没有验收标准来证明它在做事。]
]

而这恰恰是 Agent 大量产出基建代码时最典型的失败模式 ------ Agent 很擅长写出一个"看起来在做这件事"的定时任务， 而如果没有人问"怎么证明它真的做了"，这个任务会一直挂在那里， 既不工作也不报错。

顺带还有一个同类的数字：#strong[这 28 条工作流里有 5 条从注册之后一次都没跑过。] 注册表是唯一事实源，但#strong["注册了"和"在跑"是两件事]，中间同样缺一层判定。

#ref(<sec-observer>, supplement: [章节]) 会讲这个缺口该怎么补，而且给出的答案不是"加监控"。

== 工具链内部也在守同一条纪律
<sec-toolchain-discipline>
最后一件事最能说明这套东西的一致性。

伪本地化审计流水线要做的事是：切语言 → 装包 → 逐页启动 → 等渲染完 → 截图 → 文字识别 → 分类。它的注释记着自己是怎么来的：

#quote(block: true)[
取代旧的 148 行脚本。旧脚本用固定的 #NormalTok("sleep 6 + sleep 3");， 在冷启动加重初始化的路径上会产生假阴性。 现在改成盯日志流里的路由事件。
]

#strong[这和测试那章的 flake 教训是同一条]（见 #ref(<sec-wall-clock>, supplement: [第])）------ 别拿时间赌，上界要用真正代表"这件事发生了"的信号。 只不过它这次发生在工具链里，而不是测试里。

它的分层也照搬了检查器的做法：模型层从构建图派生出数据模型（纯，不碰 I/O）， 静态层做完整度与一致性分析（纯），运行时层才是那个要起模拟器、 跑文字识别的重家伙。注释里直接写着这是"镜像了架构检查引擎"。

=== 但这条纪律还没走完
<sec-discipline-incomplete>
诚实地补一句。整个仓库 150 万行 Swift 生产代码里， 违反"别拿时间赌"这条纪律的轮询#strong[只剩 7 处]， 其中 4 处是系统 API 的契约要求（那些 API 只能轮询，没有回调）， 1 处是外部引入的代码。

#strong[真正的违规只有 1 处 ------ 而它在最核心的那个运行时文件里]， 是一个服务解析的等待循环，用毫秒级轮询加固定次数上界。 而且那条路径没有测试覆盖。

这一节想说的不是"他也会犯错"。是：

#quote(block: true)[
#strong[纪律的推进是由外向内的。工具链先改，最核心的运行时最后改。]
]

这个顺序不是偶然。工具链的问题会立刻表现成"审计流水线出假阴性"， 而微内核那个轮询在正常情况下几乎不会触发（它只在两个线程同时解析 同一个未装配服务时才走到）。#strong[看得见的先修，看不见的留到最后 ------ 即使后者更危险。]

这和 #ref(<sec-promotion-counter-example>, supplement: [第]) 里磁盘满重复五次是同一件事： #strong[判定覆盖到哪里，纪律就执行到哪里。]

== 这一章的结论
<sec-toolchain-conclusion>
#strong[给 Agent 造工具，难的不是让它能点。]

难的是让它点完之后，#strong[你能确定刚才发生了什么] ------ 所以才有幂等的启动状态、有代替 sleep 的就绪信号、 有把假象一起写下来的说明、有静态的工具目录、有单例的设备连接。

但签名那个反例说明，这套纪律在工具链里还没走完。 前三章讲的检查全都作用在#strong[代码]上：改了什么、放得对不对、守住了哪条不变量。 而工具链里跑的这一万多次定时任务，#strong[没有任何一层检查在管它们] ------ 它们是给 Agent 生产确定性的东西，自己却处在确定性覆盖之外。

== 工具链投入的三个阶段
<sec-toolchain-stages>
7.4% 这个数字容易吓退人。但这笔投入不是一次付清的，它有明确的阶段， 而且#strong[每个阶段的边际收益差别很大]。

#strong[第一阶段：让 Agent 能看见它改了什么。] 截图、日志、状态查询。这一阶段的收益最陡 ------ 从"完全瞎"到"能看见"是一个质变，而不是量变。 大部分团队缺的是这一阶段，而它通常只需要几百行胶水代码。

#strong[第二阶段：让观察可复现。] 幂等的启动状态、固定的种子数据、就绪信号代替固定等待。 这一阶段的收益不如第一阶段陡，但#strong[它是第一阶段能否被信任的前提] ------ 一个不可复现的观察，比没有观察更糟，因为它会让 Agent 追一个不存在的原因。

#strong[第三阶段：让不可逆的动作有唯一入口。] 发布、签名、上架。这一阶段的收益是#strong[避免灾难]， 而不是提高效率 ------ 所以它的价值不体现在任何效率指标上。

#strong[三个阶段必须按顺序做。] 跳过第二阶段直接做第三阶段， 会得到一个"能自动发布但没人知道发出去的是什么"的系统。

== 一个可以直接抄的判据
<sec-tool-criterion>
判断该不该造一个工具，有一个比"这样会更方便"更硬的判据：

#quote(block: true)[
#strong[Agent 现在是在观察，还是在猜？]
]

如果它在猜 ------ 猜界面长什么样、猜日志里有什么、猜这个改动在真机上生效没有 ------ 那么这个工具的价值不是"提高效率"，是#strong[把一个猜测变成一个事实]。

而猜测和事实的差别在 Agent 场景下被放大了，因为： #strong[Agent 的猜测会被它自己当成事实继续往下推。] 它不会说"我猜界面是这样"，它会直接基于那个猜测做下一个决定。

#strong[所以每一个"它只能猜"的地方，都是一条会静默产生错误结论的路径。]

== 为什么这一块不能靠约束长出来
<sec-why-not-constraint>
这一章开头那句话值得展开：#strong[四块环境里，只有工具链光靠约束长不出来。]

前三块的共同点是：#strong[它们都可以通过"禁止"来改善。] 禁止把文件放错地方、禁止错误的依赖方向、禁止把规则放错载体 ------ 每一条禁令都让环境变好一点，而禁令本身几乎是零成本的。

#strong[而工具链没有对应的禁令。]

你没法通过"禁止 Agent 猜界面长什么样"来让它看见界面。 唯一的办法是有人去写那 18,000 行代码。

这个区别有一个实际后果：#strong[在资源紧张时，工具链永远是第一个被砍的。] 因为砍掉它不会立刻违反任何规则，也不会让任何检查变红 ------ #strong[它的缺席是静默的]，表现为 Agent 的产出质量缓慢下降， 而没有人能把这个下降归因到"我们没给它眼睛"。

这是形状 A 在投入决策上的形态：#strong[没有判定覆盖的东西，坏了你不会知道 ------ 包括"没有建"这种坏法。]

== 一个工具的完整交付包含什么
<sec-tool-delivery>
这一章反复说"造工具"，但一个工具交付完成的标准是什么？ 把它列清楚，因为#strong[大部分工具只交付了第一项。]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([交付项], [缺了会怎样],),
  table.hline(),
  [① 能力本身], [没有工具],
  [② #strong[它的假象]], [Agent 拿着能操作的手，去修一个不存在的 bug],
  [③ #strong[它的前置条件]], [在条件不满足时给出误导性的结果],
  [④ #strong[失败时的语义]], [失败被误归成"代码错了"],
  [⑤ #strong[可复现的初始状态]], [同一串操作两次结论不同],
)
#strong[第二项在 #ref(<sec-tool-illusion>, supplement: [第]) 讲过，第五项在 #ref(<sec-reproducible>, supplement: [第]) 讲过。 这里补第三和第四项。]

=== 前置条件必须是显式的
<sec-preconditions>
一个截图工具，在没有设备连接时应该怎么表现？

三种可能：

- 返回一张空图 → #strong[最坏]，Agent 会以为界面是空的
- 报一个泛泛的错误 → 中等，Agent 知道失败了但不知道为什么
- #strong[报"没有设备连接"] → 正确，Agent 知道该先连设备

#strong[这三种在实现上的差别只有几行代码，而在使用上的差别是巨大的。]

而 #ref(<sec-synapse-design>, supplement: [第]) 里那个"工具目录静态化"的决定， 正是这条纪律的一个应用：#strong[工具的存在性不依赖它的可用性] ------ Agent 总能知道有哪些工具，即使现在一个都用不了。

=== 失败的语义要和判定层对齐
<sec-tool-failure-semantics>
这一项最容易被忽略。

一个工具失败了，它是"你用错了"还是"环境不行"？ #strong[这个区分就是 #ref(<sec-cannot-judge>, supplement: [第]) 那个退出码三分， 只不过发生在工具这一层。]

如果一个工具在设备没连时和在参数写错时返回同样的错误， 那么 Agent 无法区分"我该改参数"和"我该等设备" ------ #strong[它会去改参数，反复地改。]

#strong[这一项的成本几乎为零（多一个错误类型）， 而它决定了 Agent 在工具失败时会浪费多少轮。]

== 工具链的投入曲线为什么是反直觉的
<sec-toolchain-curve>
最后一个观察。

大部分基础设施投入的收益曲线是#strong[递减]的： 第一台 CI 机器的价值远高于第十台。

#strong[而工具链的收益曲线在早期是递增的。]

原因是：#strong[Agent 的每一项能力都在放大其它能力的价值。]

- 只能截图 → 能看到界面，但不知道点了之后会怎样
- 截图 + 点击 → 能验证交互
- 截图 + 点击 + 读日志 → 能诊断为什么交互不对
- 再加上可复现的初始状态 → #strong[前三项的结论开始可信]

#strong[每加一项，前面所有项的价值都上升了。]

这解释了一个常见的困惑："我们给 Agent 加了截图工具， 好像也没什么用" ------ 因为单独一项能力经常真的没什么用。 #strong[这条曲线的膝点大概在三到四项能力之间。]

而这也解释了为什么工具链的投入容易被中途放弃： #strong[它的回报在膝点之后才出现，而膝点在前面看不见。]

== 工具的接口设计有它自己的一套要求
<sec-tool-interface>
给 Agent 用的工具，和给人用的工具，接口设计的取舍不一样。 列几条差别，因为它们不显然：

=== 一、返回结构化数据，不是给人看的文本
<sec-structured-output>
一个给人看的命令行工具，输出通常是格式化的文本。 #strong[而 Agent 消费这类输出需要解析，而解析是一个会出错的步骤。]

更要命的是：#strong[解析失败通常是静默的] ------ 它会得到一个部分正确的结果，然后基于它继续。

#strong[这是形状 E（边界处的静默降级）在工具接口上的形态。]

=== 二、错误要可分类，不只是可读
<sec-classifiable-errors>
#ref(<sec-tool-failure-semantics>, supplement: [第]) 讲过。补一条实现建议： #strong[错误的类型应该在结构上可区分，不是靠错误消息的文字。]

因为消息文字会变（改一次措辞就变了）， 而 Agent 如果靠匹配文字来分类，它会在某次无关的改动后静默失效。

=== 三、幂等优于回滚
<sec-idempotent-over-rollback>
一个操作如果可以被安全地重复执行， #strong[Agent 就不需要知道上一次执行到哪了。]

而这一点很重要，因为#strong["上一次执行到哪了"是 Agent 最容易丢失的信息] ------ 它可能在中途被打断、上下文被截断、或者干脆是一个新的会话。

#ref(<sec-profile-contracts>, supplement: [第]) 里那个"必须幂等"的契约， 在这个视角下有了第二层理由：#strong[它不只是为了让观察可复现， 也是为了让操作可以被安全重试。]

=== 四、状态查询要比状态修改便宜得多
<sec-cheap-queries>
因为 Agent 会频繁地问"现在是什么状态"------ 远比人频繁，因为它没有"我刚才看过了"这个记忆。

#strong[如果查询很贵，Agent 会减少查询，然后基于过期的假设行动。]

#ref(<sec-synapse-design>, supplement: [第]) 里那个"工具目录静态化"是这条的一个特例。

== 一张对照表：给人的工具 vs 给 Agent 的工具
<sec-tool-comparison>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([维度], [给人], [给 Agent],),
  table.hline(),
  [输出], [好看、简洁], [#strong[结构化、完整]],
  [错误], [消息清楚], [#strong[类型可区分]],
  [重复执行], [通常会警告], [#strong[应该幂等]],
  [查询成本], [无所谓], [#strong[必须便宜]],
  [前置条件], [隐含（人知道）], [#strong[必须显式报出]],
  [文档], [单独一份], [#strong[和工具在一起，且包含假象]],
)
#strong[最后一行是这一章最该被记住的]（#ref(<sec-tool-illusion>, supplement: [第])）。

而这张表也解释了为什么"把现有的人用工具包一层给 Agent" 经常效果不好 ------ 六个维度里有五个需要改。

== 一个现实的建议：先包装，再重写
<sec-wrap-first>
上面那张表可能让人觉得要重写所有工具。不必。

#strong[正确的顺序是：先包一层薄的适配，跑一段时间， 再决定哪些值得重写。]

包装层做四件事，每一件都是几十行：

+ 把文本输出解析成结构化数据
+ 把退出码和错误消息映射成可区分的类型
+ 在前置条件不满足时明确报出来
+ 把已知的假象写在这个包装层旁边

#strong[跑一段时间之后，你会知道哪个工具被调用得最频繁 ------ 而那才是值得重写的那个。]

这个顺序还有一个好处：#strong[包装层本身就是一份规格]， 它记录了"Agent 需要这个工具的哪些能力"， 而重写时这份规格是现成的。

== 工具链和判定层的交界
<sec-tool-verdict-boundary>
有一类东西既像工具又像判定，值得单独辨析， 因为#strong[放错位置会导致它两边都不管]。

典型的例子：一个"跑起来看看有没有崩"的脚本。

- 当#strong[工具]用：Agent 主动调用它来验证自己的改动 → 它属于工具链
- 当#strong[判定]用：CI 自动跑它，失败就拦 → 它属于判定层

#strong[同一个脚本，两种用法，而它们的要求不一样：]

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([], [作为工具], [作为判定],),
  table.hline(),
  [谁调用], [Agent 主动], [自动，每次],
  [失败的含义], ["再试试别的"], [#strong["这次不算数"]],
  [输出要求], [信息丰富], [#strong[结论明确 + 证据]],
  [是否需要退出码三分], [不必], [#strong[必须]],
  [是否需要哨兵], [不必], [#strong[需要]],
)
#strong[最常见的错误是：把一个当工具写的东西直接接进 CI 当判定用。]

后果是：它的失败语义不清楚（Agent 不知道该改代码还是改环境）， 它没有哨兵（坏了会静默通过），它的输出是给人看的（下游要解析）。

#strong[判据很简单]：它的失败会不会挡住合并？ 会 → 它是判定，按判定的标准要求它。

== 一个工具链投资的优先级排序
<sec-tool-priority>
如果预算有限，按这个顺序：

#strong[第一优先：让 Agent 能观察它改的东西的直接结果。] 截图、日志、状态查询。#ref(<sec-toolchain-stages>, supplement: [第]) 的第一阶段。

#strong[第二优先：让那些观察可复现。] 幂等的初始状态。#strong[否则第一优先的投入会打对折] ------ 不可复现的观察会让 Agent 追一个不存在的原因。

#strong[第三优先：把不可逆的动作收窄到唯一入口。] 这一项的收益是避免灾难，不体现在任何效率指标上， #strong[所以它最容易被排到后面 ------ 而它应该在第三位，不是最后。]

#strong[第四优先及以后]：一切"让它更方便"的东西。

#strong[注意前三项都不是"更方便"，它们分别是： 能不能观察、观察可不可信、错了能不能挽回。]

而第四项之后的东西，收益是线性的；前三项的收益是阶跃的。

== 工具链腐化的信号
<sec-tool-decay>
工具会坏，而工具坏掉的方式和代码不一样 ------ #strong[它通常不会报错，它会开始返回过时或错误的结果。]

三个可以观察的信号：

#strong[一、Agent 开始不用某个工具了。] 如果一个工具存在但 Agent 不调用它，两种可能： 它不知道有这个工具（载体问题），或者它用过发现不好用。 #strong[两种都值得查。]

#strong[二、同一个工具的调用后面经常跟着"手工验证"。] 说明 Agent（或人）不信任它的输出。

#strong[三、工具的文档和它的行为对不上。] 这是 #ref(<sec-failure-drift>, supplement: [第]) 讲的那种漂移， 而工具比 skill 更容易发生，因为工具的实现会跟着依赖升级而变。

#strong[三个信号的共同点：它们都不会让任何检查变红。]

而这就回到了这一章的结论：#strong[工具链自己处在判定覆盖之外]， 所以它的腐化是静默的（#ref(<sec-toolchain-conclusion>, supplement: [第])）。

== ⚙️ 小规模怎么做
<sec-toolchain-small>
这一章的投入门槛是全书最高的，但有三件事不需要任何基建：

#strong[一、列出你的 Agent 现在够不着的东西。] 不是"应该有的功能"，是"它现在只能靠猜的东西"。 典型答案：它看不到界面、读不到线上日志、跑不了真实的数据库查询。

#strong[二、每给一个工具，同时写下它的假象。] 一句话就够，但必须写"如果不知道这是假象、去修它会怎样"。

#strong[三、给任何一个自动化定时任务，先想清楚验收标准。] "怎么证明它真的做了事" ------ 如果答不上来， 那它上线之后大概率会变成那个挂了四个月的崩溃。

== 这一章的一句话
<sec-toolchain-oneline>
#quote(block: true)[
#strong[前三块环境降低 Agent 做错的概率， 这一块决定它能不能知道自己做对了。]
]

而"知道自己做对了"这件事，是自主性的全部前提 （#ref(<sec-autonomy-ceiling>, supplement: [第])）。

一个够不着验证手段的 Agent，它的每一次"完成"都是一个猜测 ------ #strong[而猜测会被它自己当成事实继续往下推]（#ref(<sec-tool-criterion>, supplement: [第])）。

#strong[所以工具链的投入不是在提高效率，是在把猜测变成事实。]

而这也是为什么它的收益曲线在早期是递增的 （#ref(<sec-toolchain-curve>, supplement: [第])）：#strong[每多一项能力， 就有一批原本只能猜的东西变成了可以查的。]

== 一个被低估的工具类别：只读的
<sec-readonly-tools>
这一章讲的大部分工具都涉及操作 ------ 点击、输入、装包、发布。

#strong[而收益最高的那一批往往是只读的。]

原因有三条：

#strong[一、只读工具的风险接近零。] 一个查日志的工具最坏的情况是查错了， 而一个点击的工具最坏的情况是把生产数据点没了。

#strong[这个差别意味着只读工具可以被更早、更宽松地开放。]

#strong[二、Agent 需要读的次数远多于写。] #ref(<sec-cheap-queries>, supplement: [第]) 讲过：它没有"我刚才看过了"这个记忆， 所以它会反复地问"现在是什么状态"。

#strong[三、只读工具是写工具的前提。] 你没法验证一个写操作的效果，除非你能读到它的结果。

#strong[所以正确的建设顺序是：先把所有的"看"补齐，再补"做"。]

而实践中常见的顺序是反的 ------ 因为"让 Agent 能自动部署" 听起来比"让 Agent 能查日志"更有价值。

=== 一份只读工具的清单
<sec-readonly-list>
按通用程度排，大部分项目都适用：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([工具], [它替代了什么猜测],),
  table.hline(),
  [查最近的日志], ["它跑起来了吗、报了什么错"],
  [查当前的配置/环境变量], ["这个值现在是什么"],
  [查数据库/存储的当前状态], ["我刚写进去的东西在吗"],
  [截一张界面的图], ["它长什么样"],
  [查一个进程/服务的健康], ["它还活着吗"],
  [查依赖的版本], ["我们用的是哪个版本"],
)
#strong[六个，每一个通常几十行，而它们合起来能消掉 Agent 大部分的猜测。]

== 工具链的一条反直觉建议
<sec-tool-counterintuitive>
最后一条，它和"工具越多越好"的直觉相反：

#quote(block: true)[
#strong[不要把所有能力都做成工具。有些东西应该保持"人才能做"。]
]

具体是哪些？#strong[那些不可逆、且判断依赖外部目标的。]

#ref(<sec-delivery>, supplement: [第]) 讲过：Agent 能把发布准备到完全就绪， #strong[但最后按下去那一下始终是人的决定。]

而这不是"能力不够"，是#strong[刻意不给] ------ 因为那个动作对应的判断在环外（#ref(<sec-setpoint-outside>, supplement: [章节])）。

#strong[一个工具的存在会创造使用它的压力。]

如果发布是一条命令，那么"要不要现在发"这个问题 会更容易被跳过 ------ 不是因为有人决定跳过， #strong[而是因为不跳过需要额外的动作。]

#strong[所以在不可逆的动作上保留摩擦，是一个设计选择， 不是一个遗留问题。]

== 这一章和第七章的一处矛盾
<sec-apparent-contradiction>
#ref(<sec-delivery>, supplement: [第]) 讲交付期时说"触发权收敛到唯一入口"， 而这一章讲工具时说"给 Agent 更多能力"。

#strong[这两条看起来矛盾，但它们不是。]

区分它们的是#strong[可逆性]：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([动作], [该给 Agent 吗],),
  table.hline(),
  [截图、查日志、读状态], [#strong[给] ------ 只读，零风险],
  [装包、点击、跳路由], [#strong[给] ------ 在测试环境里可逆],
  [改本地配置、跑迁移（测试库）], [给，但要有回滚],
  [#strong[打包、上架、改线上配置]], [#strong[不给] ------ 不可逆],
)
#strong[四行是一条连续的谱，而分界线是"错了能不能挽回"。]

而这条分界线和路径不变量那边的风险分级用的是同一个判据 （#ref(<sec-arbiter-fields>, supplement: [第])）------#strong[这不是巧合， 是同一条原则在两个地方的应用。]

=== 那"把发布准备到就绪"算哪一类
<sec-ready-to-release>
#ref(<sec-delivery>, supplement: [第]) 说 Agent 能把发布准备到完全就绪的状态。 而"准备"和"执行"之间的那条线，正是这一章的答案：

#strong[所有的准备工作都是可逆的] ------ 生成的截图可以重新生成，写好的元数据可以改， 打好的包可以扔掉。

#strong[而"提交审核"那一下不可逆。]

#strong[所以正确的设计不是"限制 Agent 的能力"， 是"在不可逆的那一步保留摩擦"]（#ref(<sec-tool-counterintuitive>, supplement: [第])）。

#strong[这个区分让"给 Agent 更多能力"和"收窄不可逆动作" 可以同时成立，而且它们指向同一个方向： 把 99% 的工作交出去，把那 1% 留住。]

= 小规模怎么做（环境层）
<小规模怎么做环境层>
= 小规模怎么做（环境层）
<sec-small-scale-environment>
这一章和 #ref(<sec-small-scale-verdict>, supplement: [章节]) 是全书的分界线。

没有它们，前面几章就是一次博物馆导览 ------ "看，我建了这些"。 #strong[有它们，才是一本工具书。]

所以这一章有一条硬约束：#strong[不许出现任何需要重基建的建议。 每一条都要能在一周内、用现有工具链落地。]

== 先分清必需前提和特定选择
<sec-prerequisites>
前面五章里的东西，混着两类：#strong[这套方法的必需前提]， 和#strong[这个团队的特定选择]。分不清这两者，读者会以为门槛比实际高十倍。

#strong[必需前提（没有就不成立）：]

- 一条主干 + 短生命周期分支
- 一个能在合并前跑的自动检查入口（任何 CI 都行）
- 一个 Agent 能读到的常驻文件

#strong[就这三条。]

#strong[不是前提（可以完全没有）：]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([前面提到的], [真的需要吗],),
  table.hline(),
  [单体仓库], [不需要],
  [特定的构建系统], [#strong[只有 #ref(<sec-depgraph>, supplement: [第]) 那一节需要]],
  [自建 CI 机器], [不需要],
  [远程缓存], [不需要],
  [二十几万行的自研工具链], [不需要],
  [二十几条自动检查规则], [不需要，而且#strong[一开始不该有]],
)
最后一条不是客气话。#ref(<sec-two-months-late>, supplement: [第]) 讲过： #strong[第一条自动检查比 Agent 规模化晚了两个月， 因为在那之前根本不知道该拦什么。]

== 三件一周内能落地的事
<sec-three-things>
按投入产出比排序。

=== 一、把常驻文件重写成"带失败形态的规则"
<sec-rewrite-always-on>
#strong[投入：半天。产出：立竿见影。]

方法：把现有的每一条规则，补上两句 ------ #strong["不遵守会怎样"和"怎么修"。]

判据很硬：#strong[如果一条规则你写不出它的失败形态，那它可能不该存在。]

这个测试比它听起来严格得多。大部分团队的规范文档里， 有相当一部分条目写不出具体的失败形态 ------ 它们是品味，不是规则。 品味应该在评审里表达，不该占用常驻文件的位置。

顺带做第二件事：#strong[按 #ref(<sec-always-on-criteria>, supplement: [第]) 那三条判据筛一遍。] 第三条（"它能否被写成结构"）通常会筛掉最多。

一个真实的例子：如果你的规范里写着"不要在业务代码里直接读环境变量"， 那么正确的做法不是把这条写得更醒目，是#strong[建一个配置模块， 然后加一条检查禁止业务代码直接读]。规则从文档移进了结构， 常驻文件少一行，而约束更强了。

=== 二、给最危险的三条路径写一份清单
<sec-three-paths>
#strong[投入：一天。]

选哪三条？#strong[按"出错之后能不能重试挽回"来选。] 绝大多数团队的答案是同样的三条：

+ #strong[数据迁移]
+ #strong[发布 / 部署]
+ #strong[认证与权限]

每条只需要四个字段：

#Skylighting(([#NormalTok("路径：       哪些文件会触发");],
[#NormalTok("必须保持：   一句自然语言，写给人和 Agent 读");],
[#NormalTok("动手前读：   一到两个链接");],
[#NormalTok("完成后跑：   一条命令");],));
#strong[不需要任何工具支持] ------ 一个 Markdown 文件加一条 CI 检查就够了： 如果本次改动触到了这些路径，把对应的段落打印出来。

#strong[先不要写禁止模式。] #ref(<sec-forbid-tuning>, supplement: [第]) 已经说明， 那是需要拿真实数据调的，而你现在还没有数据。 先打印，让 Agent 和人都能看到，跑一两个月再说。

=== 三、把退出码分成三种
<sec-three-exit-codes>
#strong[投入：半天。这是全书投入最小、收益最被低估的一条。]

#NormalTok("0"); 通过 / #NormalTok("1"); 内容违规 / #NormalTok("2"); 基建故障。

实测数据：#strong[最近 500 次 CI 失败里 119 次是基建故障 ------ 接近四分之一， 而构建阶段更是每三次红灯就有一次不是代码的错。]

如果这些红灯都被当作"你写错了"丢回给 Agent， #strong[它会去改本来正确的代码，而且会改得很有信心] ------ 因为它手里确实握着一个红灯。

具体怎么做：在你的 CI 脚本里，把"工具没装""依赖拉不下来" "执行器起不来""超时"这几类失败单独识别出来，返回 2。 然后在给 Agent 的提示里说清楚：#strong[看到 2 就不要改代码。]

#strong[这一条不需要任何新基建，它只需要你的 CI 脚本多几个 if。]

== 决定要做多少的是重复判断的频次
<sec-frequency-not-size>
不是仓库大小，不是团队人数。

#strong[判断该不该加一条机制的标准只有一个：同一个判断你做过几次？]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([第几次], [该怎么做],),
  table.hline(),
  [第一次], [#strong[直接改。] 不要建机制],
  [第二次], [#strong[记一笔] ------ 写进常驻文件或说明文档],
  [第三次], [#strong[把它变成一条能自动跑的检查]],
)
一个人的项目，写清楚一份常驻文件就够了。 一个五人团队，前两条加上那三条路径清单就够了。

#strong[别从治理系统开始。]

== 五个人的团队具体该长什么样
<sec-five-person-shape>
把前面的内容落成一个具体的目标状态。一个五人团队用了 Agent 之后， 两三个月内应该长成这样：

#strong[一份 60--120 行的常驻文件。] 每条规则带失败形态。 超过 150 行说明有东西该往下放了。

#strong[三到五份路径清单。] 覆盖不可逆的那几条路径。 不带禁止模式，只有"必须保持什么"和"动手前读什么"。

#strong[三条自动检查。] 测试执行数不为零、退出码三分、 一条从你们评审里长出来的结构规则（报数模式）。

#strong[零份"规范文档"。] 所有规范要么进了常驻文件（压缩成一两句）， 要么进了结构（目录、类型、检查），要么被删掉了。

#strong[就这些。] 没有构建图，没有自研工具链，没有二十条规则。

== 三件不该做的事，以及它们各自的失败方式
<sec-three-antipatterns>
=== 一、不要先建"AI 编码规范"
<sec-no-ai-guidelines>
这是最常见的第一步，也是最常见的浪费。

失败方式：一份从零想出来的规范，它的每一条都没有被真实失败校准过。 于是它同时#strong[过严]（限制了本来没问题的做法）和#strong[过松] （漏掉了你还没撞过的坑）。

而更糟的是它的#strong[信任成本]：团队照着它做，撞了一次它没覆盖的坑， 于是这份规范的权威性开始下降 ------ 而它下降之后， 它本来覆盖对的那些条目也一起失效了。

#strong[正确的第一步是重写你已有的东西，不是新建一份。]

=== 二、不要为了"以后好扩展"提前分层
<sec-no-premature-layers>
#ref(<sec-earned-level>, supplement: [第]) 讲过为什么。这里补一个小团队特有的理由：

#strong[在一个三十个文件的项目里，一层空目录稀释掉的信息量占比更高。] 大项目里一层多余的目录是噪声，小项目里它可能是#strong[一半的噪声]。

=== 三、不要在团队还在吵的时候写规则
<sec-no-rules-during-disagreement>
失败方式：规则把一方的观点固化成了机制。 而机制比争论更难改 ------ 反对一条写进 CI 的规则， 成本远高于反对一句口头约定。

#strong[结果是分歧不但没解决，还被埋进了工具里。]

判据很简单：#strong[这条规则你们讨论过几次？ 如果超过两次还没有共识，那它不该被写成规则。]

== 三种规模的具体配置
<sec-three-scales>
给三个规模各一份具体的目标状态，可以直接对照。

=== 一个人
<sec-scale-solo>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([项], [配置],),
  table.hline(),
  [常驻文件], [#strong[40--80 行]，每条带失败形态],
  [路径清单], [一到两份，只覆盖不可逆的],
  [自动检查], [#strong[一条]：测试执行数不为零],
  [退出码], [三分（值得做，因为你没有第二个人帮你判断红灯真假）],
  [工具链], [让 Agent 能看见它改的东西 ------ #strong[这是投入最值的一项]],
)
#strong[一个人的系统里，工具链的优先级高于检查层。] 因为你自己就是那个判定（至少在早期）， 但你不是那双能替 Agent 看界面的眼睛。

=== 五到二十人
<sec-scale-small-team>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([项], [配置],),
  table.hline(),
  [常驻文件], [#strong[80--150 行]],
  [路径清单], [三到五份],
  [自动检查], [三到八条，其中至少一条是报数模式],
  [债务台账], [当存量大到不能一次清完时引入],
  [工具链], [第一、二阶段（#ref(<sec-toolchain-stages>, supplement: [第])）],
)
#strong[这个规模是这本书的主要目标读者]， 也是"载体分类"收益最大的规模 ------ 因为人开始多到 非正式沟通兜不住边界了（#ref(<sec-parallel-coordination>, supplement: [第])）。

=== 二十人以上，或大量并行 Agent
<sec-scale-large>
到这个规模，全书内容基本都适用，而且会开始需要 那些"⚙️"标记的东西：依赖图、只测受影响的、语义规则。

#strong[但顺序仍然不变] ------ 不要因为规模大就跳过前面的步骤。 #ref(<sec-build-order>, supplement: [第]) 那五步，每一步都是下一步的前提。

== 一个常被问的问题：要不要专人负责
<sec-dedicated-owner>
到什么规模需要有人专职维护这套东西？

#strong[答案取决于一个量：规则集的维护成本。]

而 #ref(<sec-full-cost-of-a-rule>, supplement: [第]) 那张表里，持续成本只有三项： 误报时被打断、重构时改范围、判断该不该退休。

#strong[前两项随规则数量线性增长，第三项通常没人做。]

一个粗略的估计：#strong[十条规则以内，摊到每个人身上是可忽略的； 超过二十条，需要有一个明确的 owner（不一定专职，但要有名字）。]

而这个 owner 的主要工作不是写新规则，是 #strong[#ref(<sec-rule-health>, supplement: [第]) 那张健康检查清单] ------ 每季度跑一遍， 删掉该删的，切换该切的，修掉误报的。

#strong[没有这个角色，规则集会单调增长，然后腐化。]

== 三个可以立刻做的十分钟练习
<sec-ten-minute-exercises>
不用读完全书，这三个练习各花十分钟，而且各自会产出一个具体的行动项。

=== 练习一：数一数你的常驻文件
<sec-exercise-count>
打开它，数三个数：

+ #strong[总行数]
+ #strong[写不出失败形态的条目数]（"不遵守会怎样"答不上来的）
+ #strong[能写进结构的条目数]（能被目录、类型或一条检查表达的）

第二个数应该是零。第三个数是你的待办清单。

#strong[如果总行数超过两百，先做第三项 ------ 那通常能砍掉最多。]

=== 练习二：列出不可逆的动作
<sec-exercise-irreversible>
在纸上列出你系统里"做错了重试挽回不了"的动作。

#strong[提示]：涉及外部世界的、涉及删除的、涉及钱的、涉及身份的。

对每一个问：#strong[改哪些文件可能导致它？]

那些文件路径就是你的第一批路径清单（#ref(<sec-three-paths>, supplement: [第])）。

#strong[大部分团队做完这个练习会发现：不可逆的动作比想象中少， 通常三到五个 ------ 而它们全都没有被特殊对待。]

=== 练习三：翻最近十次 CI 红灯
<sec-exercise-red>
逐个标注：#strong[代码问题，还是基建问题？]

如果基建问题超过两个，那么退出码三分（#ref(<sec-three-exit-codes>, supplement: [第])） 对你有立竿见影的价值。

而如果你标注时发现自己#strong[说不清某一次是哪一类] ------ 那本身就是一个信号：#strong[你的失败信息不够定位。]

== 这三个练习为什么是这三个
<sec-why-these-three>
它们各自对应这本书的一个核心主张，而且#strong[都不需要相信那个主张才能做]：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([练习], [它验证的主张],),
  table.hline(),
  [数常驻文件], [规则的载体决定它是否生效],
  [列不可逆动作], [判定的价值来自不可逆性],
  [标注红灯], [判定必须有第三态],
)
#strong[做完之后，你会有自己的数据来判断这些主张成不成立] ------ 而这比读一百页论证有用。

这也是这本书对读者唯一的要求：#strong[不要相信它，去量一下。]

而如果量出来的结果和书里说的不一样 ------ #strong[那说明你的系统和这个不一样， 而你的数据比这本书的数据更适用于你。]

== 三个真实场景的具体建议
<sec-three-scenarios>
抽象的建议不如具体的场景。给三个常见的处境。

=== 场景一：五个人，一个 Web 应用，刚开始用 Agent
<sec-scenario-web>
#strong[现状]：单仓库、npm/pnpm、一套 CI、有一份写得不错的 README。

#strong[第一周做]： 把 README 里那些"约定"抽出来，写成常驻文件， 每条补上失败形态。#strong[大概率会从二十条压到八条。]

#strong[第二周做]： 给 Agent 一个能看到界面的方式 ------ 一个截图脚本加一个控制台日志抓取。 这是 #ref(<sec-toolchain-stages>, supplement: [第]) 的第一阶段，通常一两百行。

#strong[第一个月做]： 退出码三分。你们的 CI 里大概率已经有一批"依赖装不上"的红灯。

#strong[不要做]：任何规则。观察一个月，看评审里重复说什么。

=== 场景二：二十个人，一个后端服务加几个客户端
<sec-scenario-backend>
#strong[现状]：多仓库、各自的 CI、已经有一些 lint 规则。

#strong[这个规模的核心问题通常是"跨仓库的约定没有载体"]------ 接口契约、错误码、认证方式，这些约定散在几个仓库的文档里。

#strong[第一件事]：把接口契约做成"一份声明派生多端" （#ref(<sec-derive>, supplement: [第])）。不需要写编译器，一份 schema 加一个生成脚本就行。

#strong[第二件事]：给最危险的三条路径写清单 （#ref(<sec-three-paths>, supplement: [第])）------ 后端这边通常是迁移、发布、认证。

#strong[第三件事]：让本地和 CI 跑同一条命令（#ref(<sec-step-divergence>, supplement: [第])）。 这个规模上，"本地是好的"已经开始出现了。

=== 场景三：一个人，多个小产品
<sec-scenario-solo>
#strong[这个场景和这本书的源系统最像，只是规模小几个数量级。]

#strong[优先级]：工具链 \> 载体 \> 判定。

理由在 #ref(<sec-scale-solo>, supplement: [第])：你自己就是判定（至少在早期）， 但你不是那双能替 Agent 看界面的眼睛。

#strong[而载体排第二，是因为一个人最容易犯的错是 "我知道就行了"] ------ 那些没写下来的约定， 在你自己下一次开新会话时就已经不在场了。

#strong[一个人的系统里，常驻文件不是写给别人的， 是写给三个月后的自己和每一个新会话的。]

== 一个月之后该看什么
<sec-after-one-month>
#ref(<sec-first-month>, supplement: [第]) 给了一个月的计划。这里给它的验收。

一个月之后，你手里应该有三样东西：

#strong[一、一份短的常驻文件，每条带失败形态。]

验收：#strong[随便抽三条，让另一个人（或另一个 Agent） 读完之后说出"不遵守会怎样"。] 说不出的，还没写好。

#strong[二、一份评审语句的记录。]

你记了一个月你在评审里说了什么。现在做一件事： #strong[按语义分组，看哪一句说得最多。]

那句话就是你的第一条规则，而且它已经被"挣得"了 （#ref(<sec-two-months-late>, supplement: [第])）。

#strong[三、一个红灯的分类。]

十次以上的红灯，每一次标注了代码问题还是基建问题。

验收：#strong[基建问题占比。] 如果超过 15%，退出码三分对你有立竿见影的价值； 如果低于 5%，可以先不做，但要知道这个比例会随 依赖增多而上升。

== 常见的第一个错误
<sec-first-mistake>
按经验，小团队在这条路上最常犯的第一个错误是：

#quote(block: true)[
#strong[建了检查，但没建"这个检查坏了会怎样"的答案。]
]

具体表现：一条 CI 检查跑了三个月，一次都没红过， #strong[没有人怀疑过它是不是还在工作。]

而这正是形状 A 里最危险的那个变体（#ref(<sec-variant-zombie>, supplement: [第])）------ 探针失效但仍在输出。

#strong[修法极其便宜]：让每条检查打印它的工作量 （扫了多少文件、跑了多少用例、处理了多少条）。

#strong[一行输出，而它把一个静默的失效变成了一个可见的数。]

#ref(<sec-mistake-no-scan-count>, supplement: [第]) 讲过：从第一天就打印它， 因为等你想加的时候，你已经没有历史数据可以对照了。

== 这一章的一句话总结
<sec-small-scale-summary>
如果整章只记一句：

#quote(block: true)[
#strong[必需的前提只有三条（一条主干、一个合并前的检查入口、 一份 Agent 能读到的常驻文件），其余全是这个团队的特定选择。]
]

而这句话的用处是：#strong[当你读到书里某个看起来遥不可及的东西时 （自建 CI 池、22 万行工具链、23 条规则）， 先问它属于哪一类。]

#strong[十有八九是特定选择。]

== 什么时候不该做
<sec-when-not-to>
这一节用来对冲全书的推销倾向。四种情况下，不做比做好：

#strong[一、项目生命周期短于六个月。] 规则的收益来自复利 ------ 它拦下的第一百次比第一次值钱得多。 你等不到那个时候。

#strong[二、单人且不用 Agent。] 你自己就是那个判定。把判定外化的成本，在这个规模下换不回收益。

#strong[三、团队还没就"什么是对的"达成一致。] 先写规则会#strong[把分歧固化成机制]，而机制比争论更难改 ------ 一条写进 CI 的规则，反对它的成本远高于反对一句口头约定。 #strong[先吵完，再写规则。]

#strong[四、规则的误报率会超过 5%。] #ref(<sec-bypass>, supplement: [第]) 讲过：#strong[会被绕过的规则比没有规则更糟]， 因为它还在消耗信任 ------ 而信任一旦被消耗， 下一条规则（哪怕它是对的）也会被同样对待。

如果你还没有足够的真实数据来校准规则边界， #strong["还没到时候"是一个正确的答案。]

== 逐条对照：前面五章里哪些能用、哪些不能
<sec-chapter-by-chapter>
把第二部逐章过一遍，标出小团队的适用度。

=== 第 #ref(<sec-codebase>, supplement: [章节]) 章 Codebase
<sec-applicable-codebase>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([内容], [小团队适用度],),
  table.hline(),
  [「被挣得」原则], [#strong[完全适用，而且更重要]],
  [角色由「怎么获取」决定], [完全适用],
  [第四格 #NormalTok("Testing/");], [完全适用，成本近乎为零],
  [演进纪律（第二次就上移）], [完全适用],
  [按变更原因拆文件], [完全适用],
  [共享层按能力组织], [有共享层之后才适用],
  [worktree 隔离], [#strong[不适用]，除非你真的在并行跑多个 Agent],
)
#strong[七条里有五条完全适用，而且都零成本。]

「被挣得」原则为什么在小团队更重要，#ref(<sec-no-premature-layers>, supplement: [第]) 讲过： 一层空目录在三十个文件的项目里，稀释掉的信息量占比更高。

=== 第 #ref(<sec-architecture>, supplement: [章节]) 章 架构
<sec-applicable-architecture>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([内容], [小团队适用度],),
  table.hline(),
  [一份声明派生多端], [#strong[适用，但不需要写编译器]],
  [生成物漂移检测], [完全适用，五行脚本],
  [依赖只向一个方向流动], [完全适用],
  [禁止兜底 fallback], [#strong[完全适用，收益最高的一条]],
  [不可逆动作收敛到唯一入口], [完全适用],
  [#strong[依赖图 / 只测受影响的]], [#strong[不适用]，这是唯一需要重基建的],
)
第一条值得展开：#strong[「一份声明派生多端」不等于「你得写一个编译器」。]

它的最小形态是：一份 JSON Schema 加一个生成脚本。 关键不在工具多好，在于#strong[从此只有一个地方可以改]。

而如果你现在只有一个客户端，那这一条暂时不适用 ------ 它的收益随"端"的数量增长。#strong[两端的时候开始考虑，三端的时候必须做。]

=== 第 #ref(<sec-carriers>, supplement: [章节]) 章 载体
<sec-applicable-carriers>
#strong[整章完全适用，零基建，而且这是全书对小团队最有用的一章。]

唯一需要调整的是规模：五种载体里，小团队通常只需要三种 ------ 常驻文件、按需查阅的说明、路径清单。 skill 和跨会话契约要等到你真的在跑周期性长任务时才需要。

=== 第 #ref(<sec-toolchain>, supplement: [章节]) 章 工具链
<sec-applicable-toolchain>
#strong[最难的一章，但也是收益最陡的一章。]

不需要造一整套工具。#ref(<sec-toolchain-stages>, supplement: [第]) 讲的三个阶段里， #strong[第一阶段（让 Agent 能看见它改了什么）通常只需要几百行胶水代码]， 而它是从"完全瞎"到"能看见"的质变。

具体到不同类型的项目：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([项目类型], [第一阶段是什么],),
  table.hline(),
  [Web 前端], [一个能截图并返回控制台日志的脚本],
  [后端服务], [一条能查最近日志和当前状态的命令],
  [命令行工具], [一个能跑起来并捕获完整输出的封装],
  [移动端], [最难，但模拟器截图 + 日志已经能解决大半],
)
#strong[判据在 #ref(<sec-tool-criterion>, supplement: [第])：Agent 现在是在观察，还是在猜？]

== 一个真实的取舍：什么时候值得引入构建图
<sec-when-build-graph>
这是第二部里唯一一个需要重基建的东西，所以值得给一个明确的门槛。

#strong[引入统一构建系统的成本是巨大的] ------ 迁移一个现有项目通常要几个人月， 而且迁移期间的收益是零。

#strong[它的收益有三块，但只有第一块是它独有的：]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([收益], [有没有替代方案],),
  table.hline(),
  [#strong[反向依赖查询 → 只测受影响的]], [#strong[没有便宜的替代]],
  [构建缓存 → 增量更快], [有，各语言都有自己的缓存方案],
  [密封构建 → 结果可复现], [有，容器化能解决大部分],
)
所以问题简化成一个：#strong[你需要「只测受影响的」吗？]

而这个需求有一个明确的触发条件：

#quote(block: true)[
#strong[当你的全量检查时间，超过了你能接受的单次迭代延迟时。]
]

在这之前，全量跑就够了，而且全量跑还更简单、更可信 （没有"影响面算错了"这个失败模式）。

#strong[大部分五到二十人的团队，永远不会到达这个触发点。] 而在到达之前引入构建图，付的是全部成本，拿的是三分之一收益。

== 一个五人团队的第一个月
<sec-first-month>
把上面的东西排成一个可以照着走的月度计划：

#strong[第一周]：重写常驻文件（带失败形态）+ 退出码三分。

#strong[第二到四周]：#strong[什么都不加，只观察。]

具体观察什么： - 记下每一次你在评审里说的话。#strong[重复三次以上的那句， 就是你的第一条规则。] - 记下每一次 CI 红灯，标注它是代码问题还是基建问题。 这个比例会告诉你退出码三分值不值。

#strong[第二个月]：把第一条规则写成检查，#strong[先只报数不拦]。

#strong[这个节奏看起来很慢，但它是这本书唯一推荐的节奏。] 理由在 #ref(<sec-two-months-late>, supplement: [第])：#strong[在你撞过之前，你不知道该拦什么。] 而从别处抄来的规则，误报率会高到让整套东西失去信任。

== 从这本书里能拿走的六条判据
<sec-six-criteria>
这一章的最后，把全书那些"把品味问题变成事实问题"的判据 集中列一遍。#strong[它们是这本书最可移植的部分]， 每一条都能在十分钟内用完一遍：

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([判据], [用在哪], [出处],),
  table.hline(),
  [#strong[这一层被第二个实例挣得了吗]], [目录、抽象、规则], [#ref(<sec-earned-level>, supplement: [第])],
  [#strong[这条边界换来了什么可测性]], [架构], [#ref(<sec-testability-judge>, supplement: [第])],
  [#strong[这条规则什么时候需要到达]], [载体], [#ref(<sec-five-carriers>, supplement: [第])],
  [#strong[这道检查坏了会表现成通过还是失败]], [判定], [#ref(<sec-sensor-self-check>, supplement: [第])],
  [#strong[出错之后重试能不能挽回]], [风险等级], [#ref(<sec-arbiter-fields>, supplement: [第])],
  [#strong[同一个判断你做过几次]], [该不该建机制], [#ref(<sec-frequency-not-size>, supplement: [第])],
)
#strong[六条的共同结构是：它们都把一个"应该"的问题 换成了一个"是不是"的问题。]

而这个转换的价值在于：#strong[事实问题在不同的人之间 能得到一致的答案]，而"应该"的问题不能。

#strong[在几十个并行的 Agent 之间，这一点尤其重要] ------ 因为它们之间没有任何沟通机制来对齐"应该" （#ref(<sec-parallel-coordination>, supplement: [第])）。

== 一条元建议
<sec-meta-advice>
如果这一章的所有具体建议都不适用于你的处境， 那么记住这一条：

#quote(block: true)[
#strong[不要先建系统，先建测量。]
]

你现在不知道你的瓶颈在哪 ------ 是判定慢， 还是失败信息差，还是 Agent 够不着某些东西。

#strong[而这三个的解法完全不同，甚至互相冲突] （加机器 vs 改信息 vs 造工具）。

#strong[所以第一步永远是：量三个数]（#ref(<sec-measure-the-loop>, supplement: [第])）， #strong[看它们的关系，判断自己在哪个稳态]（#ref(<sec-three-equilibria>, supplement: [第])）。

#strong[这一步的成本是几天，而它决定了后面几个月的投入方向。]

而它还有一个额外的好处：#strong[这三个数本身就是 这套系统的第一个观测器] ------ 建完之后， 你就有了一个能看到"这套东西还在不在工作"的东西。

#part[第三部 · 判定]
= 判定的三种失败
<判定的三种失败>
= 判定的三种失败
<sec-three-failures>
一个判定可以怎么坏？

大部分系统的答案是"两种"：它可以说通过，也可以说失败。而这个答案漏掉了 最危险的那一种，也没有区分开代价完全不同的另外两种。

== 三种，性质完全不同
<sec-verdict-failures>
#strong[第一种：判定说通过，但它其实什么都没验。]

这是形状 A，全书会反复回到它。一个跑了零个用例的测试套件、一个因为缺少 可执行宿主而只编译不运行的界面测试、一个被无条件跳过却仍然保留着测试外观的 用例 ------ 它们都返回"通过"，而且它们返回的是#strong[真的]通过： 按各自的标准，它们没有任何异常。

#strong[第二种：判定说失败，但错的不是代码。]

执行器起不来、依赖没同步、任务超时、构建工具下载失败。红灯是真的， 但它指向的方向是错的。

#strong[第三种：判定说失败，代码确实错了。]

这是唯一一种"正常"的失败。

大部分系统只区分通过和失败，于是第一种被归进通过，第二种被归进第三种。 这两个归并的代价完全不对称：

- 第一种被归进通过 → #strong[坏代码进主干]
- 第二种被归进第三种 → #strong[Agent 去改本来正确的代码]

第二个后果比它听起来更严重。Agent 拿到一个红灯，它不会怀疑这个红灯的来源， 它会去找代码里可能导致这个红灯的东西，然后改掉。而且#strong[它会改得很有信心， 因为它手里确实握着一个红灯。] 改完之后红灯还在（因为根因在基建）， 于是它再改一轮。几轮之后，一段本来正确的代码被改得面目全非， 而那个下载超时的构建工具还是没下载下来。

== 数据：接近四分之一的红灯跟代码无关
<sec-infra-share>
这个比例不是估计。把最近五百次 CI 失败按性质拆开：

- 三百八十次是代码或测试真的错了
- #strong[一百一十九次是基建故障] ------ 执行器起不来、依赖没同步、任务超时

按类别看，差异比总数更说明问题：

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([类别], [代码问题], [基建故障], [基建占比],),
  table.hline(),
  [构建], [59], [34], [#strong[37%]],
  [单元 / 集成], [143], [60], [30%],
  [结构检查], [56], [13], [19%],
  [UI / 端到端], [102], [8], [7%],
)
#strong[构建阶段每三次红灯就有一次不是代码的错。]

这个分布本身也有信息：越靠近底层的判定，基建故障占比越高， 因为它依赖的外部条件越多（网络、缓存、工具链版本）。而越靠上层的判定 （界面与端到端），虽然单次更贵、更慢，反而更"干净" ------ 一旦它跑起来了，它红就是真的红。

== 让"无法判断"成为一等公民
<sec-cannot-judge>
解法是把结果从两种变成三种：

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([退出码], [含义], [修复对象],),
  table.hline(),
  [#strong[0] Passed], [证据完整，未命中策略], [--- 继续],
  [#strong[1] PolicyViolation], [候选改动触碰规则], [#strong[这次的 diff]，回到 owner 改代码],
  [#strong[2] InfrastructureFailure], [策略读不出来、版本缺失、工具链不可用], [#strong[检查条件]，改业务代码没有意义],
)
把 1 和 2 分开，是这套东西和普通 lint 最实质的区别。

#strong[这两类失败绝不能共用一个重试分支。] 策略违规重试同一份代码毫无意义； 而基础设施故障下改业务代码也换不回一个可信判定 ------ 它只会让 Agent 在一个本来就无法判断的环境里，把代码越改越乱。

=== 这个区分在代码里长什么样
<sec-verdict-in-code>
值得看一眼实现，因为它比任何解释都清楚。判定的类型不是布尔值：

#Skylighting(([#KeywordTok("pub");#NormalTok(" ");#KeywordTok("enum");#NormalTok(" LaneOutcome ");#OperatorTok("{");],
[#NormalTok("    Passed");#OperatorTok(",");],
[#NormalTok("    PolicyViolation(");#DataTypeTok("String");#NormalTok(")");#OperatorTok(",");],
[#NormalTok("    InfrastructureFailure(");#DataTypeTok("String");#NormalTok(")");#OperatorTok(",");],
[#OperatorTok("}");],));
三态枚举，#strong[让非法状态无法表示]。你没法"忘记"处理基建故障那一支 ------ 编译器会拦住你。这是把一条纪律交给类型系统去守，而不是交给记性。

而退出码是这样算出来的：

#Skylighting(([#KeywordTok("pub");#NormalTok(" ");#KeywordTok("fn");#NormalTok(" exit_code(");#OperatorTok("&");#KeywordTok("self");#NormalTok(") ");#OperatorTok("->");#NormalTok(" ");#DataTypeTok("i32");#NormalTok(" ");#OperatorTok("{");],
[#NormalTok("    ");#ControlFlowTok("match");#NormalTok(" ");#KeywordTok("self");#NormalTok(" ");#OperatorTok("{");],
[#NormalTok("        ");#DataTypeTok("Self");#PreprocessorTok("::");#NormalTok("Completed ");#OperatorTok("{");#NormalTok(" lanes");#OperatorTok(",");#NormalTok(" ");#OperatorTok("..");#NormalTok(" ");#OperatorTok("}");#NormalTok(" ");#ControlFlowTok("if");#NormalTok(" lanes");#OperatorTok(".");#NormalTok("has_infrastructure_failure() ");#OperatorTok("=>");#NormalTok(" ");#DecValTok("2");#OperatorTok(",");],
[#NormalTok("        ");#DataTypeTok("Self");#PreprocessorTok("::");#NormalTok("Completed ");#OperatorTok("{");#NormalTok(" lanes");#OperatorTok(",");#NormalTok(" ");#OperatorTok("..");#NormalTok(" ");#OperatorTok("}");#NormalTok(" ");#ControlFlowTok("if");#NormalTok(" lanes");#OperatorTok(".");#NormalTok("has_policy_violation() ");#OperatorTok("=>");#NormalTok(" ");#DecValTok("1");#OperatorTok(",");],
[#NormalTok("        ");#DataTypeTok("Self");#PreprocessorTok("::");#NormalTok("Completed ");#OperatorTok("{");#NormalTok(" ");#OperatorTok("..");#NormalTok(" ");#OperatorTok("}");#NormalTok(" ");#OperatorTok("=>");#NormalTok(" ");#DecValTok("0");#OperatorTok(",");],
[#NormalTok("        ");#DataTypeTok("Self");#PreprocessorTok("::");#NormalTok("BaselineGrowth(_) ");#OperatorTok("=>");#NormalTok(" ");#DecValTok("1");#OperatorTok(",");],
[#NormalTok("        ");#DataTypeTok("Self");#PreprocessorTok("::");#NormalTok("InfrastructureFailure(_) ");#OperatorTok("=>");#NormalTok(" ");#DecValTok("2");#OperatorTok(",");],
[#NormalTok("    ");#OperatorTok("}");],
[#OperatorTok("}");],));
#strong[注意匹配臂的顺序。] 基建故障排在策略违规#strong[前面]。这意味着： 一次运行如果同时有内容违规和基建故障，它报的是 2，不是 1。

这个顺序是一个刻意的决定，而理由值得说清楚：#strong[如果测量不可信， 那么同一次运行里得出的策略结论也不可信。] 你不能一边说"我的传感器坏了"， 一边说"但我根据它的读数判定你违规了"。

#ref(<sec-sensor-faults>, supplement: [章节]) 会给这条规则一个正式的名字。在这里先记住它的形状： #strong[传感器故障压过对象故障。]

=== 两条用断言守住的不变量
<sec-verdict-invariants>
同一个文件里还有两句 assert，各守一条不变量：

#Skylighting(([#PreprocessorTok("assert_ne!");#NormalTok("(lane");#OperatorTok(",");#NormalTok(" ");#PreprocessorTok("LaneId::");#NormalTok("Architecture");#OperatorTok(",");],
[#NormalTok("           ");#StringTok("\"architecture outcomes must retain their rich result\"");#NormalTok(")");#OperatorTok(";");],));
架构检查的判定#strong[不许被降级]成普通结论。因为架构 lane 的输出带着规则名、 扫描数、哨兵读数和具体违规位置 ------ 一旦被压扁成一句 #NormalTok("PolicyViolation(\"失败了\")");， Agent 就失去了它自己收敛所需要的全部信息。

#Skylighting(([#PreprocessorTok("assert!");#NormalTok("(");#KeywordTok("self");#OperatorTok(".");#NormalTok("lanes");#OperatorTok(".");#NormalTok("iter()");#OperatorTok(".");#NormalTok("all(");#OperatorTok("|");#NormalTok("c");#OperatorTok("|");#NormalTok(" c");#OperatorTok(".");#NormalTok("lane ");#OperatorTok("!=");#NormalTok(" result");#OperatorTok(".");#NormalTok("lane)");#OperatorTok(",");],
[#NormalTok("        ");#StringTok("\"guardrail lane outcomes must be unique\"");#NormalTok(")");#OperatorTok(";");],));
#strong[一个 lane 只能有一个判定。] 这是"每份可变状态收敛到单一 writer" 这条原则用在了判定本身上 ------ 如果同一个 lane 能写两次结论， 那么"这次到底过了没有"就取决于谁最后写，而这正是形状 B。

== 一次真的 exit 2 长什么样
<sec-real-exit-2>
#Skylighting(([#NormalTok("$ bash guardrails/guard check arbiters");],
[#NormalTok("could not download Bazel: ... Get \"https://releases.bazel.build/...\" : EOF");],
[#NormalTok("guardrails: failed to build canonical runner");],
[#NormalTok("ERROR: Job failed: command terminated with exit code 2");],));
构建工具拉不下来，检查器构建不出来，策略就读不出来。

#strong[它没有假装通过，也没有报成策略违规，而是明确地说「这次我判不了」。]

这三句话是三个不同的产品决定。一个系统在这种情况下的默认行为， 暴露了它真正的设计意图：

- 假装通过 → 优化的是"不要挡住人"
- 报成违规 → 优化的是"不要有未处理的情况"
- 说判不了 → 优化的是"结论必须可信"

== 四道 fail-closed 的证据门
<sec-evidence-gates>
在 CI 里，这套判定被拆成四道独立的门，#strong[全部 fail closed]：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([门], [守什么],),
  table.hline(),
  [策略机制自身的契约], [检查器有没有坏],
  [真机 lane 的实际执行], [需要真实设备的那部分跑没跑],
  [目录与依赖边界], [结构对不对],
  [对本次 diff 的最终扫描], [这次改动碰了什么],
)
fail closed 的意思是：#strong[判不了 = 不通过。]

而绝大多数系统的默认是反过来的 ------ 检查挂了就跳过， 理由是"不能因为工具坏了就挡住所有人"。

这个默认值在人的世界里是合理的：人会记得回来补。 #strong[在 Agent 的世界里它是错的，因为没有人会记得。] 一个被跳过的检查， 和一个从来不存在的检查，在下一次运行时是同一个东西。

== 第一种失败为什么最难对付
<sec-first-failure-hardest>
三种失败里，第二种和第三种都会#strong[表现出来] ------ 有人被挡住， 有人去查，最终会被处理。

#strong[第一种不会。] 它的全部表现就是一片绿色。

而它有三个性质，让它比另外两种难对付一个数量级：

#strong[一、它没有触发点。] 后两种失败都有一个明确的时刻：CI 变红了。 而第一种没有任何时刻 ------ 它是一个持续的、无声的状态。

#strong[二、它会累积。] 一个坏掉的检查，从它坏掉那天起， 之后所有经过它的改动都没有被真正检查过。 #strong[而你不知道那天是哪天。]

#strong[三、发现它需要主动怀疑。] 后两种失败会来找你，第一种要你去找它。 而"去找一个看起来没问题的东西的问题"， 是所有工程活动里最难被排进优先级的一种。

这三条合起来解释了为什么这本书用一整章讲传感器故障 （#ref(<sec-sensor-faults>, supplement: [章节])），以及为什么那一章里的四种机制 #strong[全都是主动的] ------ 量程校验、解析冗余、机内自检， 它们都不等异常出现，它们主动去证明测量还活着。

== 三种失败的代价不对称
<sec-cost-asymmetry>
设计一个判定系统时，最关键的一个决定是： #strong[在不确定的时候，往哪边倒。]

而这个决定应该由代价的不对称性来定，不是由"哪种更常见"来定：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([把 X 误判成 Y], [后果], [可发现性],),
  table.hline(),
  [把违规误判成通过], [#strong[坏代码进主干]], [低 ------ 可能几个月后才知道],
  [把通过误判成违规], [一次无谓的返工], [高 ------ 当场就知道],
  [把基建故障误判成违规], [#strong[改坏正确的代码]], [中 ------ 改坏之后可能才发现],
  [把违规误判成基建故障], [一次无谓的等待], [高 ------ 重跑就知道],
)
#strong[两个"高可发现性"的误判，代价都是一次浪费； 两个"低/中可发现性"的误判，代价都是错误进入了系统。]

所以正确的倾向很清楚：#strong[不确定时，往"更严"和"更早说判不了"的方向倒。]

这就是四道证据门全部 fail closed 的理由（#ref(<sec-evidence-gates>, supplement: [第])）， 也是退出码 2 排在退出码 1 前面的理由（#ref(<sec-verdict-in-code>, supplement: [第])）。

#strong[代价不对称的时候，"公平"是错的目标。]

== 这三种失败在别的地方也成立
<sec-generalizes>
退出码三分是从 CI 里长出来的，但这个划分的适用范围比 CI 大得多。

#strong[任何一个"产生判断的东西"，都应该有这三种输出。]

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([场景], [通过], [内容违规], [判不了],),
  table.hline(),
  [代码检查], [干净], [有违规], [工具起不来],
  [监控告警], [正常], [指标越界], [#strong[采集器挂了]],
  [数据质量检查], [数据合格], [数据有问题], [#strong[上游没送数据]],
  [权限判定], [允许], [拒绝], [#strong[鉴权服务不可达]],
  [健康检查], [健康], [不健康], [#strong[检查本身失败]],
)
#strong[每一行的第三列，在大部分实现里都被折叠进了前两列之一。]

而折叠的方向暴露了设计意图：

- 折叠进"通过" → 优化的是可用性，代价是#strong[静默失效]
- 折叠进"违规" → 优化的是保守，代价是#strong[误报和错误归因]

#strong[监控告警那一行值得单独说]，因为它的折叠方向几乎总是错的： 采集器挂了，指标没有数据，而大部分告警规则在"没有数据"时#strong[不触发] ------ 也就是折叠进了"正常"。

#strong[结果是：监控系统坏掉的时候，它看起来一切正常。]

这正好是形状 A，而且它和 #ref(<sec-signing-failure>, supplement: [第]) 那个 挂了四个月的定时任务是同一个形状 ------ 只不过一个发生在监控上， 一个发生在自动化上。

#strong[所以这一章的判断也可以反过来用]： 当你看到一个系统只有"好"和"坏"两种输出时， 去找它的第三种状态被折叠到哪里去了。#strong[那里通常有一个洞。]

== 从两态到三态需要改什么
<sec-two-to-three>
具体到实现，这个改动涉及三个地方，而#strong[大部分人只改了第一个]。

=== 一、产生判定的一方：要能区分
<sec-producer>
在检查脚本里识别出基建故障的特征，返回不同的退出码。 #ref(<sec-impl-exit-codes>, supplement: [第]) 给了一个可以直接抄的形态。

#strong[这一步最容易，也最常被当成全部。]

=== 二、传递判定的一方：不能压扁
<sec-transport>
从检查脚本到 CI 到 Agent，中间每一层都可能把三态压回两态。

典型的压扁点：

- CI 配置里写了 #NormalTok("|| true");（把所有失败压成通过）
- 一个包装脚本只判断"退出码是不是 0"
- 报告聚合时只统计"成功/失败"两种

#ref(<sec-verdict-invariants>, supplement: [第]) 里那句 #NormalTok("assert_ne!(lane, LaneId::Architecture, \"架构判定必须保留丰富的结果\")"); 守的正是这一类压扁。

#strong[而它用的是断言，不是文档] ------ 因为压扁通常是无意的， 一次重构、一次"简化"就会发生。

=== 三、消费判定的一方：要知道怎么用
<sec-consumer>
#strong[这一步最常被完全遗漏。]

你区分了三态，但如果给 Agent 的指导里没有说 "看到退出码 2 不要改代码"，那么这个区分对它是不存在的。

而这一条应该放在#strong[常驻文件]里（#ref(<sec-always-on-criteria>, supplement: [第])）------ 它必须无条件生效，而且不遵守它的后果是静默的 （Agent 会改坏正确的代码，而没有任何东西会报错）。

== 三步都做到了才算做完
<sec-all-three-steps>
#strong[只做第一步的结果是：你付出了成本，没有得到收益。]

而这个失败模式很难被发现，因为第一步做完之后， 一切看起来都在工作 ------ 退出码确实是 2 了。

#strong[检验方式很简单]：随便找一次基建故障导致的失败， 看 Agent 那一轮做了什么。#strong[如果它改了代码，那就是没做完。]

== 给读者的动作
<sec-three-failures-action>
把你 CI 上最近的十次红灯拉出来，逐个归类。

如果第二类（基建故障）占比超过百分之十五，而你的系统没有把它和第一类分开 ------ 那么你的 Agent 有超过十分之一的时间在改本来正确的代码。

这是全书投入最小、收益最确定的一条改动：#strong[半天，一个退出码。]

== 这一章的一句话
<sec-three-failures-oneline>
#quote(block: true)[
#strong[一个只有两种输出的判定系统， 一定把第三种状态藏在了某个地方 ------ 而那个地方就是它的洞。]
]

而找到那个洞的方式很简单：#strong[问它在"判不了"的时候会怎样。]

- 假装通过 → 洞在"静默失效"这一侧
- 报成违规 → 洞在"错误归因"这一侧

#strong[两个洞的代价不对称]（#ref(<sec-cost-asymmetry>, supplement: [第])）， 所以如果只能选一个，选后者 ------ 但正确的做法是两个都不选， #strong[而是让"判不了"成为一个一等公民的状态。]

== 三种失败和三层判定的交叉
<sec-cross-product>
三种失败可以出现在三层判定的任何一层， 而#strong[九个格子里，有些是常见的，有些几乎不发生。]

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([], [假绿], [基建故障], [真违规],),
  table.hline(),
  [#strong[测试]], [#strong[常见]（#ref(<sec-fake-green>, supplement: [第])）], [#strong[常见]（30%）], [常见],
  [#strong[结构检查]], [少（有哨兵）], [少（19%）], [#strong[最多]（7% 失败率）],
  [#strong[路径不变量]], [#strong[少]（只扫新增行，逻辑简单）], [少], [少（命中率低）],
)
#strong[读这张表能得到三个判断：]

#strong[一、测试那一行最需要防护。] 它同时是假绿最常见、基建故障最多的一层 ------ 而这解释了为什么第 #ref(<sec-tests>, supplement: [章节]) 章是全书最长的判定章。

#strong[二、结构检查是最"干净"的一层。] 它的失败几乎总是真违规，而这是它性价比高的一部分原因 （#ref(<sec-cheapest-layer>, supplement: [第])）------ #strong[一次失败几乎不需要甄别。]

#strong[三、路径不变量这一层的假绿风险最低。] 因为它的逻辑最简单（路径匹配 + 字面模式）， #strong[代码越少，静默失效的可能性越低]（#ref(<sec-why-so-small>, supplement: [第])）。

#strong[而这给出一个反直觉的设计建议]： #strong[当一层判定的逻辑变复杂时，它自己的假绿风险在上升] ------ 所以复杂的判定需要更多的自检（#ref(<sec-checker-self-coverage>, supplement: [第])）。

== 一个实用的分类练习
<sec-classification-exercise>
#ref(<sec-three-failures-action>, supplement: [第]) 建议拉十次红灯出来分类。 这里给一个更细的版本，如果你想做得更彻底：

对每一次红灯，记四个字段：

#Skylighting(([#NormalTok("① 哪一层？          测试 / 结构 / 路径不变量");],
[#NormalTok("② 哪一类？          真违规 / 基建故障");],
[#NormalTok("③ 定位花了多久？    从看到红灯到知道原因");],
[#NormalTok("④ 修复花了多久？    从知道原因到转绿");],));
#strong[第③个字段是最有价值的]，因为它直接衡量 #strong[失败信息的质量]（#ref(<sec-delay-breakdown>, supplement: [第])）。

而如果你发现某一层的③特别长， 那一层的失败信息需要改善 ------ #strong[而这通常比再加一道检查便宜得多，收益也大得多。]

= Tests：绿灯可不可信
<tests绿灯可不可信>
= Tests：绿灯可不可信
<sec-tests>
测试不关心 Agent 写得像不像标准答案，只关心系统在真实输入下做了什么。

#strong[前提是 ------ 这个"绿"本身得是真的。]

整章都在讲这个前提，因为在 Agent 大量产出的场景下， #strong[假绿不是一个边缘情况，它是主流失败模式。]

理由很简单，而且它是结构性的：

#quote(block: true)[
#strong[让一个断言通过，永远比让一个行为正确要容易。]
]

一个被要求"加测试"的 Agent，面对的是一个优化问题：怎样最快地 让检查变绿。而"写一个不会失败的测试"是这个优化问题的一个合法解 ------ 它满足了所有可见的约束。

== 金字塔的真实形状
<sec-pyramid>
这个形状不是照着书画的，是被成本逼出来的。取完整的一天， CI 上跑了 2,382 个任务，各层的中位耗时是：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([层], [中位耗时],),
  table.hline(),
  [构建], [1.9 分钟],
  [结构检查], [5.2 分钟],
  [单元与集成], [7.8 分钟],
  [界面与端到端], [14.9 分钟],
)
越往上一层，一次判定越贵 ------ #strong[界面层的单次成本接近结构检查的三倍， 而它能覆盖的路径反而最少。]

金字塔的形状，说到底就是"把判定尽量下沉到便宜的那一层"。

但成本不是唯一理由，甚至不是主要理由。#ref(<sec-cascade>, supplement: [第]) 会说明： 真正的理由是稳定性 ------ 这是一个#strong[串级控制]结构， 快内环先抑制大部分扰动，慢外环只处理漏过来的。而串级有一个定量前提， #strong[如果内环不够快，整个结构就白搭。]

== 什么才算通过
<sec-what-passes>
=== 变异验证
<sec-mutation>
最重要的一条：#strong[把那个修复拿掉，回归测试必须重新变红。]

如果它不变红，说明这条测试守的根本不是行为，只是"这段代码还在"。

这一条是这一章所有内容的根。它把"测试通过了吗"这个问题 换成了一个可以真正回答的问题：#strong["这条测试有能力失败吗？"]

而这两个问题的差距，就是假绿的全部藏身之处。

=== 覆盖率的门槛，以及它怎么算
<sec-coverage>
门槛是 95%，但比这个数字更重要的是它怎么算。规则写得很细， #strong[就是为了堵住"把分母做大"这条路]：

- 只针对#strong[新增 / 修改的生产单元]，不是全仓一刀切
- 用平台标准指标和工具能报告的#strong[最小范围]
- #strong[先算原始的已覆盖 / 总数再取整]
- 只用工具链既有的排除项，记录验证命令与范围
- 不聚合无关代码抬高数字，不加排除项掩盖缺口
- #strong[覆盖率不替代]有意义的断言与变异验证

第三条容易被跳过，但它堵的是一个很实在的漏洞：先四舍五入再聚合， 和先聚合再四舍五入，在多个小文件上能差出好几个百分点。

而最后一条是整段的兜底：#strong[覆盖率是一个下界指标，不是一个质量指标。] 它能告诉你哪里肯定没测，不能告诉你测过的地方测对了。

=== 测试结论属于跑测试的那一方
<sec-verdict-ownership>
还有一条容易被忽略的纪律：#strong[测试结论属于跑测试的那一方， 后续阶段不得重新推导或覆盖。]

听起来像废话，但在多阶段流水线里， #strong["后面那一段自己判断前面那段其实没问题"是很常见的绕过方式] ------ 一个下游阶段看到上游失败了，检查一下发现"这个失败看起来是环境问题"， 于是继续往下走。

它之所以危险，是因为它每一次都显得合理，而且它把一个明确的判定 换成了一个推测。这条纪律由两条独立的路径不变量守着， 一条管客户端侧，一条管 CI 侧。

== 坑一：假绿 ------ 跑了 0 个用例，照样通过
<sec-fake-green>
现在讲三个真实踩过的坑。它们比"要写测试"这句话有用得多， 因为#strong[它们都属于"看起来在跑，其实没跑"] ------ 而这恰恰是 Agent 最容易停在的状态。

=== 形态一：过滤器写错，零个用例，报通过
<sec-filter-trap>
测试过滤器给裸方法名会匹配不到任何用例，测试二进制以 0 退出， 构建系统报"通过"；要求跑 8 遍就报 8 个"通过"。

#Skylighting(([#ExtensionTok("--test_filter=");#StringTok("'StreamingLogReaderTests'");#NormalTok("                       ");#CommentTok("# ✅ 类名");],
[#ExtensionTok("--test_filter=");#StringTok("'StreamingLogReaderTests/testFinalLineIsRead'");#NormalTok("   ");#CommentTok("# ✅ 类名/方法名");],
[#ExtensionTok("--test_filter=");#StringTok("'testFinalLineIsRead'");#NormalTok("                           ");#CommentTok("# ❌ 0 个测试，照样通过");],));
关键在于摘要那一行数的是#strong[构建目标]，不是测试用例。

所以规矩是：#strong[带过滤器得到的红或绿，在看到"执行了 N 个测试" 且 N 不为 0 之前都不算数。]

#Skylighting(([#ExtensionTok("bazel");#NormalTok(" test //X:Tests ");#AttributeTok("--test_filter");#OperatorTok("=");#NormalTok("... ");#AttributeTok("--test_output");#OperatorTok("=");#NormalTok("all ");#DecValTok("2");#OperatorTok(">&");#DecValTok("1");#NormalTok(" ");#KeywordTok("|");#NormalTok(" ");#FunctionTok("grep");#NormalTok(" ");#StringTok("\"Executed [0-9]* test\"");],
[#CommentTok("# Executed 0 tests, with 0 failures   ← 假绿");],));
#strong[这个坑的杀伤力在于它是上游污染。] 一旦踩中， 后面所有依赖"跑一次看结果"的动作 ------ 包括变异验证和 flake 复现 ------ 得出的结论#strong[全是空话]。

你以为你在做变异验证：拿掉修复，跑测试，红了，很好。 而实际上你跑了零个用例两次，两次都"通过"， 于是你得出"这条测试守不住行为"的结论，然后去重写一条本来没问题的测试。

=== 形态二：编译通过，但没有可执行宿主
<sec-no-host>
同一个形状的第二个实例，沉淀成了一条规则：

#quote(block: true)[
界面测试只有库目标、没有可执行宿主时，#strong[会编译通过但执行 0 个用例。]
]

这一条更隐蔽，因为它不需要任何人写错什么 ------ 只要构建文件里少了一个目标， 整个测试套件就静默地不跑了，而所有信号都是绿的。

=== 形态三：无条件跳过
<sec-unconditional-skip>
第三个实例也沉淀成了规则，它匹配无条件的跳过语句。规则的说明是：

#quote(block: true)[
无条件的跳过#strong[永久删除了覆盖，却仍然保留了测试的外观。]
]

修法是把场景修好并启用，只有真实的运行时限制才允许用有依据的条件跳过。

=== 三个形态的共同结构
<sec-fake-green-shape>
把三个放在一起看：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([形态], [缺了什么], [信号],),
  table.hline(),
  [过滤器写错], [用例没被选中], [绿],
  [缺可执行宿主], [用例没被执行], [绿],
  [无条件跳过], [用例被跳过], [绿],
)
#strong[三种不同的原因，同一个后果，同一个信号。]

而它们的共同点是：#strong[在"通过"这个信号里，没有携带"跑了多少"这个信息。]

这就是形状 A 的本质 ------ #strong[探针和被测对象之间有一条未被验证的因果假设]， 这里的假设是"任务跑完了 ⇒ 用例跑过了"。

== 坑二：本机全绿，只在 CI 红
<sec-local-vs-ci>
本机和 CI 跑的根本不是同一件事。CI 用的是覆盖率模式， 外面套了一层语言环境包装器，还会按主机容量并发多个模拟器。

差异出现时，#strong[按可疑度从高到低]排查这三个变量：

+ #strong[模拟器争用]（最常见）
+ #strong[覆盖率插桩] ------ 它改代码生成，能翻出只在插桩下崩的问题
+ #strong[语言环境包装器] ------ 默认值和本机通常一致，最少中招

除此之外还有一层：CI 的模拟器通常比本机新， 而声明式界面框架展平成原生视图层级的方式#strong[会随系统版本变化]， 所以界面测试里的层级断言可能只在某一边成立。

规矩是：#strong[本机绿是必要条件，不是充分条件。]

这一条对 Agent 尤其重要，因为 Agent 拿到"本机绿了"这个事实之后， 默认会认为工作完成。#strong[必须明确告诉它这个结论的适用范围。]

== 坑三：用墙钟给异步上界
<sec-wall-clock>
flake 的典型形状是这样的：要断言一个最终一致的异步副作用， 却用时间给它设超时。

问题在于#strong[墙钟在争用下是反向伸缩的] ------ 机器越忙，同样一秒里能排进去的调度次数越少。

于是这条测试实际上是#strong[红在机器负载上，而不是红在被测代码上]， 重跑一次又绿了，看起来就成了"偶发"。

规矩是：#strong[上界要用争用时真正稀缺的那种资源] ------ 调度次数，或者每轮真正发出一次的查询 ------ #strong[别拿时间赌。]

=== 这条纪律在工具链里执行得比在运行时里好
<sec-discipline-uneven>
诚实地补一句。整个仓库 150 万行 Swift 生产代码里， 违反这条纪律的轮询只剩 7 处，其中 4 处是系统 API 的契约要求 （那些接口只能轮询，没有回调），1 处是外部引入的代码。

#strong[真正的违规只有 1 处，而它在最核心的那个运行时文件里] ------ 一个服务解析的等待循环，用毫秒级轮询加固定次数上界。 而且那条路径没有测试覆盖。

#ref(<sec-discipline-incomplete>, supplement: [第]) 讲过这个顺序为什么不是偶然： #strong[看得见的先修，看不见的留到最后，即使后者更危险。]

== 一份构建文件的成本论证
<sec-ui-test-wrapper>
这一节讲一份包装规则的文档注释，因为#strong[它是整个仓库里最好的工程写作]， 而且它示范了一件很少有人做的事：#strong[给一个默认值写期望值论证。]

背景是界面测试在 CI 里不参与合批，所以#strong[一个测试目标 = 一个 macOS 任务]， 再乘以系统版本矩阵。而 macOS 执行机只有 5 台。

=== 决定一：名字由包装器推出，不由调用方起
<sec-derived-name>
#quote(block: true)[
按功能拆 bundle 曾把 8 个产品拆成 30 个目标； 一次共享层改动就要 #strong[43 个任务去抢 5 台机器]。
]

所以不按功能拆，而是#strong[按执行环境拆]：目标名必须等于包装器 从 owner 和设备推出的那一个。而这条约束的执行方式很讲究：

#quote(block: true)[
两个只差过滤条件的目标会推出同一个名字， 构建系统在加载期就报重复目标 ------ #strong[拆不出来，而不是拆完等 CI 发现。]
]

#strong[这是"让非法状态无法表示"用在了构建图上。] 它不是一条被检查的规则， 它是一条结构上做不到的事。

而失去的能力（失败时只重跑一个业务域）被另一条路径补上了： 本地重跑时用命令行过滤。

#quote(block: true)[
拆分的收益由命令行在本地重跑时提供， #strong[不需要在构建图上永久付一份任务成本。]
]

#strong[临时的需求用临时的手段满足，不要为它在结构上留一个永久的口子] ------ 这条可以直接抄走。

=== 决定二：超时默认值的期望值论证
<sec-timeout-ev>
框架默认的超时太紧，于是改成更长的一档。但注释接着说， 对"一个产品一个 bundle"来说这一档几乎总是不够，并给出了实测：

#quote(block: true)[
本地实测 #strong[40 个用例 / 977 秒 ≈ 每用例 24 秒]（不是早期文档写的约 7 秒）。 而 CI 的 5 台机器各跑 3 个并发，3 个模拟器加 3 个运行器挤 16GB， 实测把同一个用例放大 #strong[1.3--5.4 倍] ------ 所以本地低于阈值也不能赌。
]

然后是那句论证：

#quote(block: true)[
#strong[赌短超时是负期望：超时会让 flaky 的 3 次尝试各烧满 900 秒 （45 分钟一台机器），而长超时在测试正常通过时不产生任何额外成本。]
]

这是一个#strong[不对称收益]的判断：调短的收益是"失败时早点知道"， 代价是"每次失败烧掉 45 分钟机时"；调长的代价在正常情况下是#strong[零]。

#strong[没有人给超时值写期望值论证。] 而这正是这类默认值总是设错的原因 ------ 它们是凭感觉设的，而感觉在不对称收益面前是不可靠的。

=== 决定三：承认一条查过的死路
<sec-no-third-way>
#quote(block: true)[
#strong[没有第三条路]：测试运行器不认构建系统的分片协议 （对应目录下没有任何分片索引/总数的处理）， 所以分片数拿不到，单个目标内部无法再切。
]

#strong[记下一条被排除的方案，和记下选中的方案一样有价值。] 没有这一句，每隔几个月就会有人（或某个 Agent）重新提议"用分片来解决"， 然后花半天验证它不行。

=== 决定四：flake 的根因被命名了
<sec-named-flakes>
界面测试默认标记为 flaky（允许重试），但注释没有停在"界面测试不稳定"， 而是#strong[点名了两类无法靠产品代码消除的基础设施 flake]， 每一类都带着一个具体的案例编号。

#strong["这个测试不稳定"和"这个测试因为这两个已知的基础设施问题不稳定" 是两个东西。] 前者是放弃，后者是一份待办清单 ------ 而且它让"重试"这个决定变得可以被复核：哪天这两个根因被消除了， 这个默认值就该改回去。

=== 它自己承认的一个缺口
<sec-wrapper-gap>
同一份注释里还有这样一段：

#quote(block: true)[
构建文件里的排除清单#strong[没有任何东西校验其完备性]， 新加一个套件忘了同步就#strong[静默双跑或静默不跑]。
]

#strong[作者自己在文档里标出了一处形状 A。]

它没有被修（可能因为成本高于收益），但它被#strong[写了下来]。 而写下来之后，任何一个读到这份文件的人（或 Agent） 在遇到"某个套件好像没跑"的时候，会立刻有一个候选解释。

#strong[一个已知的缺口，和一个未知的缺口，在排查成本上差一个数量级。]

== 实测：这套东西守住了多少
<sec-assertion-density>
前面讲的都是机制，现在看结果。

全仓 Swift 测试里有 #strong[33,239 个测试函数，其中 1,318 个没有任何断言 ------ 4.0%。]

作为对照，一般代码库这个比例在 10% 到 20% 之间。

但要诚实地补两句：

#strong[第一，这个统计偏高。] 它会把"断言封装在契约辅助函数里"的测试 误判为零断言 ------ 而这个仓库恰恰鼓励那种写法 （比如那个"只提交一次购买意图"的契约辅助函数）， 所以真实值比 4% 更低。

#strong[第二，零断言的浓度最高的地方，恰好是并发测试。]

比如微内核的线程安全测试里，八个"完成"标记只对应五个断言。 好的那几条非常对 ------ "并发解析同一个服务，装配计数必须恰好是 1" 是那个文件唯一真正重要的不变量，而它被直接断言了。 但另外两个测试只靠"不崩溃、不超时"过关，还有一条断言 "完成的操作数大于零"，基本不可证伪。

#strong[这里有一个值得单独说的现象：手艺最强的地方，验证反而最弱。]

写出那个三态机的人#strong[知道]它是对的 ------ 他推理过所有的交错。 而"我知道它对"会实实在在地降低写断言的动力， 因为断言在他看来是在证明一件已经确定的事。

#strong[这是典型的专家盲区，而且它有一个很坏的性质： 它精确地作用在系统里最难改、最少人懂的那部分代码上。] 半年后来改这段代码的人（或 Agent）拿不到那个"我知道它对"， 他只有那两条不会失败的测试。

== 两条专门用来防"测试看起来通过了"的规则
<sec-anti-fake-rules>
#ref(<sec-unconditional-skip>, supplement: [第]) 讲了第一条。第二条更具体：

它匹配"点到成功为止"这一类重试点击的辅助函数。规则的说明是：

#quote(block: true)[
这类辅助函数会把一次#strong[就绪延迟升级成重复交易]， 还会在按钮消失动画期间触发测试框架的异常。
]

修法是删掉这些辅助函数，改用一个只提交一次购买意图的契约方法。

#strong[这两处代码的共同点是：它们都能编译、都能跑、CI 全绿。]

而人在评审里几乎不可能从一个叫"点到订阅成功为止"的函数名 联想到"这会重复扣款"。

#strong[它们也不是代码风格问题 ------ 它们是用测试的外观掩盖了覆盖的消失。] 这正是"绿灯到底可不可信"必须有一层独立守卫的原因。

== 三个坑的共同结构
<sec-three-traps-structure>
三个坑分别是"没跑"、"跑的不是同一件事"、"红在负载上"。 把它们摆在一起，能看到一个共同的骨架：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([坑], [你以为在测什么], [实际在测什么],),
  table.hline(),
  [假绿], [行为], [#strong[测试目标存在]],
  [本机 vs CI], [代码], [#strong[本机的那套环境]],
  [墙钟超时], [异步副作用], [#strong[机器当时有多忙]],
)
#strong[三个都是"测量对象错了"，而不是"测量出错了"。]

这个区分很重要，因为它决定了修法：

- 测量#strong[出错]了 → 修测量的实现（重试、加日志、改超时）
- 测量#strong[对象]错了 → #strong[换一个测量对象]

而人（和 Agent）的默认反应是前者。看到 flake，第一反应是重试或者 把超时调大 ------ 那正是在一个错误的测量对象上做优化。

#ref(<sec-sensor-faults>, supplement: [章节]) 会把这个区分正式化。

== 为什么 Agent 特别容易停在"看起来在跑"
<sec-agent-stops-here>
这一节解释一个现象：#strong[为什么这三个坑对 Agent 的杀伤力 比对人大得多。]

人在遇到"测试通过了"的时候，会有一些说不清的怀疑 ------ 这个功能这么复杂，怎么一次就过了？这种怀疑来自经验， 而且它经常是对的。

#strong[Agent 没有这个怀疑，而且它的工作循环鼓励它没有。]

它的循环是：改代码 → 跑检查 → 检查通过 → 报告完成。 #strong["检查通过"在这个循环里是一个终止条件]， 而一个终止条件被满足的时候，没有任何机制会促使它继续追问。

这就是为什么"执行了 N 个测试且 N 不为 0"这条检查如此重要： #strong[它把一个隐含的假设变成了一个显式的终止条件。]

同样的逻辑解释了变异验证的价值：它在循环里插入了一步 #strong["证明这条测试有能力失败"]，而这一步的输出是一个新的、 无法被绕过的事实。

== 一个关于测试数量的反直觉观察
<sec-more-tests-worse>
这套系统里测试代码占全部代码的三分之一以上。 但这一章的所有内容都在说明一件事：

#quote(block: true)[
#strong[测试的数量和测试的可信度，是两个几乎独立的量。]
]

一个有一万条测试的套件，如果其中有一千条从来不会失败， 那么它提供的保护和一个有九千条测试的套件#strong[完全一样] ------ 而它的维护成本高 11%，运行时间长 11%， 并且#strong[你不知道是哪一千条。]

在 Agent 大量产出测试的场景下，这个问题会加速：

- Agent 很擅长写出#strong[语法正确、命名合理、看起来在测东西]的测试
- 它不擅长（也没有动力）判断这条测试是否真的能失败
- 而每一条新增的测试都会稀释你对整个套件的信任

#strong[所以在这个场景下，"测试覆盖率"这个指标的价值下降了， 而"变异验证"这个指标的价值上升了。]

前者衡量的是"跑到了多少行"，后者衡量的是"守住了多少行为" ------ 而只有后者在 Agent 大量产出的时候仍然可信。

== 测试金字塔在 Agent 场景下的形变
<sec-pyramid-deformed>
经典的测试金字塔是一条建议：多写单元测试，少写端到端测试。 它的理由是成本 ------ 上层贵、慢、脆。

#strong[在 Agent 场景下，这条建议的理由变了，而结论部分保留。]

理由变了，是因为多了一个经典金字塔没有考虑的因素：

#quote(block: true)[
#strong[谁在写这些测试，以及他有没有动力让它们真的能失败。]
]

一个人写单元测试时，他脑子里有那段代码的模型， 他知道哪些边界值得测。而一个 Agent 写单元测试时， 它的优化目标是"让检查变绿"------ 而单元测试是#strong[最容易被写成假绿]的一层， 因为它的输入完全由测试自己构造。

所以在 Agent 场景下，金字塔的每一层有了新的性质：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([层], [经典理由], [Agent 场景下新增的性质],),
  table.hline(),
  [单元], [便宜、快], [#strong[最容易假绿]（输入自造，断言自选）],
  [集成], [中等], [中等],
  [端到端], [贵、脆], [#strong[最难假绿]（真实路径，难以伪造）],
)
#strong[这不是说要倒过来堆端到端测试] ------ 成本的理由仍然成立。

它说的是：#strong[单元测试那一层需要额外的守卫]， 而这正是变异验证和"执行数不为零"这两条存在的理由。

#strong[换句话说：金字塔的形状不变，但底座需要加固。]

== 覆盖率在 Agent 场景下的贬值
<sec-coverage-devalued>
再看一个指标的形变。

覆盖率一直有一个众所周知的局限：它衡量"跑到了多少行"， 不衡量"验证了多少行为"。

#strong[在人写测试的场景下，这两者是弱相关的] ------ 一个人跑到了一行代码，通常是因为他想验证那行代码。

#strong[在 Agent 写测试的场景下，这个相关性大幅下降。]

原因是：#strong[提高覆盖率有一条不经过"验证行为"的捷径] ------ 调用那个函数，然后断言它没有崩溃。这条捷径能让覆盖率达标， 而它验证的东西接近于零。

所以这套系统的覆盖率规则里，那六条限制中最后一条是：

#quote(block: true)[
#strong[覆盖率不替代有意义的断言与变异验证。]
]

#strong[这条不是免责声明，是承认这个指标已经不够用了。]

而它的替代品是变异验证：#strong[衡量"守住了多少行为"， 而不是"跑到了多少行"。]

两者的成本差别很大 ------ 覆盖率是自动统计的， 变异验证需要一次额外的操作。但在 Agent 场景下， #strong[前者的信息量大幅下降，而后者没有。]

== 一个诚实的困难：变异验证很难自动化
<sec-mutation-hard>
这本书反复推荐变异验证，所以得说清楚它的困难。

#strong[手工的变异验证（改 bug 时先让测试红一次）成本是零]， 因为你本来就要跑一次。

#strong[而自动化的变异验证成本很高]：你需要程序性地生成代码变异 （改一个比较符、删一行、反转一个条件），然后跑全部测试， 看有没有测试变红。一次完整的变异验证可能要跑几千次测试套件。

这套系统的做法是#strong[只在关键路径上手工做]， 而不是建一套自动变异验证基础设施。

#strong[这个取舍值得说清楚，因为它反映了一条更一般的原则：]

#quote(block: true)[
#strong[一个昂贵但正确的判定，如果只在关键路径上施加， 仍然比一个便宜但不可信的判定覆盖全部要好。]
]

而"关键路径"在这里有一个具体的定义：#strong[每一次修复 bug 的时候。] 因为那正是"这条测试守不守得住行为"这个问题最重要的时刻 ------ 你刚刚证明了这个行为会出错，现在要确保它不会再错。

== 测试的另一个作用：它是给 Agent 的规格
<sec-tests-as-spec>
这一章到这里讲的都是"测试作为判定"。还有一个作用值得说， 因为它在 Agent 场景下比在人的场景下重要得多。

#strong[一条测试同时是一份规格。]

而 Agent 读规格的方式和人不一样：人读文档， #strong[Agent 更倾向于读代码 ------ 而测试是最接近"可执行的规格"的代码。]

这有两个实际后果：

#strong[一、测试的可读性变成了一个功能性需求。]

一条断言写成 #NormalTok("XCTAssertEqual(result, expected)"); 和写成 #NormalTok("XCTAssertEqual(result.status, .refunded, \"退款后状态必须是 refunded\")");， 对判定来说是等价的（都能失败），#strong[但对 Agent 来说信息量差很多。]

后者告诉了它这个行为的#strong[意图]，而意图是它在修改相关代码时需要的。

#strong[二、测试的组织方式变成了一份领域地图。]

一个按业务场景组织的测试套件，Agent 读一遍就知道这个模块有哪些场景； 一个按类和方法组织的测试套件，它只知道有哪些函数。

#strong[这不是"写测试的最佳实践"，这是"给 Agent 的规格"这个新用途 带来的新要求。]

== 测试代码占三分之一，这个比例意味着什么
<sec-test-ratio>
这套系统里测试代码占全部代码的三分之一以上。

这个数字容易被当成一个目标，而它不该是。#strong[它是一个结果。]

它的成因是：#strong[每一次修 bug 都要求变异验证， 而变异验证意味着每一个被修的 bug 都留下了一条能失败的测试。]

所以这个比例真正衡量的不是"我们很重视测试"， 而是#strong["我们修过多少个 bug，而且每一个都留下了守卫"]。

#strong[这也意味着这个比例不该被当成新项目的目标。] 一个新项目没有那些 bug，所以它不需要那些测试 ------ 按比例去凑，凑出来的一定是没有守住任何行为的那种。

而一个更有意义的指标是：

#quote(block: true)[
#strong[有多少条测试，是在某次真实的 bug 修复中诞生的？]
]

因为那些测试有一个别的测试没有的性质： #strong[它们守的是一个已经被证明会出错的行为。]

== Agent 写的测试和人写的测试有什么系统性差别
<sec-agent-tests-differ>
诚实地列几条观察，因为这决定了该怎么审：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([维度], [Agent 写的测试倾向于],),
  table.hline(),
  [数量], [#strong[多] ------ 它没有"写测试很烦"这个阻力],
  [覆盖广度], [广 ------ 它会把参数组合枚举得很全],
  [#strong[断言深度]], [#strong[浅] ------ 倾向于断言"没崩溃"和"返回非空"],
  [#strong[边界情况]], [#strong[中] ------ 会测明显的边界，不会测需要领域知识的],
  [命名与组织], [好 ------ 它擅长产生一致的结构],
  [#strong[是否能失败]], [#strong[未知] ------ 而这是唯一真正重要的那一列],
)
#strong[前五列都是它的优势，而第六列是它的盲区。]

这张表给出了一个很具体的审查策略： #strong[不要审 Agent 写的测试覆盖得全不全（它比你全）， 审它们能不能失败。]

而"能不能失败"有一个几乎零成本的检验方式， 就是变异验证 ------ 在它写完之后，改坏一处被测代码， 看有几条测试变红。#strong[如果一条都没红，那这一批测试 不管有多少条，守住的行为是零。]

== 端到端测试的特殊地位
<sec-e2e-special>
这一章大部分内容在讲怎么让下层测试可信。 但端到端测试有一个别的层没有的性质，值得单独说：

#quote(block: true)[
#strong[它是唯一一层"难以被伪造"的测试。]
]

原因是它的输入不由测试构造 ------ 它走的是真实的路径， 穿过真实的边界（#ref(<sec-shape-e>, supplement: [第])），触发真实的副作用。

#strong[一个能通过端到端测试的实现，很难是完全错的。]

而这个性质在 Agent 场景下变得更重要（#ref(<sec-pyramid-deformed>, supplement: [第])）。

=== 但它的代价也是真实的
<sec-e2e-cost>
从实测数据看：中位 14.9 分钟，是结构检查的三倍； 在 CI 上一个测试目标独占一个执行任务； 而且它是那两类"无法靠产品代码消除的基础设施 flake"的所在地 （#ref(<sec-named-flakes>, supplement: [第])）。

#strong[所以正确的态度不是"多写端到端测试"， 是"让每一条端到端测试都值那个价钱"。]

而"值那个价钱"有一个判据：

#quote(block: true)[
#strong[这条端到端测试覆盖的路径， 有没有可能被下层的测试完整覆盖？]
]

有 → 移下去。没有（因为它跨越了太多组件）→ 留着，它是值的。

=== 那两条防假绿的规则为什么都在这一层
<sec-e2e-rules>
#ref(<sec-anti-fake-rules>, supplement: [第]) 里那两条规则 ------ 禁止无条件跳过、 禁止重试点击 ------ #strong[都是针对端到端测试的。]

这不是巧合。因为#strong[端到端测试是最贵、最慢、最容易 flake 的一层， 所以它也是"想办法让它变绿"这个冲动最强的一层。]

一个 flake 的端到端测试，最省事的处理方式就是跳过它或者加重试 ------ #strong[而这两个动作都会让它从"最难伪造"变成"完全伪造"。]

所以这两条规则守的其实是端到端测试这一层的#strong[特殊价值]： 一旦它可以被轻易地弄绿，它就失去了它唯一的优势。

== 测试的三个失败等级
<sec-failure-grades>
最后一个框架，用来判断一次测试失败该多认真对待：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([等级], [表现], [该怎么办],),
  table.hline(),
  [#strong[一级：稳定地红]], [每次都红，本地也红], [最好的一种，直接修],
  [#strong[二级：只在 CI 红]], [本地绿，CI 红], [#ref(<sec-local-vs-ci>, supplement: [第]) 那三个变量],
  [#strong[三级：偶发地红]], [同一份代码，有时红有时绿], [#strong[最危险]],
)
#strong[第三级最危险，而不是最不重要。]

因为它给出的信息是"这里有一个你不理解的东西"------ 而不理解的东西不会因为重试而消失，它只是被掩盖了。

而 #ref(<sec-wall-clock>, supplement: [第]) 讲的那个墙钟超时是三级失败最常见的成因， 它有一个特征可以快速识别：#strong[失败率和机器负载相关。]

如果一条测试在 CI 忙的时候更容易失败， 那它大概率是在测机器负载，不是在测代码。

== 这一章和形状表的对应
<sec-tests-shapes>
这一章讲的三个坑，正好对应形状表里的三项， 而把它们对齐能看出一件事：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([坑], [形状], [而它在别的层的形态],),
  table.hline(),
  [假绿], [A（探针测错）], [健康检查只测读路径 · 定时任务坏了不报错],
  [本机 ≠ CI], [G（本地≠远端）], [手工部署和自动部署不一致],
  [墙钟超时], [A 的一个变体], [任何"用时间给异步设上界"的地方],
)
#strong[第三行值得注意：墙钟超时其实也是形状 A] ------ 它测的是"这段时间内发生了吗"，而你想知道的是"它发生了吗"。

#strong[同一个形状，在测试里叫 flake，在运维里叫"偶发超时"， 在数据管道里叫"延迟到达的数据被丢弃"。]

而它们的正确修法也是同一个： #strong[用一个真正代表"这件事发生了"的信号，替换掉时间。]

== 测试作为判定层里唯一"看行为"的一层
<sec-only-behavioral>
三层判定里，只有这一层看的是#strong[运行时的事实]。

结构检查看的是静态的代码形态，路径不变量看的是改动的内容 ------ #strong[两者都不需要程序跑起来。]

这个区别有两个后果：

#strong[一、它是唯一能发现"逻辑错了"的一层。] 一段代码可以放在完全正确的位置、遵守所有的架构约定、 不触碰任何路径不变量，#strong[而它算错了。]

#strong[二、它也是唯一会被"环境"影响的一层。] 另外两层的结果只取决于代码，而这一层取决于代码 #strong[加上它运行的那个环境] ------ 这就是形状 G 的来源， 也是为什么基建故障在这一层的占比最高（#ref(<sec-infra-share>, supplement: [第])）。

#strong[这两个后果一起解释了为什么这一层最贵、最慢、最不稳定， 而且不可替代。]

== 一个实用的排查顺序
<sec-triage-order>
一次测试失败，按这个顺序问，因为#strong[成本从低到高]：

#Skylighting(([#NormalTok("① 它真的跑了吗？            → 看执行数（成本：一眼）");],
[#NormalTok("② 本地能复现吗？            → 跑一次（成本：几分钟）");],
[#NormalTok("③ 是不是基建故障？          → 看退出码/日志（成本：一眼）");],
[#NormalTok("④ 换个负载能复现吗？        → 串行跑一次（成本：几分钟）");],
[#NormalTok("⑤ 拿掉最近的改动还红吗？    → 二分（成本：几轮）");],));
#strong[大部分人从第⑤步开始]，而前四步的成本加起来不到第五步的十分之一。

而第①步之所以排第一，正是因为 #strong[它一旦为否，后面所有步骤的结论都是空话] （#ref(<sec-filter-trap>, supplement: [第]) 那个上游污染）。

== ⚙️ 小规模怎么做
<sec-tests-small>
这一章里几乎没有一条需要基建。四件今天就能做的：

#strong[一、在 CI 里加一行，断言测试执行数不为零。] 半小时。这是全书投入产出比最高的一条改动。

#strong[二、每次修 bug 时，先让新测试红一次再让它绿。] 这就是变异验证的最小形态，成本是零 ------ 你本来就要跑一次。

#strong[三、grep 你的测试里的无条件跳过。] 通常能找出一批，而且每一个背后都有一个"当时说好回头修"的故事。

#strong[四、给你最慢的那个测试任务的超时值，写一句期望值论证。] 调短的收益是什么，代价是什么？调长的代价在正常情况下是多少？ 大部分人做完这个计算会发现自己的超时设反了。

== 测试基础设施本身该被怎么对待
<sec-test-infra>
这一章讲了很多关于测试的纪律，但有一个层面没讲： #strong[跑测试的那套东西自己。]

测试运行器、测试宿主、fixture 生成、CI 的编排逻辑 ------ #strong[这些代码不产生任何业务功能，而所有的测试结论都建立在它们之上。]

#strong[而它们通常没有任何判定覆盖。]

#ref(<sec-wrapper-gap>, supplement: [第]) 里那个自己承认的缺口就是一个实例： 构建文件里的排除清单没有任何东西校验它的完备性， #strong[新加一个套件忘了同步就静默双跑或静默不跑。]

#strong[这是形状 A 在测试基础设施上的形态]， 而它比业务代码里的形状 A 更危险， 因为#strong[它影响的是所有测试的结论，而不是某一个功能。]

=== 三条可以立刻做的
<sec-test-infra-checks>
#strong[一、断言测试目标的数量。] 和哨兵下限是同一个思想：如果你的仓库有 200 个测试目标， 断言这个数不会突然掉到 150。

#strong[二、给测试宿主加一条"我还活着"的测试。] 一条永远应该通过的测试，加一条永远应该失败的测试 （用预期失败标记）。#strong[如果第二条突然通过了，说明宿主坏了。]

#strong[三、定期跑一次全量，对照分片跑的结果。] 稀疏测量（#ref(<sec-depgraph>, supplement: [第])）的正确性依赖依赖图的准确性， 而依赖图会因为动态加载、反射、配置驱动的依赖而不准。 #strong[定期对拍是唯一能发现这类偏差的方式]（#ref(<sec-analytical-redundancy>, supplement: [第])）。

== 一个关于测试的常见误解
<sec-test-misconception>
最后处理一个误解，因为它会让这一章的建议被误用：

#quote(block: true)[
#strong["这一章是在说要写更多测试。"]
]

不是。这一章从头到尾没有一处建议"多写测试"。

它讲的全部是#strong[已有的测试可不可信]： 跑了没有、断言有没有能力失败、 它测的是代码还是环境、它在别的机器上是不是同一件事。

#strong[理由是：在 Agent 场景下，测试的数量不是稀缺资源， 测试的可信度才是]（#ref(<sec-more-tests-worse>, supplement: [第])）。

一个 Agent 可以在十分钟内写出一百条测试。 #strong[而让那一百条里有五十条真的能失败，需要的是机制，不是勤奋。]

#strong[所以这一章的所有建议都是关于机制的]： 执行数断言、变异验证、防假绿的规则、成本论证。

#strong[没有一条是"更努力地写测试"。]

== 这一章和第九章的一处呼应
<sec-tests-toolchain-echo>
#ref(<sec-toolchain-discipline>, supplement: [第]) 里那个伪本地化审计流水线的例子 ------ #strong[用固定的 sleep 改成盯日志里的路由事件] ------ 和这一章的坑三（#ref(<sec-wall-clock>, supplement: [第])）是同一条纪律。

#strong[而两处的出现顺序值得注意：那个流水线的改造， 比这一章讲的那条微内核轮询的修复要早。]

也就是说：#strong[同一条纪律，在工具链里已经执行了， 在最核心的运行时里还没有。]

#ref(<sec-discipline-incomplete>, supplement: [第]) 解释了原因（看得见的先修）， 但这里可以补一层：

#strong[工具链里的违规会立刻产生可见的后果] ------ 审计流水线出假阴性，有人会注意到。

#strong[而微内核那个轮询在正常情况下几乎不会触发] （它只在两个线程同时解析同一个未装配的服务时才走到）。

#strong[所以它的违规不产生任何后果，直到某一天在高负载下产生了。]

#strong[这正好是形状 A 的一个变体，而且是最难对付的那个]： 不是探针坏了，是#strong[这段代码本身处在一个没有探针的位置。]

而它的解法不是"更严格地要求自己" ------ 是给那条路径加一个测试（那条路径现在没有测试覆盖）。

#strong[一条没有测试覆盖的代码路径，它的纪律执行情况是不可观测的] （#ref(<sec-observability>, supplement: [第])）。

== 一个诚实的自我评估
<sec-tests-self-assessment>
这一章讲了很多机制，那么它们的实际效果如何？

#strong[可核验的数字]：33,239 个测试函数，4.0% 零断言 （而这个统计偏高，#ref(<sec-assertion-density>, supplement: [第])）。

#strong[而不可核验的是最重要的那个数]：#strong[缺陷逃逸率] ------ 有多少问题是合并之后才被发现的（#ref(<sec-no-escape-rate>, supplement: [第])）。

#strong[这本书没有这个数，所以这一章的所有机制， 它们的实际效果是未被证明的。]

能说的只有：#strong[这些机制针对的失败模式是真实的 （每一条都对应一次具体的踩坑）， 而机制本身在按设计工作（有输出、有拦截记录）。]

#strong["针对的问题是真的"和"解决了那个问题"之间， 还差一个数] ------ 而那个数值得被补上， 因为它是唯一能验证这一整章的东西。

== 这一章能被压成的三句话
<sec-tests-three-lines>
#strong[一、绿灯本身需要被验证。]

三个坑（假绿、本机≠CI、墙钟超时）的共同结构是 #strong["你以为在测 A，实际在测 B"]（#ref(<sec-three-traps-structure>, supplement: [第])）------ 而这在 Agent 场景下是主流失败模式，不是边缘情况。

#strong[二、衡量"守住了多少行为"，不是"跑到了多少行"。]

覆盖率在 Agent 场景下贬值了（#ref(<sec-coverage-devalued>, supplement: [第])）， #strong[而变异验证没有] ------ 因为它衡量的是测试有没有失败的能力， 而那正是唯一重要的那个性质。

#strong[三、这一章讲的全部是机制，没有一条是"更努力地写测试"。]

因为测试的数量不是稀缺资源，#strong[测试的可信度才是] （#ref(<sec-test-misconception>, supplement: [第])）。

== 一张速查表
<sec-tests-cheatsheet>
把这一章的可执行部分压成一页：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([症状], [先查什么],),
  table.hline(),
  [测试通过但功能不对], [#strong[执行数是不是零]],
  [本地绿 CI 红], [并发争用 → 插桩 → locale → OS 版本],
  [同一份代码时红时绿], [#strong[失败率和机器负载相关吗]],
  [加了测试但 bug 还是漏了], [拿掉修复，那条测试会红吗],
  [CI 老是红但不是代码的错], [退出码有没有区分基建故障],
  [测试越来越多但信心没涨], [抽查十条，有几条真的能失败],
)
#strong[六行，覆盖了这一章的全部实用内容。]

而它们的共同点是：#strong[每一行的"先查什么"都比 "重跑一次"或"调大超时"便宜，而且能给出真正的信息。]

= Guardrails：结构的事实
<guardrails结构的事实>
= Guardrails：结构的事实
<sec-guardrails>
测试回答的是"跑起来之后发生了什么"，这一层回答另一个问题：#strong[这段代码放得对不对。]

它做的事情是把仓库里那些反复出现的约定 ------ 依赖方向、owner 边界、 某个 API 不该出现在哪里 ------ 收敛成同一个入口的判定， 并且保证本地和 CI 跑的是同一条命令、同一份策略。

最后这一点很重要，重要到值得先说：#strong[只要两边能跑出不同结果， Agent 就会开始拿「本地是好的」当理由。] 而一旦这个理由被接受一次， 这一层就废了。

== 性价比最特别的一层
<sec-cheapest-layer>
先看一组数。取完整的一天：

- 结构检查跑了 284 个任务，失败 20 个 ------ #strong[7.0% 的失败率，是所有类别里最高的]， 比界面测试的 4.7%、单元测试的 3.9% 都高
- 但它的中位耗时只有 5.2 分钟，#strong[是界面测试的三分之一]

#strong[最常拦住人的那一层，恰好也是最便宜的一层。]

这不是巧合。结构问题不需要把程序跑起来就能发现 ------ 依赖方向、目录归属、 某个符号出现在了不该出现的地方，这些都是静态事实。而它一旦漏进主干， 代价要等到很久以后才付：一条错误的依赖方向不会让任何测试变红， 它只会在半年后让某个模块无法被单独抽出来。

== 策略与机制分离
<sec-policy-mechanism>
整套东西被切成三段，每段只做一件事：

#Skylighting(([#NormalTok("guardrails/          只放声明式策略，不含实现");],
[#NormalTok("  config/            不可变策略");],
[#NormalTok("  baseline/          历史债务台账");],
[#NormalTok("  arbiters/          路径清单");],
[#NormalTok("  architecture/rules.toml");],
[#NormalTok("      ↓ 薄引导层");],
[#NormalTok("guardrails/guard     丢弃环境里的版本覆盖，只加载封闭配置，");],
[#NormalTok("                     构建出运行器后把自己替换掉");],
[#NormalTok("                     不含任何清单 / lint / 裁决逻辑");],
[#NormalTok("      ↓ 执行");],
[#NormalTok("Rust 运行器          仓库扫描 · 依赖图查询 · 语言适配 · lane 编排 · 结果渲染");],));
中间那层的两句注释值得单独说：#strong["丢弃环境里的版本覆盖"]和 #strong["只加载封闭配置"]。这两件事合起来保证了一件事 ------ 判定的结果不取决于运行它的那台机器上装了什么。

而"构建出运行器后把自己替换掉"意味着引导层不会留在进程里， 它没有机会影响判定。#strong[引导层不参与判定，这是一条被实现方式保证的约束， 而不是一条纪律。]

== baseline 不是豁免清单
<sec-baseline>
有一个概念一定要分清，因为混淆它的代价很高。

#NormalTok("baseline"); 是一份#strong[被审阅过的历史债务台账，只允许单调收敛] ------ 存量可以慢慢清掉，新代码不许往里加。真正的不可变策略在 #NormalTok("config/");。

两者混为一谈的话，baseline 就会变成一个"加进去就不用管了"的垃圾桶。 #strong[而这恰恰是 Agent 最容易选择的路径]：面对一条报错， "把它加进豁免清单"永远比"改代码"便宜。

所以单调性本身是一条被检查的规则。一次运行的输出里会有这样一行：

#Skylighting(([#NormalTok("guardrails: baseline policy passed against c3c425291e7f");],));
它比对的是：这次的 baseline 相对某个基准版本，有没有增长。 #strong[债务可以还，不可以借。]

=== 单调性是怎么被保证的
<sec-monotonic-impl>
"只允许单调收敛"这句话，落到实现上有一个容易做错的细节， 而这套系统做对了 ------ 它值得单独看，因为#strong[做错的版本看起来完全正常。]

台账里存的是每一条违规的指纹。天真的实现会把它们收进一个#strong[集合]。

而实际的实现用的是#strong[多重集]：

#Skylighting(([#KeywordTok("pub");#NormalTok(" ");#KeywordTok("struct");#NormalTok(" FingerprintMultiset ");#OperatorTok("{");],
[#NormalTok("    counts");#OperatorTok(":");#NormalTok(" BTreeMap");#OperatorTok("<");#DataTypeTok("String");#OperatorTok(",");#NormalTok(" ");#DataTypeTok("usize");#OperatorTok(">,");],
[#OperatorTok("}");],));
它记的不是"有哪些指纹"，是"#strong[每个指纹出现了几次]"。

区别在哪？假设某个文件里有三处一模一样的违规 ------ 同样的规则、同样的模式、只是在不同的行。

- #strong[用集合]：三处折叠成一个条目。有人再加第四处， 集合里还是那一个条目，#strong[单调性检查通过]。
- #strong[用多重集]：计数从 3 变成 4，#strong[当场拦下]。

#strong[用集合的版本，会让"添加与现有违规完全相同的新违规"变成免费的。] 而这恰恰是最容易发生的一种债务增长 ------ 因为复制粘贴一段 已经在台账里的代码，是所有增长方式里最省事的那一种。

同一个文件里还有一句：

#Skylighting(([#ControlFlowTok("if");#NormalTok(" fingerprint");#OperatorTok(".");#NormalTok("is_empty() ");#OperatorTok("{");],
[#NormalTok("    ");#PreprocessorTok("bail!");#NormalTok("(");#StringTok("\"fingerprint must be non-empty\"");#NormalTok(")");#OperatorTok(";");],
[#OperatorTok("}");],));
#strong[空指纹被直接拒绝]，因为一个空指纹会匹配所有东西 ------ 它会让台账变成一张万能通行证。

#strong[这两个细节的共同点：它们防的都不是"有人故意作弊"， 而是"一个看起来无害的实现选择，悄悄打开了一个口子"。]

=== 台账的更新是事务性的
<sec-baseline-transaction>
台账的写入路径下面有一个专门的事务子模块，分成会话、提交、快照三部分。

这意味着：#strong[一次台账更新要么全部生效，要么完全不生效。]

为什么需要这个？因为台账更新通常发生在一次大规模清理之后 ------ 而如果写到一半失败（进程被杀、磁盘满、工具崩溃）， 留下的是一个#strong[部分更新的台账]：一部分违规被清掉了，一部分还在。

而部分更新的台账有一个很坏的性质：#strong[它是自洽的。] 下一次运行不会报错，它只会以那个错误的状态作为新基准。 #strong[债务凭空消失了一部分，而没有任何人会知道。]

（二十三条规则的全量清单在 #ref(<sec-appendix-rules>, supplement: [附录])，按「值得先抄哪条」分了三梯队。）

== 一条规则长什么样
<sec-rule-anatomy>
看一条完整的定义。这条规则守的是"日志只能在唯一的一个文件里定义"：

#Skylighting(([#KeywordTok("[[rule]]");],
[#DataTypeTok("id");#NormalTok("   ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"LOGGER-SINGLE-OWNER\"");],
[#DataTypeTok("kind");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"forbid_pattern\"");],
[#DataTypeTok("enforce");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#ConstantTok("true");],
[#DataTypeTok("scope");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("[");#StringTok("\"Modules/**/*.swift\"");#OperatorTok(",");#NormalTok(" ");#StringTok("\"Foundation/**/*.swift\"");#OperatorTok("]");],
[#DataTypeTok("source_view");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"code_only\"");],
[#DataTypeTok("pattern");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("'");#VerbatimStringTok("Logger\\(label:");#StringTok("'");],
[],
[#DataTypeTok("allow_files");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("[");],
[#NormalTok("    ");#StringTok("\"**/*Logger.swift\"");#OperatorTok(",");#NormalTok("  ");#StringTok("\"**/*Tests.swift\"");#OperatorTok(",");#NormalTok("  ");#StringTok("\"**/*Mock.swift\"");#OperatorTok(",");],
[#NormalTok("    ");#StringTok("\"**/TestHost/**\"");#OperatorTok(",");#NormalTok("    ");#StringTok("\"**/Preferences/Tools/**\"");#OperatorTok(",");],
[#NormalTok("    ");#StringTok("\"**/MicroKernel.swift\"");#OperatorTok(",");],
[#OperatorTok("]");],
[],
[#DataTypeTok("sentinel_min");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#DecValTok("50");],
[],
[#DataTypeTok("incident");#NormalTok("  ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"微内核服务：日志只在唯一的 Logger.swift 定义\"");],
[#DataTypeTok("fix_hint");#NormalTok("  ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"在该 target 的 Logger.swift 里定义 logger，其它文件引用它\"");],));
四个字段值得单独说，因为它们各自解决一类会让规则失效的问题。

=== #NormalTok("source_view = code_only");：规则不会被自己的文档绊倒
<sec-source-view>
规则只看代码，不看注释和字符串字面量。

所以上面那段讲解这条规则的注释文字，本身不会把这条规则触发掉。

#strong[这类「规则被自己的文档绊倒」的情况在纯文本匹配的检查里非常常见]， 而它的后果不是误报一次那么简单：一条会误报的规则会被绕过， 绕过之后它还继续消耗信任。

同类的坑在路径清单那边更狠 ------ 有一份清单把某个文档目录#strong[故意排除在扫描范围之外]， 因为禁止模式按整行匹配，并不区分代码和散文， 那句用来解释"禁止某个参数"的说明文字，本身就会触发这条规则。

=== #NormalTok("allow_files");：每条豁免都写了理由
<sec-allow-files>
原始定义里，每一条豁免上面都跟着一行注释说明它为什么存在。 其中最说明问题的是 #NormalTok("**/Preferences/Tools/**"); 这一条，它的理由是：

#quote(block: true)[
那是构建期的代码生成器，它「发射」出 #NormalTok("Logger(label:"); 这个字符串， 那是字面量，不是真的 logger。
]

#strong[如果没有这行注释，半年后的人只会看到一条不明所以的白名单， 然后要么不敢动、要么随手删掉。] 两种都是坏结果：不敢动意味着这条豁免 永远留在那里，随手删掉意味着代码生成器明天开始报错。

这是一条可以直接抄走的纪律：#strong[豁免必须带理由，而且理由要写它为什么 不是违规，不是写"这里特殊"。]

=== #NormalTok("sentinel_min");：检查器对自己的检查
<sec-sentinel>
如果某一天匹配数突然掉到阈值以下，更可能的解释是#strong[扫描逻辑坏了]， 而不是代码一夜之间变干净了。所以这种情况会被当成故障报出来， 而不是当成通过。

这个机制在实现上比它在配置里看起来的更严格。看类型：

#Skylighting(([#KeywordTok("pub");#NormalTok("(");#KeywordTok("in");#NormalTok(" ");#KeywordTok("crate");#PreprocessorTok("::");#NormalTok("config) minimum_facts");#OperatorTok(":");#NormalTok(" NonZeroUsize");#OperatorTok(",");],));
以及它是怎么被构造出来的：

#Skylighting(([#NormalTok("minimum_files");#OperatorTok(":");#NormalTok(" required_nonzero(id");#OperatorTok(",");#NormalTok(" ");#StringTok("\"sentinel_min\"");#OperatorTok(",");#NormalTok(" raw");#OperatorTok(".");#NormalTok("sentinel_min)");#OperatorTok("?,");],));
两件事被类型系统锁死了：

+ #strong[#NormalTok("required_");] ------ 哨兵是#strong[必填的]。你没法写一条不带哨兵的规则， 转换阶段会拒绝它。
+ #strong[#NormalTok("NonZeroUsize");] ------ 哨兵#strong[不能是零]。也就是说， 你没法通过把下限设成 0 来"关掉"这个自检。

#strong[一个可以被关掉的自检等于没有自检]，而这里它在类型上就关不掉。

这条设计值得单独表扬，因为它回答了一个显然的质疑： "哨兵下限是个手写常量，有人为了让规则过，把它调低不就行了？" 调低可以，#strong[移除和归零不行]。这不是完全的防御，但它把最省事的那条绕过路径堵死了。

（这个机制仍然有它的局限，见 #ref(<sec-sentinel-limits>, supplement: [第])。）

=== #NormalTok("incident"); 与 #NormalTok("fix_hint");：失败信息的质量
<sec-incident-hint>
#strong[规则不是凭空立的：先出问题，再沉淀成规则。]

失败返回的时候把"为什么有这条"和"怎么修"一起给出去， Agent 才有可能自己收敛，而不是换个写法再撞一次。

用第四部的语言说：一个只返回"失败"的判定，只提供了误差的符号； 一个返回了 owner、证据和修复方向的判定，提供了误差的#strong[方向和大小]。 #strong[只有后者能让搜索空间收缩。]

== 不是所有规则都是模式匹配
<sec-semantic-rules>
上面那条是文本模式规则，简单直接。但这一层里最能说明水平的， 是那些#strong[不能用模式匹配表达]的规则。

"禁止给 Service 加兜底 fallback"就是一条。天真的实现是"grep 一下 #NormalTok("??");"， 而真实的实现是一个近两百行的分析器，有五层过滤 ------ #strong[每一层都对应一次误报]：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([过滤], [它放行的正确写法],),
  table.hline(),
  [只对已知可选的 accessor 生效], [集合来自服务图，不是猜的],
  [剔除被局部变量遮蔽的名字], [同名的局部变量不算],
  [语句边界检查], [那个 #NormalTok("??"); 其实在下一条语句里],
  [显式不可用的右值], [#NormalTok("?? .unavailable"); 是显式声明，合法],
  [#strong[绑定跟踪]], [#NormalTok("let x = accessor()"); 之后再 #NormalTok("x ?? y");],
)
最后一条是分界线。它不是在匹配文本，#strong[它在追踪一个值的来源] ------ 先找到"从一个已知可选的 accessor 取值并绑定到局部变量"， 再动态构造一个针对那个变量名的模式去找兜底。

#strong[这是 lint 和 checker 的区别。] lint 匹配写法，checker 追踪语义。

而这五层过滤的存在方式本身就是一条经验：#strong[你没法一次写对一条规则。 它的最终形态是被真实代码里的正确用法一次次逼出来的。]

== 配置的两个类型层
<sec-raw-validated>
还有一处设计值得学，它对付的是形状 D（配置声明了但从未生效）。

配置被分成两个类型层：#NormalTok("raw"); 是从 TOML 直接反序列化出来的， #NormalTok("validated"); 是通过校验之后的。而 #NormalTok("validated"); 类型的字段全都是 #NormalTok("pub(in crate::config)"); 可见性 ------ #strong[也就是说，你没法在配置模块之外 凭空构造一个"已校验"的配置。]

它的效果是：#strong[一个函数只要拿到 #NormalTok("validated"); 类型，就不需要再检查它合不合法。] 合法性由类型携带，不由调用方的记性携带。

对照一下形状 D 里那次真实事故：某个配置因为 TOML 子表的解析问题被整段吞掉， 配额声明了却从未生效，而且没有任何东西报错。 #strong[在 raw→validated 这种分层下，那次事故不会发生] ------ 转换阶段拿不到配额字段，就会直接失败，而不是产出一个"配额为空"的合法配置。

这是一条可以推广的原则：#strong[把"检查过了"这件事编码进类型， 而不是编码进流程。] 流程会被绕过，类型不会。

== 规则不是只有开和关
<sec-enforce-levels>
一条新规则如果一上来就拦人，仓库里的存量违规会让所有人当场停摆。

所以每条规则有两个档位：#NormalTok("enforced"); 会让检查失败，#NormalTok("report-only"); 只报数、不拦。

看一次真实输出的片段：

#Skylighting(([#NormalTok("✓ [LOGGER-SINGLE-OWNER]        (enforced)    — clean (9046 scanned)");],
[#NormalTok("✗ [L10N-TABLE-LOCALITY]        (report-only) — 966 violation(s) (50 scanned)");],
[#NormalTok("✓ [PRODUCT-ISOLATION]          (report-only) — clean (22304 scanned)");],
[#NormalTok("✗ [FILE-HEALTH]                (enforced)    — 1 violation(s) (9151 scanned)");],
[#NormalTok("guardrails: architecture failed: enforced architecture rule failed");],));
注意两行的对比：一条规则有 #strong[966 处]违规，检查照样往下走； 另一条只有 #strong[1 处]，直接把这条流水线拦掉了。

#strong[一条规则拦不拦人，跟它违规多少无关，只跟它是不是 enforced 有关。]

这份输出还顺带把前面几节讲的东西摆在了台面上： 每条规则后面的 #NormalTok("scanned"); 数就是#strong[哨兵的读数]（这次扫了 9,046 处）， 而 #NormalTok("baseline policy passed"); 那行是#strong[历史债务台账的单调性检查]。

那 966 处 report-only 的违规，每一条长这样：

#quote(block: true)[
某个本地化 key 只被一个页面用到，却放在其它目标必须依赖的表里； 把它那行 CSV 挪进那个包自己的表
]

#strong[违规在哪、唯一的使用者是谁、具体该怎么改，一行给全。] 这条规则今天还不拦人，但它每跑一次都在把这 966 处的清单摆出来 ------ 等存量收敛了，它就可以切成 enforced。

=== report-only 还是一件测量仪器
<sec-report-only-as-instrument>
这一节讲一件源系统还没用起来的事。

#NormalTok("report-only"); 通常被当成上线的过渡档。但它同时是#strong[一个正在运行的对照组] ------ 它报数但不拦，所以你能看到"如果不拦，会发生什么"的完整样本。

那 966 处已经这么跑了一段时间。于是有一个可以直接问的问题： #strong[这段时间里，这 966 处违规实际引发了几次故障？]

如果答案是零，那么这条规则可能根本不该切 enforced ------ 它守的东西也许并不重要，或者重要性远低于它将要制造的摩擦。

这个分析不需要任何新基建，数据全在手边。它现在没有被做。

== 六条通道，以及为什么要分开
<sec-six-lanes>
检查被切成六条独立的通道：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([通道], [查什么],),
  table.hline(),
  [架构], [跨模块依赖方向与 owner 边界，基于构建图],
  [路径不变量], [路径级不变量，#strong[只扫本次新增行]],
  [Swift], [语言 linter 规则与债务台账],
  [Go], [源码、目标与静态分析策略],
  [Rust], [语言 linter 与已接受的历史发现],
  [TypeScript], [linter、类型检查、覆盖率归属],
)
统一入口：

#Skylighting(([#ExtensionTok("./guardrails/guard");#NormalTok(" check                       ");#CommentTok("# 全部通道");],
[#ExtensionTok("./guardrails/guard");#NormalTok(" check swift                 ");#CommentTok("# 单条");],
[#ExtensionTok("./guardrails/guard");#NormalTok(" check architecture go rust  ");#CommentTok("# 多条");],));
#strong[分成通道不是为了组织代码，是为了让"最小重跑集合"成为可能。]

#ref(<sec-minimal-checks>, supplement: [第]) 讲过，路径不变量清单的 #NormalTok("checks"); 字段 声明的正是"命中我之后要重跑哪几条通道"。如果检查是一整块， 那么任何一次失败之后都要全部重跑 ------ 而全部重跑的耗时， 就是 Agent 每次迭代的下界。

这是 #ref(<sec-gain-and-delay>, supplement: [章节]) 那条结论在这一层的具体应用： #strong[通道的粒度决定了回路延迟的下界。]

=== 而它们共用同一套判定语义
<sec-lane-uniformity>
六条通道背后是六种完全不同的工具（各语言的 linter、类型检查器、 构建图查询）。它们的输出格式、退出码约定、失败模式全都不一样。

而运行器做的事情是把它们#strong[归一到同一个三态判定上]：

#Skylighting(([#KeywordTok("pub");#NormalTok(" ");#KeywordTok("enum");#NormalTok(" LaneOutcome ");#OperatorTok("{");],
[#NormalTok("    Passed");#OperatorTok(",");],
[#NormalTok("    PolicyViolation(");#DataTypeTok("String");#NormalTok(")");#OperatorTok(",");],
[#NormalTok("    InfrastructureFailure(");#DataTypeTok("String");#NormalTok(")");#OperatorTok(",");],
[#OperatorTok("}");],));
#strong[这个归一化是有代价的]：每接一种新工具，都要判断它的哪些失败 属于"内容违规"、哪些属于"我判不了"。而这个判断没法自动做 ------ 一个 linter 返回非零退出码，可能是发现了问题，也可能是配置文件读不出来。

#strong[但这个代价必须付。] 不付的后果是： Agent 面对六种不同的失败语义，而它无法可靠地区分 "我该改代码"和"我该等环境修好"。

== 报数模式的一个隐藏成本
<sec-report-only-cost>
#ref(<sec-enforce-levels>, supplement: [第]) 讲了报数模式的必要性。这里补一个它的代价。

一条挂着 966 处违规的报数规则，#strong[每一次运行都会把这 966 处打印出来]。

而这意味着：

- 每一次 CI 输出都多了几百行
- 输出里真正需要行动的部分（那一条拦截的规则）被淹没了
- #strong[而 Agent 读的是这个输出]

这是形状 A 的一个变种，只不过发生在输出这一层： #strong[信息量增加了，信噪比下降了，而下降是静默的。]

正确的做法是给报数模式的输出分级 ------ 摘要行常驻，详细清单按需展开。 这套系统的输出格式里已经有摘要行（每条规则一行，带扫描数和违规数）， #strong[但那 966 处的详细清单目前和摘要在同一个输出里。]

这一条列在这里，是因为它示范了一件事： #strong[一个正确的机制，在规模变大之后会长出自己的问题。] 报数模式是对的，而 966 这个数字是它自己的成功造成的 （规则覆盖了一个很大的存量）------ 然后这个成功变成了新的成本。

== 证据来源的纪律
<sec-evidence-source>
最后一条，短但要紧：#strong[语言事实的权威是编译器和 linter， IDE 或 Agent 的代码索引只能作参考，不接受它们当证据。]

索引会滞后、会缺失、会因为配置不同而给出不同答案。 用它来判定"这里没有别的调用方"，迟早会错 ------ 而这类错误的特点是它#strong[看起来像一个事实]，不像一个猜测。

== 常见的三种反对意见
<sec-guardrails-objections>
这一层最常被质疑，而三种质疑各有各的道理。逐条回答。

=== "这不就是 lint 吗，我们已经有了"
<sec-objection-lint>
区别有三处，而每一处都不是程度差异：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([], [普通 linter], [这一层],),
  table.hline(),
  [失败类型], [通过 / 失败], [#strong[通过 / 内容违规 / 判不了]],
  [规则的自检], [无], [#strong[哨兵下限，必填且不能为零]],
  [存量处理], [全局关闭某条规则], [#strong[单调收敛的台账 + 报数档位]],
)
第三行的差别最实际。普通 linter 面对存量违规只有两个选项： 全局关掉这条规则，或者在每一处加抑制注释。

- #strong[全局关掉] → 新代码也不受约束了
- #strong[逐处抑制] → 抑制注释会被复制粘贴传播， 而且没有任何东西告诉你抑制的总数在涨还是在跌

而单调台账是第三个选项：#strong[存量被记账，新增被拦住， 而且总量只能降不能升。]

=== "维护这些规则的成本会超过收益"
<sec-objection-cost>
这个担心是对的，而且 #ref(<sec-rule-retirement>, supplement: [第]) 会说明它现在还没有被解决。

但有两个数据可以缩小这个担心的范围：

#strong[一、规则的总量增长很慢。] 那个规则文件从建立到现在只有 9 次提交， 二十三条规则。#strong[规则不是被批量加进去的，是一次一条跟着一次具体改动进来的。]

#strong[二、这一层的检查成本是所有层里最低的。] 中位 5.2 分钟，是界面测试的三分之一，而它的失败率是所有类别里最高的。

所以真正的成本不在"跑"，在"维护规则本身" ------ 而那个成本的大小取决于规则的误报率， 而误报率取决于规则边界有没有被真实数据校准过（#ref(<sec-forbid-tuning>, supplement: [第])）。

#strong[结论：抄来的规则成本高，长出来的规则成本低。]

=== "Agent 会想办法绕过去"
<sec-objection-bypass>
#strong[会 ------ 只要规则误报。]

而这不是一个需要被防住的行为，它是一个#strong[信号]： 一条被频繁绕过的规则，说明它的边界画错了。

所以正确的应对不是加固规则，是#strong[测量绕过率] （#ref(<sec-bypass-rate>, supplement: [第])）。而这个数据现在没有被采集。

值得补充的是：#strong[绕过在这套系统里其实不容易。] 不是因为防得严，而是因为本地和 CI 跑的是同一条命令、同一份策略 ------ "本地是好的"这个最常见的绕过理由被结构性地堵死了。

== 规则本身也要被测
<sec-rules-tested>
schema、glob、禁止模式、lane 选择、退出码、失败渲染都有契约测试。

更重要的是另一类测试：#strong[故意造出违规的变更，用来验证检查器自己没坏。]

这和测试那章的变异验证是同一个思路，只不过对象换成了检查器 ------ 一个从来不会报错的检查器，和一个不存在的检查器，是同一个东西。

#ref(<sec-sensor-faults>, supplement: [章节]) 会给这个动作一个正式的名字。

== 从一条规则看这一层的完整成本
<sec-full-cost-of-a-rule>
把一条规则从提出到退休的全部成本列出来， 因为#strong[这一层最常见的失败是低估了后半段。]

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([阶段], [成本], [谁付],),
  table.hline(),
  [想出这条规则], [零（它来自一次事故）], [---------],
  [实现检查], [半天到几天], [一次性],
  [#strong[调参到误报可接受]], [#strong[通常比实现更久]], [一次性，但容易被低估],
  [报数模式期间清存量], [取决于存量大小], [一次性],
  [切成拦截], [零], [---------],
  [#strong[误报时被打断]], [#strong[持续]], [每个人，每次],
  [重构时跟着改范围], [持续], [偶发但必然],
  [#strong[判断它该不该退休]], [#strong[持续]], [#strong[通常没人付]],
)
#strong[第三行和倒数第一行是这张表的重点。]

第三行（调参）之所以被低估，是因为它在提案阶段是不可见的 ------ 你提出规则时想的是"禁止 X"，而实际实现时会发现有六种合法的 X。 #ref(<sec-forbid-tuning>, supplement: [第]) 里那四段推理，每一段都是这个阶段的产物。

最后一行之所以通常没人付，是因为#strong[它没有触发事件]。 没有任何时刻会有人问"这条规则还该存在吗"------ 除非有人专门去问（#ref(<sec-rule-retirement>, supplement: [第])）。

#strong[而这两行合起来解释了一个现象：规则集的实际维护成本， 大部分不在"跑"，也不在"实现"，而在这两处不可见的地方。]

== 结构检查为什么应该是最先建的那一层
<sec-structure-first>
三层判定里，如果只能先建一层，应该是这一层。三个理由：

#strong[一、它最便宜。] 中位 5.2 分钟，不需要起环境、不需要跑程序。 这意味着它可以在每一次改动上跑，而不是只在合并前跑。

#strong[二、它的失败最容易被修。] 一个结构违规的修法通常是明确的 （"把这个挪到那儿"），而一个行为失败的修法需要理解。 #strong[这个区别对 Agent 尤其重要] ------ 它意味着更高的自主修复率。

#strong[三、它拦下的问题，代价最延迟。]

第三条最反直觉，值得展开。

一个行为 bug 的代价是#strong[即时]的 ------ 功能坏了，很快会被发现。 而一个结构问题的代价是#strong[延迟]的： 一条错误的依赖方向不会让任何测试变红， 它会在半年后让某个模块无法被单独抽出来， 或者让一次重构的成本翻三倍。

#strong[而延迟的代价是最容易被低估的那种。]

这就是为什么"最常拦住人的那一层恰好也是最便宜的一层" （#ref(<sec-cheapest-layer>, supplement: [第])）不是巧合 ------ 结构问题多， 是因为它们不产生即时反馈，所以在没有检查的情况下会持续累积。

== 这一层的输出格式为什么重要
<sec-output-format>
一次运行的输出长这样：

#Skylighting(([#NormalTok("guardrails: verdict applies to e9a7c9d220a6 plus 13 uncommitted paths");],
[#NormalTok("==> guardrail: architecture");],
[#NormalTok("✓ [LOGGER-SINGLE-OWNER]        (enforced)    — clean (9046 scanned)");],
[#NormalTok("✗ [FILE-HEALTH]                (enforced)    — 1 violation(s) (9151 scanned)");],
[#NormalTok("guardrails: baseline policy passed against c3c425291e7f");],
[#NormalTok("guardrails: architecture failed: enforced architecture rule failed");],));
#strong[六行里有四条不同的信息，而它们各自服务不同的用途：]

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([行], [它回答], [谁需要它],),
  table.hline(),
  [第一行的版本号], [#strong[这个判定绑在哪个快照上]], [防止跨轮复用结论],
  [每条规则的 #NormalTok("scanned"); 数], [#strong[哨兵的读数]], [判断规则自己有没有坏],
  [档位标注], [这条会不会拦人], [判断该不该现在修],
  [台账那行], [债务有没有增长], [单调性检查],
)
#strong[第一行值得单独说。]

"这个判定适用于版本 X 加上 13 个未提交的路径" ------ 它明确了#strong[这个结论的有效范围]。

代码一变，旧结论就不再适用。这防的是 "上一轮跑绿了，这一轮沿用一下" ------ #strong[在 Agent 快速迭代的节奏下，这种复用几乎必然出错。]

而它的实现依赖一个前提：#strong[比较基线必须是确定的] （#ref(<sec-baseline-determinism>, supplement: [第])）。基线一旦浮动， "这次改了什么"就没有稳定答案，那么这个版本号也就没有意义了。

== 三个字段的信息密度对比
<sec-field-density>
用 #NormalTok("FILE-HEALTH"); 那一行做例子，看这套输出格式的信息密度：

#Skylighting(([#NormalTok("✗ [FILE-HEALTH]  (enforced)  — 1 violation(s) (9151 scanned)");],));
#strong[一行里有五个事实]：哪条规则、它拦不拦人、失败了、 违规几处、扫了多少。

而一个典型的 linter 输出是：

#Skylighting(([#NormalTok("error: file too long (312 lines, max 200)");],
[#NormalTok("  at src/foo.swift:1");],));
它有两个事实：什么错了、在哪。

#strong[缺的三个是]：这条规则叫什么（所以没法查它为什么存在）、 它是不是强制的（所以不知道该不该现在修）、 扫描面有多大（所以不知道这个检查有没有正常工作）。

#strong[这三个缺失里，第三个最要命] ------ 一个只报告违规、不报告扫描面的检查器， #strong[在它自己坏掉的时候会输出一片干净。]

== 建这一层的顺序
<sec-build-order>
如果从零开始建，按这个顺序，每一步都能独立产生价值：

#strong[第一步：一条规则 + 报数模式 + 打印扫描面。] 不要拦人。这一步的产出是一个数字：你的存量有多大。

#strong[第二步：退出码三分。] 在有第二条规则之前就做，因为它改变的是所有规则的语义。

#strong[第三步：台账 + 单调性。] 当存量大到不可能一次清完时。#strong[注意用多重集] （#ref(<sec-monotonic-impl>, supplement: [第])）。

#strong[第四步：哨兵下限。] 当规则超过五条，你已经不可能靠肉眼注意到某条规则突然不报了。

#strong[第五步：语义规则。] 当你发现自己在给一条文本规则加第三个例外时 （#ref(<sec-semantic-boundary>, supplement: [第])）。

#strong[五步之间没有跳过的余地] ------ 每一步都在为下一步提供前提。 特别是第一步：#strong[没有存量的数字，你无法判断第三步什么时候该做。]

== 一条规则的三种粒度
<sec-rule-granularity>
同一个意图，可以被写成三种粒度的规则，#strong[而它们的性质完全不同]：

=== 粒度一：禁止一个具体的写法
<sec-granularity-literal>
#quote(block: true)[
禁止 #NormalTok("Logger(label:"); 出现在生产代码里。
]

#strong[优点]：实现简单，误报可控，失败信息精确。 #strong[缺点]：只挡这一种写法。换个构造方式就绕过去了。

=== 粒度二：禁止一类行为
<sec-granularity-behavior>
#quote(block: true)[
禁止在非 owner 文件里构造日志器。
]

#strong[优点]：覆盖面大。 #strong[缺点]：需要知道"什么是构造日志器"------ 而这通常需要语义分析（#ref(<sec-semantic-boundary>, supplement: [第])）。

=== 粒度三：让这类行为不可能
<sec-granularity-impossible>
#quote(block: true)[
日志器的构造函数只对 owner 文件可见。
]

#strong[优点]：不需要规则，编译器就是执行者。 #strong[缺点]：需要语言支持，而且需要一次重构。

=== 该选哪个
<sec-granularity-choice>
#strong[默认选粒度一。]

理由是：粒度一的成本最低，而且#strong[它提供了走向粒度三所需要的数据] ------ 跑一段时间之后，你会知道有多少处、分布在哪、有哪些合法的例外。

#strong[而这些数据是设计粒度三所必需的。]

#ref(<sec-rule-endgame>, supplement: [第]) 里那条路径的完整形态是：

#Skylighting(([#NormalTok("粒度一（便宜，覆盖不全）");],
[#NormalTok("  → 跑一段，收集数据");],
[#NormalTok("    → 粒度二（贵，覆盖全）或直接 → 粒度三（最贵，问题消失）");],));
#strong[跳过粒度一直接做粒度三，是在没有数据的情况下做设计。] 而那通常会得到一个考虑不周的抽象 ------ 和目录层级 "必须被第二个实例挣得"是同一条道理（#ref(<sec-earned-level>, supplement: [第])）。

== 什么样的规则不该存在
<sec-rules-that-shouldnt>
四种，各有各的问题：

#strong[一、无法说出失败形态的。] 它是品味（#ref(<sec-testability-judge>, supplement: [第])）。

#strong[二、误报率高到需要频繁加豁免的。] 它的边界画错了。#strong[加第三个豁免时就该重新设计]（#ref(<sec-semantic-boundary>, supplement: [第])）。

#strong[三、和另一条规则的意图重叠的。] 两条重叠的规则说明背后那条真正的原则没被找出来 （#ref(<sec-step-conflict>, supplement: [第])）。

#strong[四、只在一个地方适用的。] 如果一条"通用规则"实际上只在一个模块里有意义， 那它应该是那个模块的局部约定，不该占用全局规则集的位置 ------ #strong[因为全局规则集的每一条都在被所有人阅读和维护。]

这一条在实践中是最难判断的，因为规则往往从一个具体的地方开始， 而"它会不会在别处也适用"要跑一段才知道。

#strong[所以合理的做法是：先加，然后在健康检查时问一句 "它到目前为止只在一个地方命中过吗"]（#ref(<sec-rule-health>, supplement: [第])）。

== 这一层和另外两层的成本对比
<sec-layer-cost-compare>
用同一天的实测数据对比三层：

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([层], [中位耗时], [失败率], [每次判定的信息量],),
  table.hline(),
  [结构检查], [#strong[5.2 分钟]], [#strong[7.0%]], [高（规则名 + 位置 + 修法）],
  [单元与集成], [7.8 分钟], [3.9%], [中（断言失败的位置）],
  [界面与端到端], [14.9 分钟], [4.7%], [#strong[低]（一个失败的步骤）],
)
#strong[三列一起看，这一层在所有维度上都占优。]

而"每次判定的信息量"那一列很少被讨论，但它很实际：

一次结构检查失败告诉你：#strong[哪条规则、哪个文件哪一行、 为什么有这条规则、怎么修]。 一次端到端测试失败告诉你：#strong[在第几步挂了]。

#strong[信息量的差别直接转化成迭代轮数的差别]（#ref(<sec-delay-breakdown>, supplement: [第])）。

#strong[所以这一层不只是"更早发现问题"，它还是"发现的问题更好修"。]

== 为什么这一层的失败率最高是件好事
<sec-high-failure-good>
7.0% 是三层里最高的，而这通常会被当成一个负面指标 （"这一层太严了""它老是挡人")。

#strong[恰恰相反。]

因为结构问题的特点是：#strong[它们不产生即时反馈] （#ref(<sec-structure-first>, supplement: [第])）。一条错误的依赖方向、 一个放错位置的文件、一个内联的日志器 ------ #strong[没有任何东西会因此变红]， 除非有一条规则专门看它。

#strong[所以在没有这一层的仓库里，这 7% 不是"没发生"，是"没被发现"。]

它们会持续累积，直到某天有人试图抽出一个模块， 或者试图理解为什么日志格式到处不一样。

#strong[一个高失败率的结构检查层，衡量的不是它有多严， 是它之前漏掉了多少。]

而这个数应该随时间下降 ------ 如果它一直保持在 7%， 说明存在某种持续产生结构问题的机制 （通常是：规则没有被前馈化，见 #ref(<sec-rule-endgame>, supplement: [第])）。

== 从这一层能读出的组织信息
<sec-organizational-signal>
最后一个观察，它超出了技术范围。

#strong[一个团队的结构检查规则集，是这个团队争论过什么的化石记录。]

#ref(<sec-nine-commits>, supplement: [第]) 那九次提交，每一次都对应一次真实的分歧 被固化成了机制。而反过来：

- #strong[规则集很小] → 要么没撞过墙，要么撞了没沉淀
- #strong[规则集很大但没人能说出诞生原因] → 抄来的
- #strong[规则集里有一批零违规的报数规则] → 有人加了但没人负责收尾
- #strong[规则集在缩小] → #strong[有人在做把规则变成结构的工作]

#strong[最后一行是最健康的信号，也是最罕见的]（#ref(<sec-rule-count>, supplement: [第])）。

== ⚙️ 小规模怎么做
<sec-guardrails-small>
这一层的最小可用版本不需要构建系统，也不需要 Rust：

#strong[一个脚本 + 一份 YAML 规则表 + 一条 CI 任务。]

规则表起步只要三个字段：匹配什么、为什么有这条、怎么修。 #strong[第四个字段（哨兵下限）等规则超过五条再加] ------ 在那之前， 你自己就是那个哨兵，你会注意到检查突然不报了。

一条建议：#strong[第一条规则，选你团队在评审里重复说得最多的那句话。] 如果你想不起来是哪一句，说明现在还不该做这一层。

== 检查器自己的判定覆盖
<sec-checker-self-coverage>
这一层检查所有的代码，那#strong[谁检查这一层？]

这套系统的答案分四块，值得完整看，因为 #strong[它是"判定覆盖到哪里，确定性就到哪里"这条原则 应用在自己身上的一个完整案例：]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([覆盖方式], [它守什么],),
  table.hline(),
  [#strong[契约测试]], [schema、glob 匹配、退出码、失败渲染的行为],
  [#strong[故意造违规]], [每条规则确实会在违规时报错（机内自检）],
  [#strong[哨兵下限]], [每条规则的扫描面没有异常缩小],
  [#strong[文件大小硬顶]], [检查器自己的代码不超过 200 行/文件],
  [#strong[CI 的四道门]], [其中一道专门跑策略机制自身的契约],
)
#strong[五层，而它们的成本是真实的] ------ 这就是为什么检查器的代码量里有相当一部分是它自己的测试。

=== 但仍然有一处没被覆盖
<sec-checker-gap>
#strong[规则集的整体健康度没有被检查。]

单条规则的正确性有覆盖（契约测试 + 故意造违规）， 单条规则的存活有覆盖（哨兵）。

#strong[而"这套规则集作为一个整体，是不是还在收敛"没有。]

具体地说，#ref(<sec-rule-health>, supplement: [第]) 那张清单里的七项， #strong[一项都没有被自动化] ------ 规则总数的变化、零违规的报数规则、扫描数的趋势、 台账的总量趋势、绕过率。

#strong[五项的数据全都是现成的]（每次运行的输出里就有）， 缺的只是把它们存成时间序列。

#strong[这是这本书对源系统提出的第五条建议]， 而它和前四条一样：#strong[数据在手边，缺的是把它接进一条判定。]

== 一个关于"检查器该多严"的判断
<sec-how-strict>
最后回答一个必然会被问的问题。

#strong[判据不是"严不严"，是"误报率"。]

一条零误报的规则，无论多严都不会造成问题 ------ 因为它拦下的每一次都是真的。

而一条有误报的规则，无论多松都在消耗信任 （#ref(<sec-feedback-cost>, supplement: [第])）。

#strong[所以正确的问题不是"我们该拦多少"，而是 "我们的每一条规则，误报率是多少"。]

而这个数在这套系统里也没有被测量（#ref(<sec-bypass-rate>, supplement: [第])）------ #strong[它是这一层最大的一处盲区]， 而且它盲的正是"这一层的健康度"这个最重要的量。

== 这一层最容易被建错的地方
<sec-most-common-mistake>
按遇到的顺序，列三个：

=== 第一个：把它当成代码风格工具
<sec-not-style>
#strong[症状]：规则集里大部分是缩进、命名格式、导入顺序。

#strong[问题]：这些东西#strong[格式化工具已经解决了]，而且是零人工的。 把它们放进这一层，等于用一个贵的机制解决一个便宜的问题， #strong[同时稀释了这一层真正该管的东西。]

#strong[这一层该管的是结构]：依赖方向、owner 边界、 某个 API 不该出现在哪里 ------ #strong[那些格式化工具管不了的。]

=== 第二个：规则没有分档
<sec-no-tiers>
#strong[症状]：所有规则一上来就拦人。

#strong[后果]：#ref(<sec-four-steps>, supplement: [第]) 讲过 ------ 所有人当场停摆， 然后规则被关掉，然后"关掉规则"成了一个先例。

=== 第三个：本地和 CI 跑的不是一回事
<sec-not-same-command>
#strong[症状]：有人说"本地是好的"。

#strong[这个症状一旦出现，这一层的权威就开始漏气] ------ 而权威一旦漏气，它拦下的每一次都会被质疑。

#strong[修法]：让两边跑同一条命令、同一份配置 （#ref(<sec-policy-mechanism>, supplement: [第])）。这通常意味着把检查 从 CI 配置里挪进一个可以本地执行的脚本， #strong[而 CI 只是调用它。]

#strong[三个错误的共同点]：它们都不会立刻造成明显的后果， 而它们会在几个月内让这一层失去作用。

== 一个关于规则数量的参照
<sec-rule-count-reference>
给一个粗略的参照，帮读者判断自己的规模：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([仓库规模], [合理的架构规则数],),
  table.hline(),
  [单产品，十万行以内], [#strong[3--8 条]],
  [多模块，百万行], [10--20 条],
  [这套系统（310 万行，26 产品）], [#strong[23 条]],
)
#strong[注意增长是次线性的。]

代码量翻了三十倍，规则只翻了三倍多 ------ 因为#strong[规则守的是"结构的种类"，不是"代码的数量"。]

一个仓库里有多少种结构性的约定， 和它有多少行代码关系不大。

#strong[而这个观察给出一个诊断]：如果你的规则数 随代码量线性增长，说明其中有一批规则是产品域特定的 （"这个模块不许调那个 API"）， #strong[而那些应该是局部约定，不该占用全局规则集的位置] （#ref(<sec-rules-that-shouldnt>, supplement: [第]) 的第四条）。

== 这一章能被压成的三句话
<sec-guardrails-three-lines>
#strong[一、最常拦住人的那一层，恰好也是最便宜的一层。]

而这不是巧合（#ref(<sec-high-failure-good>, supplement: [第])）： 结构问题不产生即时反馈，所以在没有这一层的仓库里， #strong[那 7% 不是"没发生"，是"没被发现"。]

#strong[二、baseline 是单调收敛的债务台账，不是豁免清单。]

而这个区分在实现上是一个多重集加一个事务 （#ref(<sec-monotonic-impl>, supplement: [第])）------ #strong[两个看起来很技术的细节， 守的是"债务只能还不能借"这条唯一重要的性质。]

#strong[三、规则的边界必须拿真实数据调，而哨兵不能被关掉。]

前半句决定它会不会被绕过， 后半句决定它坏了你会不会知道。

== 这一层的一个隐藏收益
<sec-hidden-benefit>
最后说一个通常不被提起的收益。

#strong[这一层的规则集，是一份关于"这个仓库在乎什么"的可执行文档。]

一个新来的人（或一个新的 Agent）想知道 "这个团队的架构原则是什么"，最可靠的信息源 不是架构文档 ------ #strong[是那份规则表。]

因为文档可能过时、可能没人读、可能和实际做法不一致， #strong[而规则每天都在跑。]

#strong[这意味着规则表有一个文档永远没有的性质： 它不可能和现实脱节。]（如果它脱节了， 它会开始误报，然后被修 ------ 而这个反馈回路是自动的。）

#strong[所以维护好这份表，某种程度上也是在维护 一份永远准确的架构说明] ------ 而这个收益不体现在任何拦截统计里。

= ARBITER：路径的不变量
<arbiter路径的不变量>
= ARBITER：路径的不变量
<sec-arbiter>
前两层判定作用在#strong[代码]上：测试看行为，结构检查看放置。

这一层作用在#strong[路径]上，而且它是五种载体里唯一一种#strong[零主动动作]的 （见 #ref(<sec-path-triggered>, supplement: [第])）------ 改到哪个路径，那个路径的背景自己浮上来。

== 为什么不是代码归属表
<sec-not-codeowners>
代码归属表做的事情是把路径路由给一个人。

这个机制在人写代码、人审代码的年代很好用，但它建立在三个前提上， 而当审查的一方变成 Agent、而且是几十个并行的 Agent 时，#strong[这三个前提全塌了。]

=== 前提一：审查者是人
<sec-premise-human>
人会累、会不在、会在疲惫时快速点通过 ------ 这些都是老问题， 而且它们有已知的缓解办法。

#strong[真正变了的是另一边。]

Agent 不会主动去查"这条路径有什么讲究"。它只会照着看起来合理的方式 一直改下去，直到有人告诉它不行。

这不是它的缺陷，这是它的工作方式：它从上下文里能读到的东西出发， 生成一个符合上下文的方案。#strong[一条没有出现在上下文里的约定， 对它来说就是不存在的。]

=== 前提二：路由到人就够了
<sec-premise-routing>
#strong[但 owner 脑子里的那条不变量从来没被写下来过。]

他离开、换组，或者这一次没被叫到评审，规则就跟着一起消失了。

这个问题在人的团队里也存在，只是被"传帮带"缓解了 ------ 新人跟着老人做几次，那些没写下来的东西就传下去了。

#strong[而 Agent 没有传帮带。] 每一个会话都是第一天。

=== 前提三：审查发生在写完之后
<sec-premise-after>
等 diff 出来才发现踩了红线，一整轮工作已经浪费掉了。

#strong[Agent 需要的恰恰相反 ------ 它需要在动手之前就知道这里有什么。]

而这一条在 Agent 场景下的成本被并行度乘上了：一轮返工在人的团队里 是一个人半天，在几十个 Agent 并行的场景下是几十次同样的返工， 因为每一个 Agent 都会独立地踩同一个坑。

=== 于是换了一个问题问
<sec-different-question>
不再问"这条路径归谁审"，改成问：

#quote(block: true)[
#strong[这条路径必须保持什么。]
]

不变量一旦写进仓库，就不再依赖任何人在场； 路径一命中它就自己浮出来，也就不再依赖谁记得去查。

配套文档的第一句写得很直白：

#quote(block: true)[
这些文件不是人的归属记录。 #strong[它们是给 Agent 工作流用的、机器可读的不变量清单。]
]

两者的差别可以列成一张表：

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([], [代码归属表], [路径不变量清单],),
  table.hline(),
  [回答], [这条路径归谁审], [#strong[这条路径必须守住什么]],
  [消费者], [评审的人], [#strong[Agent，动手前与动手后各一次]],
  [内容], [路径 → 人], [路径 → 风险 · 不变量 · 先读什么 · 禁止什么 · 跑什么],
  [时机], [diff 出来之后], [#strong[命中路径的那一刻]],
  [失效于], [人不在 · 疲劳 · 没上下文], [只失效于策略读不出来（那会报基建故障）],
)
（二十份清单的全量表在 #ref(<sec-appendix-arbiters>, supplement: [附录])，按风险等级排。）

== 六个字段各回答一个问题
<sec-arbiter-fields>
#Skylighting(([#DataTypeTok("id");#NormalTok("   ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"migration-data-destruction\"");],
[#DataTypeTok("risk");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"critical\"");],
[#DataTypeTok("paths");#NormalTok("  ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("[");#StringTok("\"Backends/**/migrations/**/*.up.sql\"");#OperatorTok(",");#NormalTok(" ");#ErrorTok("...");#OperatorTok("]");],
[#DataTypeTok("invariant");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#StringTok("\"迁移只演进 schema，绝不整表清空或删分区。……\"");],
[#DataTypeTok("read");#NormalTok("   ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("[");#StringTok("\"…#Backend Data Integrity\"");#OperatorTok(",");#NormalTok(" ");#StringTok("\"…/migrate.go\"");#OperatorTok("]");],
[#DataTypeTok("forbid");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("[");#StringTok("\"truncate *\"");#OperatorTok(",");#NormalTok(" ");#StringTok("\"*drop partition*\"");#OperatorTok(",");#NormalTok(" ");#StringTok("\"*delete where*\"");#OperatorTok(",");#NormalTok(" ");#StringTok("\"*on cluster*\"");#OperatorTok("]");],
[#DataTypeTok("checks");#NormalTok(" ");#OperatorTok("=");#NormalTok(" ");#OperatorTok("[");#StringTok("\"guard:go\"");#OperatorTok("]");],));
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([字段], [回答],),
  table.hline(),
  [#NormalTok("paths");], [哪些路径会触发它],
  [#NormalTok("risk");], [风险有多高],
  [#NormalTok("invariant");], [必须保持什么],
  [#NormalTok("read");], [动手之前应该先读什么],
  [#NormalTok("forbid");], [新增哪些内容不被允许],
  [#NormalTok("checks");], [完成之后要跑什么],
)
#strong[注意 #NormalTok("invariant"); 是给人和 Agent 读的自然语言，#NormalTok("forbid"); 才是机器执行的部分。]

这个分工是刻意的，而且它有一个重要推论：

#quote(block: true)[
#NormalTok("invariant"); 里可以写#strong[所有危险的动作]， #NormalTok("forbid"); 里只能写#strong[不该发生的动作]。
]

混淆这两者，规则就会开始误报。而误报的规则会被绕过 ------ 这是本书反复出现的那条链，#ref(<sec-forbid-tuning>, supplement: [第]) 会给出它的完整证据。

== 实现只有七百行，但每一处都在解决一个具体问题
<sec-arbiter-impl>
引擎本身很小 ------ 七个源文件，七百多行。值得逐个看它们在解决什么。

=== 只匹配新增行，而且是字面意义上的
<sec-added-only>
取证这一步用的 git 命令是：

#Skylighting(([#NormalTok("git diff --unified=0 <revision-range>");],));
#strong[#NormalTok("--unified=0"); 表示零行上下文。]

所以提取出来的新增文本里#strong[只有新增的行，一行上下文都没有]。

这不是一个优化，这是一条语义保证：#strong[禁止模式永远不会命中 一段你没有改过的代码。]

如果留了上下文行，会发生一件很坏的事：你在一个包含 #NormalTok("ALTER TABLE ... DELETE WHERE"); 的迁移文件里改了一行注释， 而那条禁止模式命中了上下文里的原有语句 ------ #strong[你会因为别人半年前写的代码 而被拦下来]，而且你完全不知道为什么。

一条会因为你没做的事而拦住你的规则，是最快被绕过的那一种。

同一个函数还合并了已暂存和未暂存的改动 ------ #strong[所以它对还没提交的工作也生效]，Agent 不需要先 commit 才能知道自己踩了什么。

=== 规则不扫自己
<sec-policy-path-excluded>
匹配模块里有一个三行的函数：

#Skylighting(([#KeywordTok("pub");#NormalTok(" ");#KeywordTok("fn");#NormalTok(" is_policy_path(path");#OperatorTok(":");#NormalTok(" ");#OperatorTok("&");#DataTypeTok("str");#NormalTok(") ");#OperatorTok("->");#NormalTok(" ");#DataTypeTok("bool");#NormalTok(" ");#OperatorTok("{");],
[#NormalTok("    path");#OperatorTok(".");#NormalTok("starts_with(");#StringTok("\"guardrails/arbiters/\"");#NormalTok(")");],
[#OperatorTok("}");],));
而路径匹配时它是这么用的：

#Skylighting(([#NormalTok("paths");#OperatorTok(".");#NormalTok("iter()");],
[#NormalTok("     ");#OperatorTok(".");#NormalTok("filter(");#OperatorTok("|");#NormalTok("path");#OperatorTok("|");#NormalTok(" ");#OperatorTok("!");#NormalTok("is_policy_path(path))");],
[#NormalTok("     ");#OperatorTok(".");#NormalTok("any(");#OperatorTok("|");#NormalTok("path");#OperatorTok("|");#NormalTok(" arbiter");#OperatorTok(".");#NormalTok("matches_path(path))");],));
#strong[编辑策略文件本身，不会触发策略。]

这解决的是"规则咬到自己"这一类问题里最基础的那个： 当你在一份清单里#strong[写下]一条禁止模式时，那行文本本身就是这个模式的一个实例。 没有这三行，任何人添加或修改一条规则都会被自己拦住。

这一类问题在这套系统里出现过好几次，形态各不相同：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([形态], [处理],),
  table.hline(),
  [规则文件里写下的模式命中自己], [上面这三行],
  [解释规则的散文命中规则], [某份清单把文档目录排除在路径之外],
  [讲解规则的注释命中规则], [结构检查那边的"只看代码不看注释"开关],
  [#strong[清单文件名让它对版本控制隐形]], [见下],
)
最后一个是最阴的。某份清单的注释里记着：#strong[这份清单的 id 不能以某个前缀开头。]

因为忽略文件里有一条未锚定的通配规则，一旦文件名以它开头， #strong[这份策略文件对版本控制就直接隐形了] ------ 规则还在文件里写着， 在本地跑也正常，但它根本没被提交，所以 CI 上不存在。

这是形状 D 的极端形态：不只是"配置没生效"，而是 #strong["配置根本不存在，但你在本地看得见它"。]

=== 需要跑的检查是算出来的，不是列出来的
<sec-minimal-checks>
命中多条清单时，需要重跑的检查集合是这么算的：

#Skylighting(([#NormalTok("affected");#OperatorTok(".");#NormalTok("arbiters");#OperatorTok(".");#NormalTok("iter()");],
[#NormalTok("    ");#OperatorTok(".");#NormalTok("flat_map(");#OperatorTok("|");#NormalTok("arbiter");#OperatorTok("|");#NormalTok(" arbiter");#OperatorTok(".");#NormalTok("checks");#OperatorTok(".");#NormalTok("iter()");#OperatorTok(".");#NormalTok("copied())");],
[#NormalTok("    ");#OperatorTok(".");#PreprocessorTok("collect::");#OperatorTok("<");#NormalTok("BTreeSet");#OperatorTok("<");#NormalTok("CheckAlias");#OperatorTok(">>");#NormalTok("()");],));
收进一个有序集合 ------ #strong[自动去重，而且顺序确定。]

如果三份清单都要求跑同一个语言的检查，它只跑一次。

这个细节很小，但它体现了一条一致的态度：#strong[返回给 Agent 的 应该是"你需要重跑的最小集合"，而不是"所有相关的检查"。]

一个返回了冗余工作的判定，会让 Agent 在正确的路上多花时间， 而多花的时间会变成更多的返工机会。

== forbid 是拿真实数据调出来的
<sec-forbid-tuning>
这是全书最能说明"规则不是拍脑袋写的"的一节。

那份数据销毁清单的注释里，完整记着当初的调参过程。逐条读：

=== 为什么不禁掉表
<sec-no-drop-table>
#quote(block: true)[
翻了一遍仓库，26 个迁移文件里有 #strong[69 处是完全合法的表退役]。
]

禁了它，规则会在正确的工作上不停误报。而接下来发生的事情是可以预见的：

#quote(block: true)[
#strong[它会被绕过去，然后整条规则就废了。]
]

这一句是整节的核心。它不是在说"我们很宽容"， 而是在说#strong[一条规则的有效性取决于它的误报率]， 而误报率高到某个程度之后，规则的实际效力是零 ------ 甚至是负的， 因为它还在消耗每个人绕过它的时间。

=== 为什么清空语句写了两种拼法
<sec-two-spellings>
#quote(block: true)[
这个语句在实际文件里要么顶格出现、要么带缩进。
]

而两种写法#strong[都要求词边界]，所以它不会命中某个文件注释里的英文单词 ------ 那个词尾部多了一个 s，恰好破坏了尾随空格的匹配。

#strong[这一条说明作者真的一行一行看过那 26 个迁移文件。] 它不是从别处抄来的规则，它是被这个仓库的实际内容塑造出来的。

=== 为什么用相邻两词而不是完整语法
<sec-adjacent-words>
删除语句用的是两个相邻的词，而不是某种数据库的完整语法。

#quote(block: true)[
前者打的是某个分析型数据库的变更删除语法，两个词是相邻的； 而另一种数据库的写法中间隔着表名，不会匹配上 ------ #strong[这是刻意的，因为有五个迁移正是靠它在收紧约束之前清理孤儿数据。]
]

同一个英文单词，在两种数据库里是两个不同风险等级的操作。 规则精确地区分了它们，而区分的方式是利用了两种语法在#strong[词序]上的差别。

=== 为什么保留期删除是故意不禁的
<sec-ttl-allowed>
#quote(block: true)[
23 个 schema 声明了它，#strong[它就是这里既定的数据保留机制]，不是异常。 当然，改它一样会删掉生产数据 ------ 但那个风险交给不变量文本和人的评审去承担，#strong[不由这个列表承担。]
]

最后半句是整章最该记住的一句：

#quote(block: true)[
#strong[规则要守住的是"不该发生的动作"，不是"所有危险的动作"。]
]

一条试图覆盖所有危险动作的规则，必然会覆盖到大量正当的工作， 然后它会被绕过，然后它连它本来能守住的那部分也守不住了。

== 一个反直觉的规律：超过一半在回答"归谁写"
<sec-ownership-pattern>
把二十份清单放在一起看，会发现一个当初没预料到的现象：

#strong[其中七份的 id 里直接带着"归属"这个词]，另外还有两份的不变量文本里 写着"只有一个 owner"。

也就是说，#strong[超过一半的路径不变量，本质上都在回答同一个问题： 这块状态归谁写。]

这跟代码归属表形成了一个很有意思的对照：

#quote(block: true)[
归属表问的是#strong[审查权]，路径清单问的是#strong[写入权] ------ #strong[而后者才是能被机器验证的那一个。]
]

"这段代码该由谁来看"是一个社会事实，机器验证不了。 "这块状态只能由这一个地方写"是一个结构事实，机器一查依赖图就知道。

这也是形状 B 在这一层的确认：#strong[单一 writer 是这套系统里 反复出现次数最多的一条原则]，多到它已经不像一条原则， 更像是这个系统看待问题的默认角度。

== 风险等级的分布
<sec-risk-distribution>
清单按风险分级，而#strong[四条最高等级守的都是不可逆的东西]：

- 数据被删掉
- 外键约束了删除语义
- 发布产生了外部副作用
- 消费位点越过了尚未处理的记录

它们的共同点是#strong[出错之后重试也回不来。]

而这一点和 Agent 的行为模式直接冲突：

#quote(block: true)[
#strong["重试一次"恰恰是 Agent 遇到问题时最自然的反应。]
]

一个 Agent 看到某个操作失败了，它的第一反应是再试一次 ------ 这个反应在 99% 的情况下是对的，正是这 99% 让它成为了默认反应。

而这四条守的就是那 1%：#strong[在这些路径上，重试不是无害的。]

== 一次真实的拦截
<sec-real-interception>
#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([步骤], [内容],),
  table.hline(),
  [① 命中路径], [迁移文件路径，最高风险，先读数据完整性那一节],
  [② 新增行证据], [#NormalTok("+ ALTER TABLE events DROP PARTITION 2026_07;"); 命中删分区模式],
  [③ 判定], [内容违规 ------ 分区删除不可逆，重试恢复不了记录],
  [④ 修正对象], [回到迁移设计与 owner，保留可回滚语义，重跑指定的检查],
)
#strong[这个例子的重点不是拦下了一行 SQL。]

重点是这次失败#strong[带着风险等级、具体证据和下一步动作一起返回了] ------ Agent 拿到的不是一句"不允许"，而是一整套上下文。

它不需要重新猜这条路径有什么讲究，也就#strong[不会换个写法绕过去再试一次。]

用第四部的语言说（#ref(<sec-sensor-faults>, supplement: [章节])）：一个只返回"失败"的判定， 只提供了误差的#strong[符号]；一个返回了 owner、证据和最小重跑集合的判定， 提供了误差的#strong[方向和大小]。#strong[只有后者能让搜索空间收缩。]

== 为什么"动手前读什么"这个字段值钱
<sec-read-field>
六个字段里，最容易被当成可有可无的是 #NormalTok("read"); ------ 它既不拦人， 也不产生判定，只是列了几个链接。

但它解决的是一个别的字段都解决不了的问题：

#quote(block: true)[
#strong[禁止模式告诉 Agent 什么不能做，#NormalTok("read"); 告诉它这条路径为什么特殊。]
]

这两者的差别在#strong[泛化能力]上。

一个只知道"不能写删分区语句"的 Agent，会去找别的删数据的写法 ------ 不是因为它想绕过，而是因为它不知道这条规则守的是什么。 它以为问题出在那个语句上。

而一个读过"这条路径上，删掉的行没有任何回滚能还原"的 Agent， 面对一种规则没有列举的新写法时，能自己判断。

#strong[这是 #ref(<sec-incident-hint>, supplement: [第]) 那条纪律在路径这一层的形态： 把"为什么"和"是什么"一起给出去。]

而 #NormalTok("read"); 相比 #NormalTok("incident"); 又多了一层：#strong[它指向的是仓库里的真实文件]， 不是一段描述。Agent 读的是那个迁移执行器的源码， 而不是关于它的一段总结 ------ 这消除了一次转译， 而转译正是规模化时第一个断掉的环节（#ref(<sec-designs>, supplement: [第])）。

== 二十份清单是怎么攒到二十份的
<sec-twenty-arbiters>
不是一次设计出来的。从版本历史看：

- 整个机制诞生于一次提交（"加入路径不变量闸门"）
- 十一天后扩到 8 条
- 然后一条一条加，加到二十条

#strong[而每一条都对应一次具体的事故或一次具体的越界。]

这个增长模式和规则那边一样（#ref(<sec-nine-commits>, supplement: [第])）， 它揭示了一个可以直接抄走的做法：

#quote(block: true)[
#strong[不要一次设计一套清单。设计一个机制，然后让清单自己长出来。]
]

机制的部分（路径匹配、只扫新增行、最小重跑集合、 排除策略文件自身）是一次性的工程投入。 而清单的部分是持续的、跟着事故走的。

#strong[两者的成本结构完全不同]：机制的成本在前期，清单的成本摊在几年里。 而大部分团队搞反了 ------ 他们花很多时间讨论"该有哪些规则"， 却用一个临时的机制去承载它们。

== 一个关于风险等级的观察
<sec-risk-observation>
二十份清单里，最高等级只有四份。

#strong[这个比例是刻意的]，而且它有一个实际后果： #strong[当 Agent 看到"最高等级"这个标记时，它是有信息量的。]

如果二十份里有十五份标着最高等级，那这个标记就退化成了装饰 ------ 和 #ref(<sec-no-speculative-layers>, supplement: [第]) 讲的空目录稀释信息量是同一个机制。

#strong[风险等级的价值来自它的稀缺性。]

而判断一份清单该不该标最高等级，有一个很干净的判据： #strong[出错之后重试能不能挽回？]

- 能挽回 → 高，不是最高
- 不能挽回 → 最高

这个判据不涉及"这件事有多重要"这种主观判断， 它只问一个事实问题。而正因为它是事实问题， #strong[它在不同的人之间能得到一致的答案]。

== 这一层和另外两层的分工
<sec-three-layers-division>
三层判定容易被看成"三道关卡"，但它们回答的是三个不同的问题， 而且#strong[它们的失效方式也不同]：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([层], [问什么], [它测不到什么],),
  table.hline(),
  [测试], [跑起来发生了什么], [没被跑到的路径、跑了但没断言的行为],
  [结构检查], [代码放得对吗], [放对了但做错了的事],
  [路径不变量], [这条路径的约定守住了吗], [不在任何清单覆盖的路径上的问题],
)
#strong[三层的覆盖面互不包含]，这是它们必须同时存在的理由。

一个具体的例子：一次删除生产数据的迁移。

- #strong[测试]测不到 ------ 迁移文件不会被单元测试执行
- #strong[结构检查]测不到 ------ 这个文件放在正确的目录里，格式也对
- #strong[路径不变量]测得到 ------ 因为它匹配的是路径 + 新增行

反过来，一次并发竞态：

- #strong[测试]可能测得到（如果有并发测试且断言正确）
- #strong[结构检查]测不到
- #strong[路径不变量]测不到

#strong[没有哪一层是"更根本"的。] 它们是三个正交的投影， 每一个都有它看不见的维度。

== 为什么这一层的实现只有七百行
<sec-why-so-small>
对比一下：结构检查那一层有六万七千行，路径不变量这一层只有七百行 ------ #strong[差了将近一百倍。]

原因不是这一层不重要，是#strong[它把大部分工作交给了别人]：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([它自己做的], [交给别人的],),
  table.hline(),
  [从版本控制取新增行], [---------],
  [路径通配匹配], [通配库],
  [禁止模式的字面匹配], [---------],
  [算出最小重跑集合], [---------],
  [渲染报告], [---------],
  [---------], [#strong[真正的语义检查（交给 #NormalTok("checks"); 字段指定的通道）]],
)
#strong[最后一行是关键。]

一份清单的 #NormalTok("checks"); 字段声明"完成之后要跑什么"， 而那些检查是别的层实现的。#strong[这一层只负责路由，不负责判定内容。]

这个划分让它保持了小，而小带来两个好处：

#strong[一、它可以被完整读懂。] 七百行，一个人一小时能读完全部。 而一个能被完整读懂的机制，它的边界和局限也是清楚的。

#strong[二、它很少需要改。] 加一份新清单不需要改这七百行 ------ 清单是数据，机制是代码。#ref(<sec-twenty-arbiters>, supplement: [第]) 讲过这个成本结构： #strong[机制的成本在前期，清单的成本摊在几年里。]

这是策略与机制分离（#ref(<sec-policy-mechanism>, supplement: [第])）在这一层的形态， 而它的效果可以量化：#strong[二十份清单，零行新代码。]

== 不变量文本该怎么写
<sec-writing-invariants>
#NormalTok("forbid"); 是机器读的，#NormalTok("invariant"); 是人和 Agent 读的。 而后者的写法决定了这份清单的实际效力。

对比同一条不变量的三种写法：

#strong[写法一（最常见）：] \> 迁移不能删除数据。

#strong[写法二（好一些）：] \> 迁移只能演进 schema，不能删除数据。删除的行无法恢复。

#strong[写法三（那份清单里实际的）：] \> 迁移只演进 schema，从不整表清空或删分区，也从不扩大自己的影响半径。 \> #strong[删除一张退役的表是可接受的 schema 演进，而且必须配一份能工作的回滚脚本]， \> 但清空、删库、变更删除和删分区#strong[销毁的是活数据，没有任何回滚能还原]， \> 而集群广播会把语句扩散到迁移执行器指向的那个节点之外。

#strong[写法三比写法一多了四样东西：]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([多的部分], [作用],),
  table.hline(),
  ["删除一张退役的表是可接受的"], [#strong[明确了什么是允许的]],
  ["必须配一份能工作的回滚脚本"], [给出了允许的条件],
  ["没有任何回滚能还原"], [解释了为什么不可接受],
  ["扩散到执行器指向的节点之外"], [解释了第四种禁止的机制],
)
#strong[第一行最重要，而它最常被漏掉。]

一条只说"不能做什么"的不变量，会让 Agent（和人）过度保守 ------ 它会连合法的表退役也不敢做，然后来问，然后你花时间回答， 然后下一个 Agent 再问一遍。

#strong[明确说出什么是允许的，成本是一句话，收益是省掉所有那些询问。]

这和 #ref(<sec-freedom-inside>, supplement: [第]) 是同一条：#strong[边界越明确， 可探索的空间越大。]

== 一份清单值多少
<sec-arbiter-value>
诚实地算一次。

#strong[成本]：写一份清单大概一到两小时（如果你已经知道那条不变量的话）。 维护成本接近零 ------ 它是数据，不是代码。

#strong[收益]：取决于两个数的乘积。

#Skylighting(([#NormalTok("收益 ≈ 这条路径被改动的频率 × 每次踩坑的代价");],));
而这两个数在不同路径上差几个数量级：

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([路径], [改动频率], [每次代价], [值不值],),
  table.hline(),
  [数据迁移], [低], [#strong[极高（不可逆）]], [#strong[值]],
  [发布配置], [低], [#strong[极高]], [#strong[值]],
  [核心业务逻辑], [高], [中（能改回来）], [一般],
  [界面样式], [高], [低], [不值],
)
#strong[注意前两行：它们的改动频率都很低。]

这是反直觉的：#strong[最值得写清单的路径，恰恰是最少被改的那些。]

因为清单的价值来自"每次踩坑的代价"，而不是"多久踩一次"。 一条一年只被改两次的迁移路径，两次里只要有一次被拦住， 这份清单就回本了 ------ 而它的成本是两小时。

#strong[这个算法也解释了为什么二十份清单是够的]： 不可逆的路径本来就不多。

== 路径不变量和代码归属表可以共存吗
<sec-coexist>
可以，而且在有人类评审的团队里应该共存 ------ #strong[因为它们回答的是两个不同的问题]（#ref(<sec-not-codeowners>, supplement: [第])）。

但共存有一个前提：#strong[不要用归属表去承载不变量。]

常见的错误做法是在归属表的注释里写"改这个目录要小心 X"。 这个做法的问题是：

- 那段注释#strong[只有配置这个文件的人会看]
- 它不会在 Agent 改到那个路径时出现
- 它没有可执行的部分

#strong[正确的分工是]：归属表管"通知谁"，路径清单管"必须保持什么"。 两者的路径可以重叠，因为它们服务不同的消费者。

== 这一层能不能被完全自动化
<sec-full-automation>
诚实的回答：#strong[不能，而且不该。]

因为 #NormalTok("invariant"); 字段的本质是#strong[一段需要被理解的自然语言]， 而它之所以是自然语言，不是因为技术不够， 是因为#strong[它要表达的东西本身没有形式化的形态。]

"删掉的行没有任何回滚能还原"------ 这句话可以被机器读，但它不能被机器#strong[执行]。 执行它的是那七条禁止模式，而那七条只是这句话的一个#strong[近似]。

#strong[而这个近似永远是不完备的]（#ref(<sec-ttl-allowed>, supplement: [第]) 里那个 "改保留期一样会删数据，但那个风险不由这个列表承担"）。

所以这一层的正确形态是：

#Skylighting(([#NormalTok("自然语言的不变量（完整，不可执行）");],
[#NormalTok("      ↓ 近似");],
[#NormalTok("可执行的禁止模式（不完整，可执行）");],
[#NormalTok("      ↓ 兜底");],
[#NormalTok("人的评审（覆盖两者之间的缝隙）");],));
#strong[三层缺一不可]，而且第三层永远存在 ------ 这正是 #ref(<sec-what-humans-do>, supplement: [第]) 那句"审的东西变了，不是不审了"的具体形态。

== 一个实用的写作顺序
<sec-writing-order>
写一份清单时，按这个顺序，因为#strong[后面的字段依赖前面的]：

#strong[第一步：写 #NormalTok("invariant");。] 用完整的自然语言， 包括允许什么、禁止什么、为什么。#strong[不要考虑能不能执行。]

#strong[第二步：写 #NormalTok("read");。] 这条不变量的完整背景在哪几个文件里？

#strong[第三步：写 #NormalTok("paths");。] 哪些文件的改动可能违反它？ #strong[注意这一步可能会让你回去改第一步] ------ 如果你发现路径范围大得离谱，说明不变量写得太宽了。

#strong[第四步：写 #NormalTok("checks");。] 完成之后跑什么能验证它？

#strong[第五步（可选，最后）：写 #NormalTok("forbid");。] 翻真实的代码，找出那些"绝对不该出现"的新增， #strong[并验证它们在现有代码里的命中数是零]（#ref(<sec-forbid-tuning>, supplement: [第])）。

#strong[如果这一步做不出一个零基线的模式列表，就留空。] 留空是一个合法的选择，而且它比一个会误报的列表好得多。

== 这一层为什么必须"动手前"和"动手后"各一次
<sec-twice>
配套文档里那句"Agent，动手前与动手后各一次"值得展开， 因为#strong[两次的作用完全不同]。

=== 动手前：提供背景
<sec-before-acting>
Agent 准备改某个文件 → 查一下这个路径命中了哪些清单 → 读它们的 #NormalTok("invariant"); 和 #NormalTok("read");。

#strong[这一次的作用是前馈]（#ref(<sec-feedforward-levels>, supplement: [第]) 的第一层）： 它降低了做错的概率，但不产生判定。

而它的价值取决于一件事：#strong[Agent 会不会真的去查？]

这套系统的做法是把它写进常驻文件 ------ "改完代码、最终报告之前，跑一下路径不变量检查"。 #strong[注意这是一条无条件的规则，所以它必须常驻] （#ref(<sec-unconditional-stays>, supplement: [第])）。

=== 动手后：产生判定
<sec-after-acting>
改完之后再跑一次，这一次扫的是#strong[实际的新增行] （#ref(<sec-added-only>, supplement: [第])），产生一个真正的判定。

#strong[这一次是反馈]，而且它是 fail closed 的 ------ 不通过就不能报告完成。

=== 为什么不能只留一次
<sec-why-both>
#strong[只留动手前]：Agent 读了背景，然后仍然可能违反 ------ 因为读到不等于遵守（#ref(<sec-rule-to-effect>, supplement: [第]) 那四步）。

#strong[只留动手后]：Agent 会先写错，再被拦，再返工。 一整轮工作被浪费掉，而这正是代码归属表的第三个失效前提 （#ref(<sec-premise-after>, supplement: [第])）。

#strong[两次合起来才完整]：前一次降低概率，后一次兜住漏网的。

#strong[而这正是前馈加反馈的标准结构] ------ 只不过这里两者用的是同一份数据， 只是在两个不同的时刻被消费。

== 一个实现细节：为什么本地和 CI 都要跑
<sec-local-and-ci>
同一条检查在两个地方跑，看起来是冗余的。它不是。

#strong[本地那次]是给 Agent 的即时反馈，回路延迟以秒计。 #strong[CI 那次]是最终的判定，它的作用是#strong[防止本地那次被跳过]。

而这个设计有一个前提，#ref(<sec-policy-mechanism>, supplement: [第]) 强调过： #strong[两边必须跑同一条命令、同一份策略。]

否则会出现最坏的情况：#strong[本地过了，CI 没过， 而 Agent 认为是 CI 有问题] ------ 于是它开始不信任 CI 的结论， 而这个不信任会扩散到所有的判定上（#ref(<sec-promise-trust>, supplement: [第])）。

#strong[冗余的价值来自一致；不一致的冗余是负资产。]

== 二十份清单的一个盲区
<sec-arbiter-blindspot>
#ref(<sec-coverage-audit>, supplement: [第]) 列了它没覆盖的领域。这里补一个更本质的盲区：

#strong[这一层只看"新增的行"，所以它看不见"删掉的行"。]

#NormalTok("--unified=0"); 提取的是新增文本（#ref(<sec-added-only>, supplement: [第])）， 而一次改动如果是#strong[删掉]了某个东西 ------ 删掉一个权限校验、 删掉一条断言、删掉一个必要的清理步骤 ------ #strong[这一层完全看不到。]

这不是实现的疏忽，是一个刻意的取舍：

- 扫新增行：#strong[误报率低]（你只对你写的东西负责）
- 扫删除行：#strong[误报率高]（大量合法的删除，比如重构、清理死代码）

#strong[而误报的规则会被绕过]（#ref(<sec-bypass>, supplement: [第])），所以这个取舍是对的。

#strong[但盲区仍然存在，而且它必须被知道。]

那么"删掉了不该删的东西"由谁守？三个地方：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([守卫], [它能守住什么],),
  table.hline(),
  [测试], [删掉的东西如果有行为，测试会红],
  [结构检查], [删掉一个必需的目标，依赖图会断],
  [#strong[人的评审]], [剩下的],
)
#strong[第三行是不可避免的]，而这也是 #ref(<sec-full-automation>, supplement: [第]) 那句"不能，而且不该"的一个具体实例。

== 从这一层能学到的一条通用设计
<sec-general-lesson>
这一层的整个设计可以被抽象成一句话， 而这句话适用于任何"给自动化系统加约束"的场景：

#quote(block: true)[
#strong[把"必须保持什么"和"禁止什么"分开写， 前者给人和 Agent 读，后者给机器执行， 并且承认后者永远是前者的一个不完备近似。]
]

三个部分，每一个都对应一个常见的失败：

#strong[只写"禁止什么"] → Agent 换个写法绕过去， 因为它不知道守的是什么（#ref(<sec-read-field>, supplement: [第])）。

#strong[只写"必须保持什么"] → 没有机器执行的部分， 全靠自觉，而自觉在几十个并行的 Agent 面前不成立。

#strong[不承认近似是不完备的] → 会试图用禁止模式覆盖所有危险动作， 然后误报，然后被绕过（#ref(<sec-ttl-allowed>, supplement: [第])）。

#strong[这三个失败，在任何一个"用规则约束自动化"的系统里都会出现] ------ 代码检查、数据质量、权限策略、内容审核。

而这一层给出的答案，是一个可以直接迁移的结构。

== ⚙️ 小规模怎么做
<sec-arbiter-small>
这一层的最小版本#strong[不需要任何工具支持]：

#strong[一个 Markdown 文件，三条路径，每条四个字段。]

选哪三条？按"出错之后能不能重试挽回"来选。绝大多数团队的答案是：

+ 数据迁移
+ 发布 / 部署
+ 认证与权限

四个字段：路径、必须保持什么、动手前读什么、完成后跑什么。 #strong[先不要写禁止模式] ------ 那是需要拿真实数据调的，而你现在还没有数据。

#strong[一条 CI 检查：如果本次改动触到了这些路径，就把对应的段落打印出来。]

#strong[打印，不拦。] 拦是后面的事，见 #ref(<sec-four-steps>, supplement: [第])。

== 这一层和"人还要审什么"的关系
<sec-arbiter-human-review>
#ref(<sec-what-humans-do>, supplement: [第]) 列了四类人还要审的东西， 而这一层和其中一类有直接关系：

#quote(block: true)[
#strong[一个不可逆的动作是否真的应该发生。]
]

这一层不能替人做这个判断（#ref(<sec-full-automation>, supplement: [第])）， #strong[但它改变了这个判断发生的方式。]

#strong[没有这一层时]：这个判断发生在评审里 ------ 如果那次评审有人、如果那个人注意到了、 如果他知道这条路径的讲究。#strong[三个"如果"。]

#strong[有这一层时]：改动被拦下，带着风险等级、 具体证据和这条路径的完整背景返回。 #strong[判断仍然由人做，但它被强制发生了。]

#strong[这个区别可以被精确表述]：

#quote(block: true)[
这一层不保证判断是对的， #strong[它保证判断没有被跳过。]
]

而 #ref(<sec-setpoint-consequences>, supplement: [第]) 那句"大部分不可逆的错误， 不是有人错误地决定要做它，而是根本没有人意识到自己在决定"------ #strong[这一层守的正是这个。]

== 一份清单的生命周期
<sec-arbiter-lifecycle>
和规则一样（#ref(<sec-rule-lifecycle>, supplement: [章节])），清单也会过时。 但它的生命周期短一些，因为它的形态更简单：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([阶段], [触发],),
  table.hline(),
  [诞生], [一次事故，或一次"某人知道但没写下来"的发现],
  [#strong[稳定期]], [路径不变、不变量不变，只是偶尔命中],
  [范围失效], [一次重构改变了路径的形态],
  [退休], [那条不变量被结构性地保证了],
)
#strong[第三行是最需要主动检查的]（#ref(<sec-death-drift>, supplement: [第])）， 而检查方式在 #ref(<sec-failure-scope-drift>, supplement: [第])： #strong[记录每份清单的命中次数，一份从来不命中的清单需要被查看。]

#strong[而第四行在这二十份里还没有发生过] ------ 因为路径不变量守的大多是"外部世界的不可逆性"， 而那类东西无法被结构性地消除。

#strong[你没法用类型系统保证"删掉的数据能被恢复"。]

#strong[所以这一层的规则集，会比结构检查那一层的更稳定， 也更少退休。] 而这是它的性质，不是它的问题。

== 这一层能被压成的三句话
<sec-arbiter-three-lines>
#strong[一、问题从"归谁审"换成了"必须保持什么"。]

而这个转换的价值在于：#strong[后者不依赖任何人在场] （#ref(<sec-different-question>, supplement: [第])）， 而前者的三个前提在 Agent 场景下全塌了。

#strong[二、不变量给人和 Agent 读，禁止模式给机器执行， 而后者永远是前者的一个不完备近似。]

承认这个不完备，是这一层设计里最重要的一个决定 （#ref(<sec-full-automation>, supplement: [第])）------ 因为不承认它， 就会试图用禁止模式覆盖所有危险动作，然后误报，然后被绕过。

#strong[三、禁止模式必须拿真实数据调出来，零基线。]

#ref(<sec-forbid-tuning>, supplement: [第]) 那四段推理是这本书里 最能说明"规则不是拍脑袋写的"的部分， 而它们的共同结论是：#strong[规则要守住的是"不该发生的动作"， 不是"所有危险的动作"。]

== 这一层最小的可行形态
<sec-arbiter-mvp>
再压一次，压到读者今天下午就能做完：

#Skylighting(([#NormalTok("1. 列出你系统里三个\"做错了重试挽回不了\"的动作");],
[#NormalTok("2. 对每一个，写下：");],
[#NormalTok("   - 改哪些文件可能导致它（路径）");],
[#NormalTok("   - 必须保持什么（一句自然语言，说清什么允许什么不允许）");],
[#NormalTok("   - 动手前该读什么（一到两个链接）");],
[#NormalTok("3. 加一条 CI 检查：命中这些路径就打印对应的段落");],
[#NormalTok("4. 打印，不拦");],));
#strong[四步，两小时。]

#strong[而第 2 步里"说清什么允许"那半句是最容易被漏掉、 也最有价值的]（#ref(<sec-writing-invariants>, supplement: [第])）------ 它省掉的是所有那些"这个能不能做"的询问。

#strong[第 4 步的"不拦"也是刻意的]： 你现在还没有数据来调禁止模式的边界， #strong[而在没有数据的时候拦人，误报几乎是必然的。]

= 规则是怎么长出来的
<规则是怎么长出来的>
= 规则是怎么长出来的
<sec-rule-lifecycle>
前面几章讲的都是规则长成之后的样子。这一章讲它是怎么长出来的。

而这一章的材料有一个别处没有的性质：#strong[它可以从版本历史里直接读出来。] 规则的诞生时间、诞生的原因、以及它从报数到拦人的那一刻， 全都是提交记录里的事实，不是事后的叙述。

== 一条规则的完整时间线
<sec-incident-to-rule>
这是从提交历史里还原的一条真实时间线，四个日期：

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([时间], [发生了什么], [性质],),
  table.hline(),
  [#strong[08-01]], [一次提交修了构建缓存的隔离问题，#strong[顺手把不变量写进常驻文件（+2 行）]], [人读的规则],
  [#strong[08-02]], [新平台上第一条真实流水线，三个任务在分析阶段同时崩], [事故],
  [#strong[08-06]], [提交：#strong["加入路径不变量闸门"] ------ 整个机制诞生], [机制诞生],
  [#strong[08-17]], [提交：#strong["扩到 8 条：……构建产物归属……"] ------ 这条规则落地], [机器执行的规则],
)
=== 08-02 那天发生了什么
<sec-the-incident>
根因不在代码里。

新的执行环境把缓存目录挂成了节点级共享， #strong[同一个节点上并发的进程各自启动构建服务，全部指向同一个输出根，互踩锁。]

崩溃时的日志有明确的识别特征：多个并发任务的日志里出现#strong[相同的输出根哈希]， 同时伴随"服务异常终止"。

这是形状 B ------ 同一份状态有两个写者，只不过这次的"状态"是构建输出目录， 而"写者"是几个互相不知道对方存在的进程。

=== 这条时间线里最值得说的一点
<sec-doc-didnt-help>
#strong[不变量在事故的前一天就已经写进常驻文件了。第二天照样发生了。]

原因不是没人看那份文档。原因是：

#quote(block: true)[
#strong[事故出在刚迁过去的新平台的挂载配置上。 写在文档里的规则不会跟着你迁移到新平台， 它只对读过它的人和会话有效。]
]

那次迁移是一次基础设施变更，做变更的人（或 Agent） 读的是基础设施的配置，不是仓库的常驻文件。 #strong[而那条规则和那次变更之间，没有任何机械的连接。]

这就是全书那句话的代价版本：

#quote(block: true)[
#strong[规则没写进结构，它就只是一段文字。]
]

写进常驻文件的那两行是#strong[声明]，写进禁止模式的才是#strong[结构]。 中间隔着的，是一次线上事故。

而具体隔了多久：#strong[从写下声明到落成结构，十六天。] 其中前五天是"以为已经解决了"，后十一天是在建机制。

== 规则不是一次性设计出来的
<sec-nine-commits>
有一个数字很能说明这套系统的性格：

#strong[架构规则那个文件，从建立到现在总共只有 9 次提交。]

九次，二十三条规则。也就是说规则#strong[极少被批量添加]， 基本是一次一条、跟着一次具体的改动一起进来的。

而每一次提交的标题都写着这条规则是被什么逼出来的：

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([提交标题（节选）], [它揭示的],),
  table.hline(),
  ["本地化表按 owner 就近拆分 X/Y，#strong[并新增]表归属守卫"], [规则和它的第一次应用#strong[同时进来]],
  ["Riff 两端目录按依赖方向重排，#strong[并补上多端产品逃过的]界面粒度闸"], [#strong[一条已有规则漏了一类情况，被一个具体产品钻过去了]],
  ["产品声明解耦 + 例外归位，#strong[发布走账本转为拦截]"], [一条规则从报数#strong[转成拦人]],
  ["界面测试粒度收敛到包装器：#strong[9 个目标合成 2 个]"], [规则带来的具体收益],
)
第二条尤其值得说。它不是"我们想到还该加一条规则"， 而是#strong["某个产品的形态钻过了现有规则的空子，所以补一条"] ------ 规则的边界是被真实的越界行为定义的。

第三条是 #ref(<sec-four-steps>, supplement: [第]) 那个流程在版本历史里的痕迹： #strong[规则先以报数模式跑了一段，等存量清理完（"例外归位"）， 才在同一次提交里转成拦人。]

== 规则上线是四步，不是三步
<sec-four-steps>
#Skylighting(([#NormalTok("① 先写进文档");],
[#NormalTok("② 变成可执行的检查");],
[#NormalTok("③ 以报数模式跑一段时间，把存量清单摆在每一次输出里");],
[#NormalTok("④ 等它收敛了才切成拦截");],));
大部分人会跳过第三步 ------ 既然规则是对的，为什么不直接执行？

#strong[跳过第三步的结果是所有人当场停摆，然后这条规则被关掉。 那还不如从来没有过。]

"那还不如从来没有过"不是修辞。一条被关掉的规则比一条不存在的规则更糟， 因为：

- 它的文件还在，于是下一个人会以为这条约定还在生效
- 关掉它的那次操作建立了一个先例：#strong[规则挡路的时候可以关掉它]
- 而这个先例会被应用到下一条规则上

=== 这一步在控制里有个名字
<sec-deadband>
报数模式在控制工程里叫#strong[死区]：误差被测量、被报告， 但在误差降到某个范围内之前不施加控制作用。

死区存在的理由和这里完全一样：#strong[一个在初始误差很大时就全力动作的控制器， 会饱和、会剧烈震荡，然后被操作员关掉。]

而"被操作员关掉"是控制工程里一个真实且常见的失败模式 ------ 一个总是在叫的告警，最终会被静音；一个总是把阀门开到底的调节器， 最终会被切到手动。

#strong[作者是独立撞出来的，撞出来的形态和教科书上的一模一样。]

== 报数模式还是一件测量仪器
<sec-report-only-instrument>
这一节讲一件源系统还没用起来的事，也是本书对它的第三条建议。

报数模式通常被当成上线的过渡档。#strong[但它同时是一个正在运行的对照组] ------ 它报数但不拦，所以你能看到"如果不拦，会发生什么"的完整样本。

现在有一条规则挂着 #strong[966 处]报数模式的违规，已经跑了一段时间。 于是有一个可以直接问、而且数据全在手边的问题：

#quote(block: true)[
#strong[这段时间里，这 966 处违规实际引发了几次故障？]
]

如果答案是零，那么这条规则可能根本不该切成拦截 ------ 它守的东西也许并不重要，或者重要性远低于它将要制造的摩擦。

如果答案不是零，那么这几次故障就是这条规则最有力的辩护词， 而且它们能告诉你#strong[应该先清理哪一部分存量]。

#strong[报数模式产生的数据，比报数模式本身有价值。] 而这个数据现在没有被读。

== 第一条规则比 Agent 规模化晚了两个月
<sec-two-months-late>
这是全书对"该从哪开始"这个问题的答案，而且它是反直觉的。

#quote(block: true)[
#strong[这不是拖延 ------ 是因为在那之前，根本不知道该拦什么。]
]

正确的顺序是：

- 先遇到一个#strong[行为]问题 → 写一个测试
- 同一种#strong[结构]问题出现几次 → 才沉淀成检查
- 某条#strong[路径]总是需要额外的上下文和风险提醒 → 才为它写一份清单

#strong[别从治理系统开始。]

这里有一个可以自查的推论：

#quote(block: true)[
#strong[如果你现在就能列出二十条该拦的规则， 说明这些规则大概率是从别人那里抄来的，不是从你的失败里长出来的。]
]

抄来的规则有一个共同问题：#strong[它们的边界没有被你的代码校准过。] 而 #ref(<sec-forbid-tuning>, supplement: [第]) 已经说明了，边界没校准的规则误报率会很高， 而误报的规则会被绕过。

== 规则会被绕过，只要它误报
<sec-bypass>
这一节承认这套系统的边界。

问：Agent 会不会绕过这些规则？

答：#strong[会 ------ 只要规则误报。]

所以那些禁止模式是拿真实数据调出来的（#ref(<sec-forbid-tuning>, supplement: [第])）： 不禁掉表退役，因为禁了会在正确的工作上误报，然后被绕过去。

另外每条规则都有哨兵下限，匹配数掉下去说明规则自己失效了 （#ref(<sec-sentinel>, supplement: [第])）。

=== 但有一个数字没有被测量
<sec-bypass-rate>
#strong[绕过率。]

具体说：规则跑了多少次、其中多少次的失败#strong[最终被判定为"规则错了"] （也就是这次改动的结果是改规则，而不是改代码）。

这个比例是#strong[规则集腐化速度的先行指标]：

- 它接近零，说明规则边界校准得好
- 它开始上升，说明规则和代码的实际形态在脱节 ------ 通常发生在一次大重构之后

而这个数据是可以从版本历史里算出来的：#strong[每一次改规则的提交， 去看它前面那次失败是什么。]

== 规则怎么退休
<sec-rule-retirement>
这一节在原始材料里完全没有，但它是这套系统长期风险最大的一块。

二十三条架构规则、二十份路径清单、六条检查通道、各语言的债务台账。 前面讲了规则怎么长出来，#strong[几乎没讲规则怎么退休。]

三个没有答案的问题：

#strong[一、规则本身有没有 owner？] 一条规则加进去之后，谁负责在它误报时修它、在它过时时删它？ 如果答案是"谁碰到谁修"，那么它的实际 owner 是零。

#strong[二、重构时，多少规则的路径范围要跟着改？]

这个问题有一个现成的实例。历史里有一次提交是 "把某产品未被挣得的 App 层摘掉，按获取方式拆进组装根与库" ------ #strong[一次纯粹的目录重排。]

而那次重排之后，所有以路径通配符定义范围的规则， 它们的匹配范围都变了。有的变宽了（扫到了不该扫的）， 有的变窄了（漏掉了该扫的），#strong[而后者是静默的。]

#strong[没有任何机制会告诉你"这次重构让某条规则的覆盖面掉了一半"] ------ 除了哨兵下限，而哨兵只在掉到绝对下界以下时才响 （这正是 #ref(<sec-sentinel-limits>, supplement: [第]) 建议改成相对变化率的原因之一）。

#strong[三、一条挂着 966 处违规的报数规则，收敛的动力从哪来？]

文档里写着"等存量收敛了，它就可以切成拦截"。 但#strong[谁负责收敛？什么时候？]

一条永远处于报数模式的规则会变成背景噪音 ------ 每次 CI 输出里都有它，每次都没人看。 而那时候它已经从"一个正在过渡的规则"变成了"一条被遗忘的规则"， #strong[而这两者在输出里长得一模一样。]

=== 这套系统的长期风险
<sec-long-term-risk>
综合起来：

#quote(block: true)[
#strong[这套系统的长期风险不是不够严， 是规则集本身腐化成一堆没人敢动的历史遗留。]
]

而这个风险有一个明确的先行指标，就是上面那个绕过率。 它现在没有被测量，所以这个风险目前是#strong[不可观测]的 ------ 而 #ref(<sec-observability>, supplement: [第]) 会说明，一个不可观测的状态是不可控的。

== 从反馈到前馈：规则的终点
<sec-rule-endgame>
最后一节回到 #ref(<sec-why-check-then>, supplement: [第]) 埋下的那条线。

一条规则的完整生命周期，不止于"从报数变成拦截"。它还有一段：

#Skylighting(([#NormalTok("① 评审时被人发现        ← 反馈，最贵");],
[#NormalTok("② 变成一条自动检查      ← 还是反馈，但便宜了");],
[#NormalTok("③ 变成一个结构性的不可能 ← 前馈，问题消失");],));
第三步才是终点，而这套系统里有几条走完了：

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([规则], [它最终变成了什么],),
  table.hline(),
  [界面测试的 bundle 命名], [名字由包装器推出，#strong[两个冲突的目标在加载期就报重复，拆不出来]],
  [配置的合法性], [#strong[已校验的类型在模块外无法构造]],
  [哨兵不能被关掉], [#strong[类型是非零整数，且必填]],
  [生成物的一致性], [对拍测试，#strong[签入值与重算值必须相等]],
)
#strong[这四条已经不是"规则"了，它们是结构。] 没有人需要遵守它们，因为违反它们做不到。

而这正是 #ref(<sec-environment-first>, supplement: [章节]) 那句话的具体含义： #strong[检查的最高成就，是把自己变成不再需要检查的东西。]

== 规则的三种死法
<sec-three-deaths>
一条规则不会一直有效。它有三种死法，而#strong[三种的表现完全不同]：

=== 死法一：被关掉
<sec-death-disabled>
最明显的一种。有人在某次紧急情况下把它关了，然后没有开回来。

#strong[它的好处是可见的] ------ 配置里有一个明确的痕迹。 只要有人定期看一眼那份配置，就能发现。

=== 死法二：被绕过
<sec-death-bypassed>
规则还开着，但大家学会了怎么写才不会触发它 ------ 而那种写法并不比原来的更好，只是不触发。

#strong[这种死法在配置里没有任何痕迹。] 规则每次都是绿的， 它的统计数据看起来很健康。

发现它的唯一办法是 #ref(<sec-bypass-rate>, supplement: [第]) 那个指标： #strong[看有多少次失败最终导致的是改规则而不是改代码。]

=== 死法三：范围漂移
<sec-death-drift>
最阴的一种。规则还开着，没有人绕过它，但#strong[它扫的东西变了。]

一次目录重构、一次模块拆分、一次路径通配符的调整 ------ 规则的匹配范围悄悄缩小了，于是它守着一个越来越小的角落， 而输出仍然是绿的。

#strong[哨兵下限是专门防这一种的]，但它只在扫描数掉到绝对下界以下时才响。 一条本来扫 9,000 处的规则掉到 3,000 处，哨兵（下限 50）不会响。

#strong[这就是 #ref(<sec-sentinel-limits>, supplement: [第]) 建议改成相对变化率的最强理由。]

== 三种死法的检测成本
<sec-death-detection>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([死法], [检测方式], [成本],),
  table.hline(),
  [被关掉], [定期看配置], [低],
  [被绕过], [统计"改规则 vs 改代码"的比例], [中，需要一次性建立统计],
  [范围漂移], [扫描数的时间序列 + 变化率告警], [低，数据已经在输出里],
)
#strong[第三行值得注意：数据已经存在了。]

每一次运行的输出里都有每条规则的扫描数（那就是哨兵的读数）。 把它们按时间存下来，画成曲线，#strong[范围漂移会一眼看出来] ------ 一条正常的规则，扫描数应该随仓库增长而缓慢单调上升， 任何一次断崖式下跌都值得怀疑。

这是这本书对源系统的第四条建议，而且它的实现成本几乎为零： #strong[输出里已经有这个数了，缺的只是把它存下来。]

== 规则的数量应该收敛，不是单调增长
<sec-rule-count>
最后一个观察，它和大部分人的直觉相反。

一套健康的规则集，规则数量应该#strong[收敛到一个稳态]，而不是持续增长。

理由是 #ref(<sec-rule-endgame>, supplement: [第]) 讲的那条路径： #strong[每一条走完全程的规则，最终会变成结构，然后从规则集里消失。]

- 界面测试的命名规则 → 变成"两个冲突的目标在加载期就报重复"
- 配置合法性规则 → 变成"已校验的类型在模块外无法构造"

#strong[这两条已经不需要作为规则存在了。]

所以规则集的动力学应该是：新规则从事故里进来， 旧规则通过"变成结构"离开。#strong[如果只有进没有出， 那说明"把规则变成结构"这条路径没有在走] ------ 而那才是真正该担心的事，不是规则太多。

#strong[判据]：过去一年里，有几条规则因为"问题已经在结构上消失了"而被删除？ 如果是零，你的规则集在单调增长，而那是不可持续的。

== 规则的来源分布
<sec-rule-sources>
一条规则可以从三个地方来，而#strong[三个来源的规则，质量差别很大]：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([来源], [特征], [误报率],),
  table.hline(),
  [#strong[一次真实的事故]], [边界被那次事故校准过], [低],
  [一次评审中的重复讨论], [边界模糊，但至少是真需求], [中],
  [#strong[从别处抄来 / 凭空想出]], [边界完全没有校准], [#strong[高]],
)
#ref(<sec-nine-commits>, supplement: [第]) 那九次提交里，绝大多数属于第一类 ------ 每一次提交的标题都写着规则被什么逼出来。

而这个分布本身是一个可以自查的指标：

#quote(block: true)[
#strong[数一下你的规则，有多少条你能说出它是因为哪次具体的失败而存在的？]
]

说不出的那些，就是第三类。#strong[而第三类是绕过率最高的] （#ref(<sec-bypass>, supplement: [第])），也是最该被优先审视的。

== 一条规则的"半衰期"
<sec-rule-halflife>
规则会过时，而过时的方式有两种，#strong[它们的处理完全不同]：

=== 方式一：问题消失了
<sec-problem-gone>
#ref(<sec-rule-endgame>, supplement: [第]) 讲的那条路径 ------ 问题在结构上被消除了。

#strong[处理：删掉规则。] 而且应该有一次明确的删除提交， 提交信息里写清楚"这个问题现在由 X 结构性地保证了"。

#strong[这是最好的一种过时。]

=== 方式二：问题还在，但规则不再匹配它
<sec-rule-mismatched>
代码演化了，规则的模式匹配不到新的形态， 但那个不变量仍然需要被守。

#strong[处理：改规则，不是删规则。]

#strong[而这一种的危险在于它看起来像第一种] ------ 规则不再报违规了，看起来"问题解决了"。

#strong[区分两者的唯一方法是看扫描数]（#ref(<sec-death-drift>, supplement: [第])）：

- 问题真的消失了 → 扫描数不变，违规数归零
- 规则不再匹配了 → #strong[扫描数下降]

#strong[这两个数必须一起看]，而这就是为什么输出格式里 每条规则后面都跟着扫描数（#ref(<sec-output-format>, supplement: [第])）。

== 规则集的健康检查清单
<sec-rule-health>
给一份可以每季度跑一遍的清单：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([检查], [健康的样子],),
  table.hline(),
  [规则总数的变化], [#strong[有进有出]，不是单调增长],
  [每条规则能否说出它的诞生原因], [全部能],
  [报数模式的规则数], [少数，且每条有明确的收敛计划],
  [#strong[零违规的报数规则]], [#strong[应该被切成拦截，或者被删除]],
  [每条规则的扫描数趋势], [随仓库缓慢上升，无断崖],
  [台账的总量趋势], [#strong[单调下降]],
  [绕过率], [接近零],
)
#strong[第四行是最容易被遗漏的]：一条零违规的报数规则处于一个 无意义的中间状态 ------ 它不拦人（所以不产生保护）， 也不报数（因为没有违规），#strong[它只是每次运行多跑了一次扫描。]

而这套系统里现在就有两条这样的规则（#ref(<sec-report-only-three>, supplement: [第])）。

== 事故到规则之间该隔多久
<sec-incident-to-rule-delay>
那条时间线（#ref(<sec-incident-to-rule>, supplement: [第])）里，从事故到规则落地隔了十五天。

#strong[这个延迟是合理的，甚至是必要的。]

理由有三条：

#strong[一、事故当天，你还不知道这类问题的完整形态。] 你只知道这一次它长什么样。而规则要覆盖的是这一类， 不是这一个 ------ 而"这一类"需要时间才能看清。

#strong[二、事故当天做的决定，倾向于过度反应。] 刚被烧过的人会想加一条很严的规则，而过严的规则误报率高， 误报的规则会被绕过（#ref(<sec-bypass>, supplement: [第])）。

#strong[三、规则需要拿真实数据调边界]（#ref(<sec-forbid-tuning>, supplement: [第])）， 而收集数据需要时间。

#strong[但延迟也有上限。] 超过某个时间，那次事故的细节就模糊了， 而细节正是校准规则边界所需要的。

一个可用的节奏：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([时间], [该做什么],),
  table.hline(),
  [#strong[事故当天]], [修好，#strong[并写下故障记录]（细节在这时候最完整）],
  [一周内], [把不变量写进常驻文件或说明（人读的版本）],
  [#strong[两到四周]], [观察同类问题有没有再出现，收集边界数据],
  [一个月内], [如果确实是一类问题，写成可执行的规则，报数模式],
)
#strong[第一行是关键。] 那份故障记录不是给别人看的， 是给一个月后要写规则的你自己看的 ------ 而它的价值取决于它记了多少"当时相信的是什么"。

== 为什么"顺手加一条规则"通常是错的
<sec-not-drive-by>
在一次改动里"顺手"加一条规则，是一个很自然的冲动， 但它有三个问题：

#strong[一、这条规则没有经过报数期。] 它一上来就是拦截的，而你不知道存量有多少 （#ref(<sec-four-steps>, supplement: [第]) 的第三步被跳过了）。

#strong[二、它混在一次业务改动里，评审时不会被单独审视。] 而规则是一个应该被单独审视的东西 ------ 它会影响所有人。

#strong[三、它的诞生原因不会被记录。] 提交信息讲的是那次业务改动，规则只是"顺手" ------ #strong[而一个月后没有人能说出它为什么存在]（#ref(<sec-rule-sources>, supplement: [第])）。

值得对照的是这套系统的实际做法：那九次提交里， #strong[规则总是和它的第一次应用一起进来的]， 而提交标题里明确写着这条规则是什么、为什么。

#strong["和它的第一次应用一起"和"顺手加一条"看起来相似， 实质完全不同] ------ 前者是"我刚做完这件事， 发现它该被规则化"，后者是"我路过，加一条"。

== ⚙️ 小规模怎么做
<sec-lifecycle-small>
#strong[一、第一条规则，选你在评审里重复说得最多的那句话。] 如果你想不起来是哪一句，说明现在还不该做这一层。

#strong[二、每条规则加进去的时候，同时写下它的诞生原因。] 一句话就够。半年后这句话是唯一能判断它该不该继续存在的依据。

#strong[三、永远先报数，再拦人。] 哪怕你确信存量是零 ------ 因为你确信的往往是错的，而这个错误的代价是整条规则被关掉。

#strong[四、给每条规则一个 owner，写在规则旁边。] 不是为了追责，是为了让"这条规则该退休了"这个判断有人做。

== 这一章的一句话
<sec-lifecycle-oneline>
#quote(block: true)[
#strong[规则不是被设计出来的，是被事故长出来的； 而一条规则的终点不是"永远执行"，是"变成不再需要执行的东西"。]
]

前半句决定了你该从哪开始（#ref(<sec-two-months-late>, supplement: [第])）， 后半句决定了你该往哪走（#ref(<sec-rule-endgame>, supplement: [第])）。

#strong[而大部分团队两头都错]：从一份抄来的规则清单开始， 然后让它单调增长，直到没人敢动。

#strong[正确的形态是一个有进有出的流]： 事故进来，结构出去，而中间那段是规则。

== 规则和文档的分工
<sec-rule-vs-doc>
一条约定，什么时候该是规则，什么时候该是文档？

#ref(<sec-always-on-criteria>, supplement: [第]) 从"载体"的角度回答过。 这里从"生命周期"的角度再答一次，因为#strong[两个角度给出的答案 在一处不一致，而那一处很有意思。]

#strong[载体角度]：能写进结构就写进结构，不能的写进常驻文件。

#strong[生命周期角度]：#strong[一条约定在它还可能改变的时候，不该被固化成规则。]

而不一致的地方是：#strong[有些约定重要到必须无条件生效， 但它还没有稳定。]

#strong[这时候正确的做法是报数模式]（#ref(<sec-four-steps>, supplement: [第])）------ 它同时满足两边：规则已经存在（所以它可以被讨论、被数据支撑）， 而它还不拦人（所以改它的成本还很低）。

#strong[报数模式的本质是一个"还没决定"的状态被显式表达了出来。]

而这比另外两个选项都好： 写成文档（不可执行、会被忽略）、 直接拦人（把一个还没稳定的判断固化成了机制）。

== 一条规则的最坏形态
<sec-worst-rule>
最后说一个应该被主动避免的形态， 因为它同时具备了这一章讲的所有问题：

#quote(block: true)[
#strong[一条抄来的、直接拦人的、没有诞生原因的、 没有哨兵的、没有 owner 的规则。]
]

它的失效轨迹是可预测的：

+ 上线，大量存量违规，所有人停摆
+ 有人加一批豁免，或者干脆关掉
+ 如果是加豁免：豁免列表持续增长，没人知道为什么
+ 如果是关掉：文件还在，但它不再生效
+ #strong[半年后，没有人能说出它该不该存在]

#strong[而每一步都是局部合理的]，这正是它危险的地方。

=== 对照：一条规则的最好形态
<sec-best-rule>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([属性], [最好的样子],),
  table.hline(),
  [来源], [#strong[一次真实的失败]],
  [上线], [先报数，存量清零后再拦],
  [边界], [拿真实数据调过，零基线],
  [自检], [有哨兵，且哨兵不能被关掉],
  [失败信息], [带诞生原因和修法],
  [owner], [有名字],
  [终点], [#strong[有一条通往"变成结构"的路]],
)
#strong[七项里，最容易被漏掉的是最后一项。]

而漏掉它的后果是 #ref(<sec-rule-count>, supplement: [第]) 那个问题： #strong[规则集单调增长，而增长是不可持续的。]

== 这一章和第五章的呼应
<sec-lifecycle-echo>
#ref(<sec-why-check-then>, supplement: [第]) 埋了一条线： #strong[每一次反馈抓到的新失败，都是一个可以被转化成前馈的候选。]

而这一章讲的整个生命周期，就是那条转化路径的完整形态：

#Skylighting(([#NormalTok("反馈发现（评审时被人看到）");],
[#NormalTok("  → 便宜的反馈（一条自动检查）");],
[#NormalTok("    → 前馈（结构上做不到）");],));
#strong[三步，而这本书里有四条走完了全程]（#ref(<sec-rule-endgame>, supplement: [第])）。

而值得注意的是：#strong[这四条的终点形态各不相同] ------ 构建图的重复目标、类型的可见性、非零整数、对拍测试。

#strong[四种不同的机制，同一个效果：违反它变成了做不到的事。]

这说明"把规则变成结构"没有统一的做法， #strong[它取决于你的技术栈提供了什么表达能力] （#ref(<sec-open-question-arch>, supplement: [第]) 提过这一点的局限）。

== 一个关于规则集大小的最终判断
<sec-final-rule-count>
这一章的最后一个观察，也是最反直觉的一个：

#quote(block: true)[
#strong[一个健康的规则集，它的大小应该收敛， 而不是随代码量增长。]
]

理由是那条转化路径：规则从事故里进来， #strong[通过"变成结构"离开。]

而这给出一个可以直接用的诊断（#ref(<sec-rule-count>, supplement: [第])）：

#strong[过去一年里，有几条规则因为"问题已经在结构上消失了" 而被删除？]

- #strong[零] → 转化路径没有在走，规则集在单调增长
- #strong[一到两条] → 健康
- 很多条 → 要么规则本来就加得太随意，要么你在做重构

#strong[而"零"是最常见的答案] ------ 因为删除一条规则需要有人主动去做， 而没有任何机制会提醒他（#ref(<sec-rule-retirement>, supplement: [第])）。

= 小规模怎么做（检查层）
<小规模怎么做检查层>
= 小规模怎么做（检查层）
<sec-small-scale-verdict>
和 #ref(<sec-small-scale-environment>, supplement: [章节]) 配对，同样的约束： #strong[不许出现任何需要重基建的建议。]

== 按投入产出比排序的三道检查
<sec-three-checks>
=== 一、断言测试执行数不为零
<sec-assert-nonzero>
#strong[投入：半小时。这是整本书投入产出比最高的一条改动。]

它挡住的是 #ref(<sec-fake-green>, supplement: [第]) 里那三个形态中最常见的一种， 而且它的实现就是在 CI 脚本里加一行 grep：

#Skylighting(([#CommentTok("# 跑完之后，确认真的跑了");],
[#VariableTok("output");#OperatorTok("=");#VariableTok("$(");#OperatorTok("<");#NormalTok("你的测试命令");#OperatorTok(">");#NormalTok(" 2");#OperatorTok(">&");#DecValTok("1");#VariableTok(")");],
[#BuiltInTok("echo");#NormalTok(" ");#StringTok("\"");#VariableTok("$output");#StringTok("\"");#NormalTok(" ");#KeywordTok("|");#NormalTok(" ");#FunctionTok("grep");#NormalTok(" ");#AttributeTok("-qE");#NormalTok(" ");#StringTok("\"Executed [1-9][0-9]* test\"");#NormalTok(" ");#KeywordTok("||");#NormalTok(" ");#KeywordTok("{");],
[#NormalTok("    ");#BuiltInTok("echo");#NormalTok(" ");#StringTok("\"guard: 测试执行数为 0\"");#KeywordTok(";");#NormalTok(" ");#BuiltInTok("exit");#NormalTok(" 1");],
[#KeywordTok("}");],));
不同的测试框架输出格式不同，但#strong[每个框架都会打印执行数]。 找到那一行，断言它不为零。

#strong[为什么这条排第一]：因为它是#strong[上游污染的防线]。 一旦"跑了零个用例"没被发现， 后面所有依赖"跑一次看结果"的动作 ------ 变异验证、flake 复现、 二分定位 ------ #strong[得出的结论全是空话。]

=== 二、退出码三分
<sec-exit-codes-again>
#strong[投入：半天。] 详见 #ref(<sec-three-exit-codes>, supplement: [第])。

这一条同时属于环境层和检查层的入门清单，因为它便宜到不做没道理。

一个补充的实践：#strong[在给 Agent 的提示里， 把"看到退出码 2 不要改代码"写成一条常驻规则。] 否则你做了这个区分，而消费它的一方不知道。

=== 三、一条报数模式的结构规则
<sec-first-report-only>
#strong[投入：一天。]

选你团队在评审里吵得最多的那条约定，写成检查，#strong[先只报数不拦。]

然后跑两周，看它每次报多少。这个数字会告诉你两件事：

- #strong[它到底是共识还是一厢情愿。] 如果存量违规有几百处， 那这条"约定"从来没有被真正执行过。
- #strong[该先清理哪部分存量。] 报数输出应该带上具体位置。

#strong[两周之后再决定要不要切成拦截。] 而且要按 #ref(<sec-four-steps>, supplement: [第]) 那四步走 ------ 先把存量清到接近零，再切。

== 变异验证的最小形态
<sec-mutation-minimal>
这一条不是"一道检查"，是一个习惯，但它比上面三条加起来还重要：

#quote(block: true)[
#strong[每次修 bug 时，先让新测试红一次，再让它绿。]
]

#strong[成本是零] ------ 你本来就要跑一次测试。区别只是跑的顺序： 先写测试、跑一次（应该红）、再改代码、再跑（应该绿）。

如果第一次它没红，#strong[你刚刚发现了一条假绿]， 而发现的成本是零。

这条习惯的价值在 Agent 场景下被放大了，因为 #ref(<sec-mutation>, supplement: [第]) 讲的那个结构性理由： #strong[让一个断言通过，永远比让一个行为正确要容易。] 而一个被要求"加测试"的 Agent 面对的正是这个优化问题。

== 不要做的三件事
<sec-three-donts>
#strong[一、不要一上来就拦人。] 存量违规会让所有人当场停摆，然后规则被关掉 ------ #strong[而被关掉的规则比不存在的规则更糟]， 因为它建立了"规则挡路时可以关掉它"这个先例。

#strong[二、不要抄别人的规则表。] 抄来的规则边界没有被你的代码校准过，误报率会很高。 而误报的规则会被绕过，绕过之后它还继续消耗信任。

#strong[三、不要为"以后可能有用"写规则。] 和目录层级一样（#ref(<sec-earned-level>, supplement: [第])）：#strong[规则也必须被一次真实的失败挣得。]

== 什么时候该升级
<sec-when-to-scale>
三个信号，出现任意一个就该往上走一档：

#strong[一、同一类问题在两个月内出现三次。] 这是 #ref(<sec-promotion>, supplement: [第]) 那条演进纪律的检查层版本。

#strong[二、有人开始用"本地是好的"当理由。] 这说明本地和 CI 跑的不是同一件事（#ref(<sec-local-vs-ci>, supplement: [第])）， 而这个裂缝会越来越宽 ------ 一旦这个理由被接受一次， 整个检查层的权威就开始漏气。

#strong[三、你发现自己在评审里反复说同一句话。] 这句话就是你的下一条规则，而且它已经被"挣得"了。

== 从一道检查到一套系统的三个台阶
<sec-three-steps-up>
上面三道检查建好之后，接下来会自然遇到三个问题。 它们出现的顺序几乎是固定的：

=== 台阶一：规则开始互相冲突
<sec-step-conflict>
#strong[出现时机]：规则超过五条左右。

#strong[症状]：一条规则要求 A，另一条隐含地要求非 A。 或者更常见的：一条规则在另一条规则要求的写法上误报。

#strong[修法]：这说明规则背后的#strong[原则]没有被找出来。 两条冲突的规则，通常是同一条原则的两个不完整的投影。 找出那条原则，用它替换两条规则。

=== 台阶二：本地和 CI 开始不一致
<sec-step-divergence>
#strong[出现时机]：检查开始有配置、有依赖、有版本。

#strong[症状]：有人说"本地是好的"。

#strong[修法]：#ref(<sec-policy-mechanism>, supplement: [第]) 那一条 ------ #strong[让本地和 CI 跑同一条命令、同一份配置。] 这通常意味着把检查从 CI 配置里 挪进一个可以本地执行的脚本，而 CI 只是调用它。

#strong[这一步的收益被严重低估]：它同时消除了一类争论和一类误报。

=== 台阶三：失败开始分不清是谁的错
<sec-step-attribution>
#strong[出现时机]：检查依赖了外部资源（下载、容器、真实设备）。

#strong[症状]：红灯里开始混进"不是代码的错"的那些。

#strong[修法]：退出码三分（如果你还没做）。而如果你已经做了， 这一步的问题会升级成：#strong[怎么判断一个新工具的失败该归哪一类？]

而这个判断没法自动做，只能一条一条接。 #ref(<sec-lane-uniformity>, supplement: [第]) 讲过这个成本，以及为什么它必须付。

== 三道检查各自的最小实现
<sec-minimal-implementations>
给到可以直接抄的程度。

=== 断言测试执行数不为零
<sec-impl-nonzero>
关键是找到你的测试框架打印执行数的那一行。常见的形态：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([框架族], [输出里的那一行长什么样],),
  table.hline(),
  [xUnit 系], [#NormalTok("Executed N tests"); / #NormalTok("N tests, N assertions");],
  [各语言的内置测试], [#NormalTok("ok N"); / #NormalTok("N passed");],
  [端到端框架], [#NormalTok("N passing");],
)
拿到之后，断言它不为零。#strong[注意要断言"不为零"， 不是断言"等于某个数"] ------ 后者会在每次加测试时失败， 然后被人调大，然后失去意义。

=== 退出码三分
<sec-impl-exit-codes>
不需要重写 CI。在你现有的检查脚本外面包一层：

#Skylighting(([#FunctionTok("run_check()");#NormalTok(" ");#KeywordTok("{");],
[#NormalTok("  ");#VariableTok("output");#OperatorTok("=");#VariableTok("$(");#StringTok("\"");#VariableTok("$@");#StringTok("\"");#NormalTok(" ");#DecValTok("2");#OperatorTok(">&");#DecValTok("1");#VariableTok(")");#KeywordTok(";");#NormalTok(" ");#VariableTok("code");#OperatorTok("=");#VariableTok("$?");],
[#NormalTok("  ");#BuiltInTok("[");#NormalTok(" ");#VariableTok("$code");#NormalTok(" ");#OtherTok("-eq");#NormalTok(" 0 ");#BuiltInTok("]");#NormalTok(" ");#KeywordTok("&&");#NormalTok(" ");#ControlFlowTok("return");#NormalTok(" ");#DecValTok("0");],
[#NormalTok("  ");#CommentTok("# 基建故障的特征：识别它们，返回 2");],
[#NormalTok("  ");#ControlFlowTok("case");#NormalTok(" ");#StringTok("\"");#VariableTok("$output");#StringTok("\"");#NormalTok(" ");#KeywordTok("in");],
[#NormalTok("    ");#PreprocessorTok("*");#StringTok("\"command not found\"");#PreprocessorTok("*");#KeywordTok("|");#PreprocessorTok("*");#StringTok("\"connection refused\"");#PreprocessorTok("*");#KeywordTok("|");#DataTypeTok("\\");],
[#NormalTok("    ");#PreprocessorTok("*");#StringTok("\"no space left\"");#PreprocessorTok("*");#KeywordTok("|");#PreprocessorTok("*");#StringTok("\"timeout\"");#PreprocessorTok("*");#KeywordTok("|");#PreprocessorTok("*");#StringTok("\"unable to fetch\"");#PreprocessorTok("*");#KeywordTok(")");],
[#NormalTok("      ");#BuiltInTok("echo");#NormalTok(" ");#StringTok("\"");#VariableTok("$output");#StringTok("\"");#KeywordTok(";");#NormalTok(" ");#BuiltInTok("echo");#NormalTok(" ");#StringTok("\"guard: 基建故障\"");#KeywordTok(";");#NormalTok(" ");#ControlFlowTok("return");#NormalTok(" ");#DecValTok("2");#NormalTok(" ");#ControlFlowTok(";;");],
[#NormalTok("  ");#ControlFlowTok("esac");],
[#NormalTok("  ");#BuiltInTok("echo");#NormalTok(" ");#StringTok("\"");#VariableTok("$output");#StringTok("\"");#KeywordTok(";");#NormalTok(" ");#ControlFlowTok("return");#NormalTok(" ");#DecValTok("1");#NormalTok("     ");#CommentTok("# 其余归为内容违规");],
[#KeywordTok("}");],));
#strong[这个特征列表一开始不会全]，而这没关系 ------ 每次遇到一个新的基建故障，往里加一条。 #strong[它是从失败里长出来的，和规则一样。]

=== 第一条报数模式的规则
<sec-impl-report-only>
#Skylighting(([#VariableTok("hits");#OperatorTok("=");#VariableTok("$(");#FunctionTok("grep");#NormalTok(" ");#AttributeTok("-rn");#NormalTok(" ");#StringTok("\"<你的模式>\"");#NormalTok(" ");#OperatorTok("<");#NormalTok("你的范围");#OperatorTok(">");#NormalTok(" ");#KeywordTok("|");#NormalTok(" ");#FunctionTok("wc");#NormalTok(" ");#AttributeTok("-l");#VariableTok(")");],
[#BuiltInTok("echo");#NormalTok(" ");#StringTok("\"[YOUR-RULE] (report-only) — ");#VariableTok("$hits");#StringTok(" 处 (扫描 ");#VariableTok("$(");#ExtensionTok("...");#VariableTok(")");#StringTok(" 个文件)\"");],
[#BuiltInTok("exit");#NormalTok(" 0     ");#CommentTok("# 报数不拦");],));
#strong[注意那个"扫描了多少个文件"] ------ 那就是哨兵的读数 （#ref(<sec-sentinel>, supplement: [第])）。从第一天就打印它，因为等你想加的时候， 你已经没有历史数据可以对照了。

== 这三道检查合起来防住了什么
<sec-what-three-checks-cover>
对照七个形状，看这三道覆盖了哪些：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([形状], [三道检查覆盖了吗],),
  table.hline(),
  [A 探针测错], [#strong[部分] ------ 第一道防住了最常见的一种],
  [B 两个写者], [没有 ------ 需要针对性的规则],
  [C 修了实例], [没有 ------ 需要故障记录的复盘],
  [D 声明未生效], [没有 ------ 需要观测器（#ref(<sec-observer>, supplement: [章节])）],
  [E 边界降级], [没有],
  [F 资源无界], [没有],
  [G 本地≠远端], [#strong[部分] ------ 第二道让归因变清楚了],
)
#strong[七个里覆盖了两个的一部分。]

这个诚实的盘点很重要，因为它防止一种误解： 建完这三道不等于"判定建好了"。

#strong[但这三道是有顺序意义的]：它们建立的是#strong[判定本身的可信度]， 而其余五个形状的检查，全都建立在"我的检查是可信的"这个前提上。

#strong[先有可信的判定，再有更多的判定。] 顺序反了的话， 你会在一个不可信的基础上叠加，而叠加的每一层都继承了底层的不可信。

== 一个人的检查层
<sec-solo-verdict>
前面讲的是五人团队。一个人的情况不一样，值得单独说。

#strong[一个人的系统里，最反直觉的一点是：判定层的价值不是"防别人"， 是"防未来的自己"。]

具体地说，它防的是三件事：

#strong[一、防止你自己在赶时间的时候放水。] 一条自动检查不会因为今天很急就网开一面。而你会。

#strong[二、防止上下文丢失。] 三个月后回到一段代码，你已经忘了当时为什么那样写。 而一条带 #NormalTok("incident"); 字段的规则会告诉你。

#strong[三、防止 Agent 的产出在你不注意时漂移。] 这是最实际的一条：一个人不可能逐行看几十个改动， 而 Agent 会持续产出。

=== 一个人该建哪两条
<sec-solo-two-checks>
如果只建两条：

#strong[第一条：测试执行数不为零。] 理由同前，成本半小时。

#strong[第二条：一条"我最容易犯的错"的检查。]

而这一条要靠翻自己的提交历史找出来 ------ #strong[看你过去半年里，有哪一类问题你修过三次以上。]

一个人的系统里，这个数据特别可靠，因为所有的提交都是你自己的。 #NormalTok("git log"); 就是你的故障记录。

== 判定层和你的时间的关系
<sec-verdict-and-time>
最后一个视角，它解释了这一层为什么值得投入。

#strong[判定层做的事情，本质上是把你的注意力从"检查"移到"判断"。]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([没有判定层], [有判定层],),
  table.hline(),
  [你要看每一个改动], [你只看被拦下来的],
  [你要判断"这样写对不对"], [机器判断，你判断"该不该这么做"],
  [你的注意力随产出线性消耗], [#strong[你的注意力随"意外"消耗]],
)
#strong[第三行是关键。]

一个健康的判定层，会让你的注意力消耗和"产出量"脱钩， 转而和"意外的数量"挂钩。

而意外的数量是#strong[有上限]的（一个系统里真正新鲜的问题不多）， 产出量没有上限。

#strong[这就是为什么这一层的投入回报是超线性的] ------ 它不是让你快了一点，它改变了你的注意力消耗曲线的形状。

而这也解释了 #ref(<sec-dashboard-nobody-reads>, supplement: [第]) 那句话为什么重要： #strong[当注意力不再和产出量挂钩之后， 它就变成了这个系统里最稀缺、也最值得保护的资源。]

== 什么时候可以停
<sec-when-to-stop>
这本书讲的东西可以一直建下去，所以得说清楚什么时候该停。

#strong[一个可用的停止条件：当你连续两个月没有遇到 "合并之后才发现的问题"时，停。]

这不是说你的系统完美了，是说#strong[当前的瓶颈已经不在判定这一侧了。] 继续加固判定是在优化一个不是瓶颈的环节。

那时候瓶颈通常在两个地方，而这本书都帮不上忙：

- #strong[在参考输入上] ------ 也就是「该做什么」这个按定义在回路之外的问题 （#ref(<sec-no-self-setpoint>, supplement: [第]) · #ref(<sec-setpoint-outside>, supplement: [章节])）------ 做的事情本身不对
- #strong[在工具链上]（#ref(<sec-toolchain>, supplement: [章节])）------ Agent 够不着某些东西，只能猜

#strong[第二个在小团队里出现得比想象中早。] 一个五人团队， 在建了三道检查之后，下一笔最值钱的投入通常不是第四道检查， 是#strong[让 Agent 能看见它改的东西]。

== 三道检查的常见实现错误
<sec-common-mistakes>
按遇到的频率排：

=== 错误一：断言执行数等于某个具体的数
<sec-mistake-exact-count>
#Skylighting(([#FunctionTok("grep");#NormalTok(" ");#AttributeTok("-q");#NormalTok(" ");#StringTok("\"Executed 42 tests\"");#NormalTok("     ");#CommentTok("# ✗");],
[#FunctionTok("grep");#NormalTok(" ");#AttributeTok("-qE");#NormalTok(" ");#StringTok("\"Executed [1-9][0-9]* tests\"");#NormalTok("   ");#CommentTok("# ✓");],));
前者每次加测试都会失败，然后被人改成新的数， #strong[改几次之后就会被改成 #NormalTok("Executed .* tests");，于是它什么都不检查了。]

#strong[一条会因为正常工作而失败的检查，最终会被改成不检查任何东西。]

=== 错误二：把基建故障的特征写死
<sec-mistake-hardcoded>
第一次遇到"connection refused"，加进去。 第二次遇到"i/o timeout"，加进去。 #strong[第三次遇到一个新的，检查把它归成了内容违规。]

这不是错误，这是#strong[必然] ------ 特征列表永远不完整。

#strong[正确的心态是把它当成一个持续维护的列表]， 而不是一次写完的配置。而这意味着它需要一个 owner （#ref(<sec-dedicated-owner>, supplement: [第])）。

=== 错误三：报数模式的输出没有位置信息
<sec-mistake-no-location>
#Skylighting(([#NormalTok("[MY-RULE] 47 处违规          ✗  你不知道该从哪开始清");],
[#NormalTok("[MY-RULE] 47 处违规          ✓");],
[#NormalTok("  src/a.ts:12  ...");],
[#NormalTok("  src/b.ts:88  ...");],));
#strong[报数模式的全部价值就在那份清单里。] 只报一个数字，你得到的是焦虑，不是行动项。

而这也是为什么那条挂着 966 处违规的规则仍然有价值 ------ #strong[它每一次都把这 966 处的位置和修法摆出来] （#ref(<sec-enforce-levels>, supplement: [第])）。

=== 错误四：忘了打印扫描面
<sec-mistake-no-scan-count>
#Skylighting(([#NormalTok("[MY-RULE] 0 处违规                        ✗");],
[#NormalTok("[MY-RULE] 0 处违规（扫描 1,204 个文件）   ✓");],));
#strong[前者在规则坏掉时和规则通过时长得一模一样。]

而这个数字是免费的（你本来就遍历了那些文件）， #strong[且它是后面所有自检机制的基础]（#ref(<sec-sentinel>, supplement: [第])）。

#strong[从第一天就打印它] ------ 等你想加的时候， 你已经没有历史数据可以对照了。

== 三道检查之后的第四道该是什么
<sec-fourth-check>
三道建完之后，最常见的问题是"接下来加什么"。

#strong[答案不在这本书里，在你的评审记录里。]

#ref(<sec-after-one-month>, supplement: [第]) 那个练习的产出 ------ 你重复说得最多的那句话 ------ 就是第四道检查的内容。

#strong[而这条原则值得被明确表述]：

#quote(block: true)[
#strong[第四道及之后的每一道检查，都应该来自你自己的失败， 而不是来自任何一本书的清单。]
]

理由在 #ref(<sec-rule-portability>, supplement: [第])：这本书那二十三条里， 真正可移植的只有三到四条，#strong[而剩下的十九条对你来说是噪音。]

== 判定层的三个成熟度阶段
<sec-verdict-maturity>
给一个可以定位自己的框架：

=== 阶段一：有检查，但不知道检查可不可信
<sec-maturity-one>
#strong[特征]：CI 是绿的，但你不完全放心。有时候会手工再验一遍。

#strong[这个阶段的瓶颈是可信度，不是覆盖面。] 加更多检查不会让你更放心 ------ #strong[让现有的检查可信才会。]

三道检查（#ref(<sec-three-checks>, supplement: [第])）针对的正是这个阶段。

=== 阶段二：检查可信，但覆盖不全
<sec-maturity-two>
#strong[特征]：CI 绿了你就敢合，但仍然有问题漏过去。

#strong[这个阶段可以开始加规则了]，而且加的每一条 都应该来自一次真实的逃逸（#ref(<sec-rule-sources>, supplement: [第])）。

=== 阶段三：覆盖够了，但维护成本上来了
<sec-maturity-three>
#strong[特征]：规则超过二十条，开始有误报，开始有人抱怨。

#strong[这个阶段需要的是 #ref(<sec-rule-health>, supplement: [第]) 那张健康检查清单， 和一个有名字的 owner]（#ref(<sec-dedicated-owner>, supplement: [第])）。

=== 三个阶段的顺序不能跳
<sec-maturity-order>
#strong[最常见的错误是从阶段二开始] ------ 直接加一批规则， 而底下那三道保证可信度的检查还没有。

#strong[结果是：你有二十条规则，但你不知道它们是不是还在工作。]

而这个状态比只有三条可信的检查#strong[更糟]， 因为它给了你一种虚假的安全感 ------ 而虚假的安全感会让你停止手工验证。

== 一张自检表
<sec-self-check-table>
最后，把 #ref(<sec-sensor-self-check>, supplement: [第]) 那张表放在这里， 因为它是这一层最好的入门练习：

对你现有的#strong[每一道]检查，填这一行：

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([检查], [它坏了会表现成通过还是失败？], [有没有量程校验？], [有没有第二通道？],),
  table.hline(),
  [], [], [], [],
)
#strong[大部分人第一次填完会发现：绝大多数检查在坏掉的时候会表现成"通过"， 而且后两列一个勾都没有。]

这不是灾难 ------ 这只是说明这些检查此前从来没有被当成#strong[传感器]看待过。 而只要开始这么看，后两列都能在一天之内补上第一个勾。

== 这三道检查为什么不包括"写测试"
<sec-no-write-tests>
一个可能的疑问：为什么入门清单里没有"要求写测试"？

#strong[因为"要求写测试"不是一道检查，是一个期望。]

而它和这三道的差别在于：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([], [三道检查], ["要求写测试"],),
  table.hline(),
  [能否自动验证], [#strong[能]], [能（覆盖率），但那验证的不是同一件事],
  [失败时的动作], [明确], [#strong[不明确]（写什么样的测试？）],
  [它坏了会怎样], [有信号], [#strong[无信号]],
)
#strong[第二行是关键。]

"覆盖率不达标"这个失败，给出的指导是"去覆盖那些行"------ 而满足它最快的方式是写没有断言的测试 （#ref(<sec-coverage-devalued>, supplement: [第])）。

#strong[所以这条要求会引导出一个不是你想要的行为。]

而三道检查里那条"断言测试执行数不为零"不同： 它失败时的指导是明确的（你的过滤器写错了，或者宿主缺了）， #strong[而且没有一个"作弊"的满足方式] ------ 要让执行数非零，你必须真的跑一些用例。

#strong[这是判断一道检查好不好的一个通用标准：]

#quote(block: true)[
#strong[满足它最省事的方式，是不是你想要的那个行为？]
]

不是 → 这道检查会产生它自己的技术债。

== 判定层建设的一条时间线
<sec-verdict-timeline>
给一个可以照着走的六个月节奏：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([时间], [做什么], [产出],),
  table.hline(),
  [第 1 周], [测试执行数断言 + 退出码三分], [判定开始可信],
  [第 2--4 周], [#strong[只观察]，记评审语句和红灯分类], [两份数据],
  [第 2 月], [第一条规则，报数模式], [存量的数字],
  [第 3 月], [清存量，同时观察第二条规则的候选], [---------],
  [第 4 月], [第一条切拦截，第二条上报数], [第一道真正的门],
  [第 5--6 月], [重复，同时开始记录扫描数的时间序列], [可观察的健康度],
)
#strong[注意第 2--4 周那一格：什么都不加，只观察。]

这三周通常会被跳过，而跳过它的代价是 #strong[你的第一条规则来自猜测而不是数据]（#ref(<sec-rule-sources>, supplement: [第])）。

#strong[而这本书里最贵的一个教训是]： 第一条自动检查比 Agent 规模化晚了两个月 ------ #strong[而那不是拖延，是因为在那之前不知道该拦什么] （#ref(<sec-two-months-late>, supplement: [第])）。

== 这一章能被压成的三句话
<sec-small-verdict-three-lines>
#strong[一、先建可信度，再建覆盖面。]

三道检查（执行数、退出码三分、一条报数规则） 针对的全是"我的检查可不可信"， #strong[而不是"我的检查够不够全"]（#ref(<sec-maturity-order>, supplement: [第])）。

#strong[二、第四道及之后的每一道，都必须来自你自己的失败。]

因为抄来的规则边界没有被你的代码校准过， #strong[而误报的规则会被绕过，绕过之后它还继续消耗信任。]

#strong[三、一道好的检查，满足它最省事的方式 应该就是你想要的那个行为。]

#ref(<sec-no-write-tests>, supplement: [第]) 那个判据是这一章唯一的通用测试 ------ #strong[它能提前发现一道检查会不会制造它自己的技术债。]

== 最后一件事：不要一次做完
<sec-dont-rush>
这一章给的东西加起来大概一周半的工作量， #strong[而正确的做法是把它摊到两三个月。]

理由在 #ref(<sec-verdict-timeline>, supplement: [第]) 那张表的第二行： #strong[第 2--4 周什么都不加，只观察。]

而"只观察"之所以难，是因为它没有可见的产出 ------ #strong[在那三周里，你手上没有任何新东西可以展示。]

#strong[但那三周的产出是后面所有规则的依据。]

跳过它的代价不是"晚了三周"，是 #strong[你的第一条规则来自猜测而不是数据] ------ 而一条来自猜测的规则，误报率高、被绕过、 然后连带损害你对整套东西的信任（#ref(<sec-rule-sources>, supplement: [第])）。

#strong[这本书里最贵的一个教训，就是这个： 第一条自动检查比 Agent 规模化晚了整整两个月， 而那不是拖延。]

#part[第四部 · 回路]
= 增益与延迟
<增益与延迟>
= 增益与延迟
<sec-gain-and-delay>
#ref(<sec-two-walls>, supplement: [章节]) 里留了一个问题：两堵墙的形状是一样的，但没说那个形状叫什么。

这一章给它一个名字，然后用这个名字预测下一堵墙会在哪。

== 两个变量
<sec-two-variables>
先做两个翻译。

#strong[Agent 的吞吐是回路增益。] 增益的定义是：每单位测得的误差， 你施加多少修正。更多的 Agent 并行，意味着单位时间里施加的修正更多。

#strong[流水线的延迟是回路延迟。] 从改动产生，到判定回到 Agent 手里， 中间隔了多久。这个仓库里的实测值是：结构检查中位 5.2 分钟， UI 与端到端测试中位 14.9 分钟，而从红灯到最终转绿的中位时间是 1.4 小时， 长尾接近二十小时。

有了这两个变量，控制论里最基本的一条结论就能用上了：

#quote(block: true)[
#strong[在有延迟的系统里提高增益，会导致失稳。 延迟带来的问题，不能靠加大增益来解决。]
]

这句话在工程上的直觉版本是：一个反应很快但要等很久才知道结果的控制器， 会不停地过冲、反向过冲、再过冲。它越努力，抖得越厉害。

== 两堵墙的重新表述
<sec-walls-restated>
现在把两堵墙翻译一遍：

#strong[墙一：增益上去了，反馈路径的带宽没变。]

人审是一个极低带宽的传感器兼控制器 ------ 一天能处理的 diff 数是个位数， 而且这个数不随投入线性增长（第二个审查者不会让审查速度翻倍， 因为他们要看的是同一批代码）。往这样一个回路里灌几十个 Agent， 结果只能是排队。

#strong[墙二：反馈路径的带宽扩了，但测量的对象没有缩小。]

买机器等价于把传感器的采样率提上去。但如果每次采样都要测量整个状态空间 ------ 每条改动都跑全量检查 ------ 那么采样率的提升会被测量成本的增长吃掉。

#strong[而真正的解法不是继续扩带宽，是缩小测量。]

查反向依赖图、只测本次真正变化的那部分，在控制里的名字是#strong[稀疏测量]： 你不需要观测全部状态，只需要观测那些实际发生了变化的维度。

这就是为什么第二次买机器不管用、而查依赖图管用 ------ #strong[这两者不是程度差异，是性质差异。] 一个在扩大分子，一个在缩小分母。

== 为什么测试金字塔其实是串级控制
<sec-cascade>
#ref(<sec-pyramid>, supplement: [第]) 里说，金字塔的形状是被成本逼出来的：越往上一层， 一次判定越贵，而覆盖的路径反而最少，所以要"把判定尽量下沉到便宜的那一层"。

成本是对的，但它不是主要理由。主要理由是稳定性。

一个快内环（结构检查，5.2 分钟）加一个慢外环（端到端，14.9 分钟） 是一个标准的#strong[串级控制]结构：

- 内环快速抑制大部分扰动 ------ 格式、依赖方向、危险配置， 这些在五分钟内就被打掉了，根本传不到外环
- 外环只处理内环漏过来的那一小部分 ------ 真正需要把程序跑起来才能发现的行为问题

串级控制有一个前提，而且这个前提是定量的：#strong[内环必须显著快于外环。] 如果两个环的时间常数接近，串级不会带来任何好处， 反而会因为多了一层而增加复杂度。

这给出一个可以直接用的判据：

#quote(block: true)[
如果你的静态检查和你的端到端测试耗时在同一个量级， 那你没有串级，你只有两个并联的慢环。
]

这个仓库里的比值是 5.2 : 14.9，接近 1:3。这是一个能工作的串级。 而在很多团队里，静态检查和单元测试都要跑十几分钟 ------ 那里没有内环。

== 采样周期：另一个被撞对的结论
<sec-cadence-theory>
#ref(<sec-cadence>, supplement: [第]) 讲过，周期任务的节奏由外部系统的反馈延迟决定 ------ 投放报表按日结算就日级采样，商店审核加重新索引要一周就周级采样。

这条在控制里叫#strong[采样周期匹配对象时间常数]，而它的理由比"看不到效果"更硬。

一个被控对象有它自己的响应速度。你以远快于这个速度的频率去采样， 采到的#strong[不是它的状态，是它的噪声] ------ 因为在两次采样之间， 对象根本还没有对上一次的输入做出反应，你看到的变化全部来自别的东西。

而这还不是最坏的。最坏的是：#strong[你会依据这些噪声动作。]

于是回路开始追噪声：报表今天跌了 3%，调低出价；明天涨回来了，调高； 后天又跌，再调低。#strong[每一次调整都在给系统注入一个新的扰动， 而这些扰动的效果会在一天后到达，和当时的调整完全对不上号。] 一个本来会自己稳定下来的系统，被采样过快的控制器搅成了振荡。

大部分人会为了"响应快"把这类回路设成小时级。这个直觉在 #strong[延迟很小的系统里]是对的（比如一个 5 分钟就能看到效果的 A/B 实验）， 在延迟以天计的系统里是灾难性的。

#strong[判据很简单：采样周期不应短于对象的响应时间。] 如果你不知道对象的响应时间，那么第一件该做的事是测量它， 而不是先定一个"感觉合理"的频率。

== 稳定裕度正在缩
<sec-margin-shrinking>
现在用这个框架做一个预测。

增益在涨：Agent 数量在涨，单日合入次数从个位数涨到峰值五十二次。

延迟基本不动：流水线的中位耗时由测试本身的性质决定， 它不会随仓库变大而变快，只会变慢。

#strong[增益上升、延迟不变，意味着相位裕度在缩。] 这个系统正在被自己的成功推向稳定边界。

失稳在这里会长成什么样？不是崩溃，是#strong[返工振荡]： 一个改动红了，"修好"之后又红了，再修再红。 现有数据里已经有这个形状的影子 ------ 平均每个改动跑 1.7 条流水线， 而被拦得最狠的两个各红了四次，其中一个跨了将近二十个小时。

⚠️ #strong[这里有一个本书对源系统的具体建议：把振荡次数做成时间序列。]

这个仓库测量了大量关于代码的东西，但没有测量回路本身。 控制工程师会仪表化上升时间、超调量、#strong[振荡次数]、稳态误差。 而"红→绿→红"的次数，是这套系统最直接的稳定性指标， 也是增益与延迟失配的#strong[先行指标] ------ 它会在系统真正出问题之前先涨起来。

原始数据都在流水线记录里，缺的只是把它当成一条曲线看。

== 延迟的四个组成部分
<sec-delay-breakdown>
在讨论怎么降延迟之前，先把它拆开，因为#strong[四个部分的可压缩性差别很大]：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([组成], [这套系统的实测], [可压缩性],),
  table.hline(),
  [#strong[排队]], [取决于负载], [#strong[高] ------ 加机器或缩小测量],
  [#strong[测量本身]], [结构检查 5.2 分 / 端到端 14.9 分], [中 ------ 有物理下界],
  [#strong[人的介入]], [这套系统里近乎为零], [---------],
  [#strong[Agent 的理解与重试]], [未测量], [#strong[未知]],
)
#strong[第一行是这套系统压缩得最成功的部分] ------ 从"每条改动跑全量"到"只跑受影响的"，压缩的正是排队。

#strong[第四行是完全没有被测量的部分]，而它可能是现在最大的那一块。

从红灯到转绿的中位时间是 1.4 小时，而流水线本身的中位耗时 远小于这个数（结构检查 5.2 分钟，端到端 14.9 分钟）。 #strong[中间那一个多小时去哪了？]

平均每个改动跑 1.7 条流水线，所以流水线时间大概是半小时上下。 #strong[剩下的时间是 Agent 在读失败、理解、修改、重新提交。]

#strong[这意味着：回路延迟里最大的一块，可能不在基础设施上， 而在"失败信息的质量"上。]

如果这个推测成立，那么#strong[改善失败信息的收益， 可能高于再买一批机器] ------ 而前者的成本低几个数量级。

这也就是为什么 #ref(<sec-incident-hint>, supplement: [第]) 那条纪律 （失败时把 owner、证据和下一步一起给出去） 不是用户体验问题，#strong[是延迟问题。]

== 一个可以立刻做的测量
<sec-measure-the-loop>
这本书对源系统的第一条建议，在这里给出具体形态。

#strong[需要采集的三个数，全都已经存在于流水线记录里：]

#Skylighting(([#NormalTok("每个改动：");],
[#NormalTok("  ① 提交时间 → 第一次判定返回的时间     = 测量延迟");],
[#NormalTok("  ② 第一次红灯 → 最终转绿的时间          = 完整回路延迟");],
[#NormalTok("  ③ 跑了几条流水线                       = 振荡次数");],));
#strong[画三条按周的曲线。]

而要看的不是绝对值，是#strong[趋势和它们之间的关系]：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([观察], [意味着],),
  table.hline(),
  [① 平，② 涨，③ 涨], [#strong[增益超前于延迟，稳定裕度在缩]],
  [① 涨，② 涨，③ 平], [测量变慢了，但回路还稳],
  [① 平，② 平，③ 涨], [#strong[失败信息的质量在下降]],
  [全平], [系统稳态],
)
#strong[第三行是最容易被忽略的一种]：基础设施没有变慢， 但 Agent 需要更多轮才能修好 ------ 这通常意味着 新加的规则给出的信息不够，或者失败被归到了错误的类别。

#strong[三条曲线，一张图。而数据已经在那儿了。]

== 三条出路
<sec-three-remedies>
控制论对"增益必须涨、但延迟降不下来"这个局面，给出三条路：

#strong[一、继续降延迟。] 这是这个仓库已经在走的路 ------ 稀疏测量、缓存复用、分片并行。 但这条路有下界：某些判定就是需要把程序跑起来。

#strong[二、加微分作用。] 也就是对误差的#strong[变化率]动作，而不是只对误差动作。 翻译成工程语言：#strong[在跑完整流水线之前，预判哪些改动会红，并分流处理。]

现在所有改动走的是同一条路径、同样的判定强度 ------ 这是#strong[定增益]。 而路径清单里已经有风险等级了，只是那个等级调的是"检查什么"， 不是"回路压多紧"。#strong[风险分级的增益调度]是这个框架直接给出、 而经验推不出来的下一步。

#strong[三、降增益。] 也就是少开一些 Agent。这条路在这里不太可能被选， 但它必须被列出来 ------ 因为如果前两条走不通，这就是唯一剩下的选项， 而且它比失稳好。

== 稀疏测量在代码里长什么样
<sec-sparse-impl>
"只测本次真正变化的子空间"这句话，落到实现上是一万两千多行代码。 值得看它在处理什么，因为#strong[它处理的大部分不是"怎么查依赖"， 而是"查不到的时候怎么办"。]

有一组测试专门在验证这件事，它构造了四种查询结果：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([查询的结果], [判定],),
  table.hline(),
  [成功，返回空], [#strong[接受]，空就是空],
  [#strong[失败，但产出了完整输出]], [#strong[接受输出]],
  [失败，没有输出], [#strong[报错]],
  [输出不是合法编码], [#strong[报错]],
)
第二行是这组测试的核心：#strong[一次退出码非零、但产出了完整结果的查询， 它的结果是被接受的。]

这看起来很奇怪，直到你意识到构建图查询在部分目标不可解析时 会返回非零退出码，#strong[但它对可解析的那部分给出的答案是正确的。]

而下一个测试的名字把这条纪律说清楚了： #strong["批量查询只接受完整的回退结果"] ------ 部分结果在批量场景下是不可接受的，因为你无法区分 "这个目标没有依赖者"和"这个目标没被查到"。

#strong[同一种失败，在两个场景下有两个不同的正确处理。] 而把它们区分开的，是"这次测量的完整性能不能被验证"。

#strong[这就是 #ref(<sec-sensor-faults>, supplement: [章节]) 讲的那个判别，出现在了测量的最底层。]

== 比较基线必须是确定的
<sec-baseline-determinism>
稀疏测量有一个前提，它比测量本身更基础： #strong["这次改了什么"必须有一个稳定的答案。]

基线一旦浮动，后面所有判定都跟着不稳 ------ 同一份代码， 两次运行可能得出不同的影响面，于是跑不同的测试，得出不同的结论。

实现上，基线的确定有一条明确的#strong[回退链]： 新分支推送时先尝试合并基点，再回退到默认分支。

#strong[回退链的存在本身就是一个设计决定。] 它意味着： "我算不出基线"不是一个可接受的终态， 系统必须给出一个确定的答案，哪怕是一个次优的答案。

而这和 #ref(<sec-cannot-judge>, supplement: [第]) 那条纪律并不矛盾 ------ 区别在于：#strong[基线是可以有合理默认值的，而判定不可以。] 算不出基线时退回默认分支，最坏的结果是测多了； 判不了却假装通过，最坏的结果是坏代码进了主干。

#strong[能安全回退的地方回退，不能的地方明确报"我判不了"] ------ 这个区分需要逐个场景做，而它是这套系统里做得最细的地方之一。

== 为什么控制论的语言值得借
<sec-why-borrow>
这一章借了一整套别的领域的词汇，值得说明为什么这不是装饰。

#strong[三个具体的收益：]

=== 一、它给了"同一个形状"一个名字
<sec-naming-shapes>
两堵墙"形状相同"这个观察，在第一章就有了。 #strong[但没有名字的观察无法被推演。]

有了"增益与延迟"这个名字之后， 可以直接问下一个问题：#strong[增益还在涨，延迟没变， 那么下一堵墙在哪？] ------ 而这个问题在没有名字的时候问不出来。

=== 二、它带来了一批现成的解
<sec-borrowed-solutions>
串级控制、死区、抗积分饱和、增益调度、观测器 ------ 这些都是别人花了几十年验证过的模式。

#strong[而这套系统独立撞出了其中的四个]（#ref(<sec-reinvention>, supplement: [第])）。 撞出来的和借来的效果一样，#strong[但撞出来要付事故的代价。]

对读者的价值是：#strong[剩下那些还没被撞出来的，可以直接拿。] #ref(<sec-three-remedies>, supplement: [第]) 里的增益调度、#ref(<sec-not-more-sensors>, supplement: [第]) 里的观测器， 都属于这一类。

=== 三、它划出了这套方法的理论边界
<sec-theoretical-boundary>
#ref(<sec-no-self-setpoint>, supplement: [第]) 那条"闭环系统不能生成自己的设定点"， 不是一个经验观察，#strong[是一个定理。]

而定理和经验的差别在于：#strong[定理告诉你不用再试了。]

一个团队如果不知道这条，可能会花很久去建一个 "能自己判断需求对不对"的系统 ------ 而那是不可能的， 不是因为技术不够，是因为范畴不对。

== 借来的语言也有它的局限
<sec-borrowing-limits>
诚实地说三条这个类比不成立的地方：

#strong[一、这里的"被控对象"会学习。] 经典控制论里，被控对象的动力学是固定的。 而模型会更新、提示词会变、Agent 会积累上下文 ------ #strong[这是一个时变系统，而时变系统的理论要复杂得多。]

#strong[二、这里的"误差"不是标量。] 控制论里误差是一个可以做减法的量。 而"这次产出和我想要的差多少"不是一个数， #strong[它是一个结构化的、多维的、部分不可比较的东西。]

#strong[三、这里没有传递函数。] 你没法写出"提示词变化 → 输出变化"的数学关系， 所以所有定量的控制设计方法在这里都用不上。

#strong[能借的只有定性的结论]：增益与延迟的关系、 前馈与反馈的分工、可观测性的必要条件、设定点必须在环外。

#strong[这四条都不需要传递函数就成立]，所以它们能过来。 而 PID 参数整定、根轨迹、频域分析那些，过不来。

#strong[知道哪些能借、哪些不能借，比借得多重要。]

== 三个可能的稳态
<sec-three-equilibria>
一个增益和延迟匹配的系统，会稳定在三种状态之一。 #strong[认出自己在哪一种，决定了下一步该做什么。]

=== 稳态一：判定受限
<sec-equilibrium-verdict>
#strong[特征]：流水线排队，Agent 在等结果。 #strong[瓶颈]：判定这一侧的带宽。 #strong[该做]：缩小测量范围、下沉判定、降延迟。

#strong[这是第一、二堵墙的状态]，也是这本书大部分内容针对的状态。

=== 稳态二：修正受限
<sec-equilibrium-correction>
#strong[特征]：判定很快返回，但改动要跑很多轮才能合入。 #strong[瓶颈]：Agent 理解失败并修正的能力。 #strong[该做]：改善失败信息的质量（#ref(<sec-delay-breakdown>, supplement: [第])）。

#strong[这是第三堵墙]，而它的特征是：加机器完全没用。

=== 稳态三：参考输入受限
<sec-equilibrium-setpoint>
#strong[特征]：产出又快又好，但"做什么"成了瓶颈。 #strong[瓶颈]：#ref(<sec-setpoint-outside>, supplement: [章节]) 那一章讲的东西。 #strong[该做]：这本书帮不上忙。

=== 怎么判断自己在哪一种
<sec-which-equilibrium>
用三个数（#ref(<sec-measure-the-loop>, supplement: [第])）：

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([测量延迟], [回路延迟], [振荡次数], [你在],),
  table.hline(),
  [#strong[高]], [高], [低], [稳态一],
  [低], [#strong[高]], [#strong[高]], [稳态二],
  [低], [低], [低], [稳态三（或者一切正常）],
)
#strong[第二行和第三行的区别是振荡次数]， 而这也是为什么那个数值得被单独采集 ------ #strong[它是区分"判定慢"和"信息差"的唯一指标。]

== 一个提醒：这些结论是定性的
<sec-qualitative-only>
#ref(<sec-borrowing-limits>, supplement: [第]) 讲过，能借来的只有定性结论。

所以这一章里所有的"增益""延迟""裕度"都是#strong[类比]， 不是可以被计算的量。#strong[没有传递函数，没有 PID 参数， 没有频域分析。]

#strong[而这不削弱它的实用性]，因为这一章给出的三个动作 ------量三个数、画一张图、判断自己在哪个稳态------ #strong[全都不需要定量的模型。]

它们需要的只是#strong[知道该看哪三个数]， 而这正是一个定性模型能提供的全部，也是它足够提供的。

== 这一章的可执行部分
<sec-gain-actionable>
不管你的规模多大，下面三个数今天就能量出来：

+ #strong[你的内环延迟]（不需要跑程序的检查，从提交到出结论）
+ #strong[你的外环延迟]（需要跑程序的检查）
+ #strong[你的振荡次数]（一个改动平均跑几次流水线才合入）

第一个和第二个的比值告诉你有没有串级。 第三个的趋势告诉你增益和延迟的匹配还剩多少余量。

#strong[如果第三个数在涨，那么加 Agent 不会提高产出，只会提高返工。]

#block[
#callout(
body: 
[
本章用控制论的语言重新表述了一套已经存在的实践。 需要说清楚的是：这套实践是先建成的，控制论的解释是后加的。

这不削弱解释的价值 ------ 它的价值恰恰在于#strong[预测那些还没撞过的墙]： 振荡次数、增益调度、稳定裕度，这三样都是经验撞不出来的， 因为它们要求你在故障发生之前就推理系统的动态。

]
, 
title: 
[
一处诚实
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
== 这一章的词汇表
<sec-gain-vocabulary>
为了方便回查，把这一章引入的控制论概念列一遍， 每个配一句"在这里它是什么"：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([概念], [在这里是什么],),
  table.hline(),
  [增益], [Agent 的吞吐 ------ 单位时间施加多少修正],
  [回路延迟], [从改动产生到判定回到手里的时间],
  [稀疏测量], [只测本次真正变化的那个子空间],
  [串级控制], [快内环（结构检查）+ 慢外环（端到端）],
  [相位裕度], [距离"返工振荡"还剩多少余量],
  [微分作用], [对误差的变化率动作 ------ 这里是"预判哪些会红"],
  [增益调度], [按风险等级调整回路的压紧程度],
  [采样周期], [周期任务多久跑一轮],
)
#strong[八个概念，其中五个已经在这套系统里有对应的实现， 三个（微分作用、增益调度、稳定裕度的测量）还没有。]

而这个比例本身说明了一件事：#strong[一个认真做闭环的人 会撞出大部分标准解，但撞不出那些需要"在故障发生前推理动态"的。]

#ref(<sec-why-borrow>, supplement: [第]) 讲过这就是借这套语言的第三个理由。

== 一个还没被撞过的墙的预测
<sec-predicted-wall>
#ref(<sec-third-wall>, supplement: [第]) 预测了第三堵墙（失败信息的质量）。 这里再往前推一步，因为#strong[这个框架允许推。]

#strong[假设第三堵墙也被解决了]：失败信息足够好， Agent 平均一轮就能修好。那时候的瓶颈在哪？

按增益和延迟的框架：#strong[延迟已经压到了测量本身的物理下界] （有些判定就是需要把程序跑起来）。

#strong[而增益还能涨。]

于是会出现一个新的状态：#strong[修正速率超过了"最快可能的判定速率"。]

这时候唯一剩下的路是 #ref(<sec-three-remedies>, supplement: [第]) 的第三条 ------ #strong[降增益]。而它的具体形态不是"少开 Agent"， 更可能是#strong[让 Agent 在提交之前自己做更多的判定]：

#quote(block: true)[
#strong[把一部分判定从"提交后"移到"提交前"] ------ 也就是把反馈变成 Agent 自己回路里的一环， 而不是外部系统的一环。
]

#strong[这在控制里叫内模控制]：控制器内部包含一个被控对象的模型， 用它来预测输出，从而减少对外部反馈的依赖。

而它的工程形态已经存在了：#strong[让 Agent 在本地跑同一套检查] （#ref(<sec-local-and-ci>, supplement: [第])）。只不过现在它是"可选的"， 而在那个未来它会变成"必须的"。

#strong[这个预测的价值不在于它对不对， 在于它说明了这个框架能生成可检验的预测] ------ 而这正是 #ref(<sec-model-cost>, supplement: [第]) 里那句"一个能预测的模型 比一个能解释的模型值钱"的意思。

== 这一章能被压成的三句话
<sec-gain-three-lines>
#strong[一、增益是 Agent 的吞吐，延迟是判定回到手里的时间， 而在有延迟的系统里提高增益会失稳。]

这就是两堵墙的统一解释（#ref(<sec-walls-restated>, supplement: [第])）， #strong[而它还预测了第三堵墙]（#ref(<sec-third-wall>, supplement: [第])）。

#strong[二、测试金字塔是一个串级控制结构，而它有一个定量前提。]

内环必须显著快于外环。#strong[如果你的静态检查和端到端测试 耗时在同一个量级，那你没有串级，只有两个并联的慢环] （#ref(<sec-cascade>, supplement: [第])）。

#strong[三、回路里最大的一块延迟，可能不在基础设施上。]

1.4 小时的中位转绿时间，减去约半小时的流水线时间 ------ #strong[剩下的一个多小时是 Agent 在读失败、理解、修改] （#ref(<sec-delay-breakdown>, supplement: [第])）。

#strong[而这意味着改善失败信息的收益， 可能高于再买一批机器。]

== 一个可以立刻画的图
<sec-one-chart>
如果这一章只做一件事，做这个：

#Skylighting(([#NormalTok("横轴：周");],
[#NormalTok("三条线：");],
[#NormalTok("  ① 测量延迟   （提交 → 第一次判定返回）");],
[#NormalTok("  ② 回路延迟   （第一次红灯 → 最终转绿）");],
[#NormalTok("  ③ 振荡次数   （每个改动跑了几条流水线）");],));
#strong[三条线，一张图，数据全在流水线记录里。]

而看的不是绝对值，是#strong[三条线之间的关系] （#ref(<sec-measure-the-loop>, supplement: [第]) 那张表）------ #strong[它会告诉你现在的瓶颈在哪一侧， 而那决定了你下一笔投入该往哪放。]

#strong[这是这一章唯一的行动项，成本是一天。]

= 传感器故障
<传感器故障>
= 传感器故障
<sec-sensor-faults>
#ref(<sec-three-failures>, supplement: [章节]) 讲了退出码为什么要分三种。这一章给那个决定一个正式的名字， 然后用这个名字找出另外三样已经在跑、但没有被识别成同一类的东西。

== 控制工程里最实际的问题之一
<sec-plant-vs-sensor>
在一个闭环控制系统里，控制器看到的不是被控对象本身， 而是#strong[传感器对被控对象的读数]。这两者不是一回事， 而它们不一致的时候会发生一件很糟的事情。

如果传感器坏了、读数归零，一个朴素的控制器会认为误差极大， 于是全力施加修正 ------ #strong[为了消除一个不存在的误差，把被控对象推向毁灭。]

这不是理论问题。飞机的空速管结冰、锅炉的热电偶断路、 反应堆的液位计卡死 ------ 每一类都有过真实的事故， 而事故的形态几乎总是一样的：#strong[控制器工作得非常"努力"， 努力的方向完全错误，而所有人都在看着一个假的读数。]

翻译到这里：

#quote(block: true)[
如果 CI 因为基建故障而红，而 Agent 把这个红灯当成"代码错了"， 它会去改本来正确的代码 ------ 而且会改得很有信心， 因为它手里确实握着一个红灯。
]

#ref(<sec-infra-share>, supplement: [第]) 里那个数字，现在可以重新读一遍： #strong[最近五百次失败里，一百一十九次是基建故障 ------ 23.8%。]

在一个真实的控制系统里，如果四分之一的传感器读数不可信， 而控制器不做判别 ------ #strong[那这个控制器的表现会比开环还差。] 开环至少不会主动往错的方向推。

这是一个可以量化的论断，不是修辞。而它解释了一个很多团队都有、 但归因错误的现象：#strong[引入 Agent 之后，某些模块的代码质量不升反降。] 通常的解释是"Agent 写得不好"。更可能的解释是： 那些模块恰好在基建故障率最高的那一层（见前面那张表：构建阶段 37%）， 于是 Agent 反复在正确的代码上做无效修改。

== 四种传感器故障管理，全都已经在跑
<sec-four-mechanisms>
有意思的地方在这里：这套系统里已经有四种独立的传感器故障管理机制， #strong[是各自撞出来的，撞完之后正好凑成了一个完整的栈。]

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([已有机制], [控制工程里的名字], [它防住什么],),
  table.hline(),
  [退出码 0/1/2 三分], [#strong[对象故障与传感器故障的判别]], [在不可测的环境里动作],
  [#NormalTok("sentinel_min"); 哨兵下限], [#strong[传感器量程 / 合理性校验]], [一个不可能的读数被当真],
  [生成物对拍测试], [#strong[解析冗余]], [单一测量通道的静默漂移],
  [变异验证], [#strong[主动注入已知故障标定传感器]], [一个永远不会红的测试被当成保护],
)
四种的原理各不相同，值得逐条看，因为#strong[它们对付的是四种不同的传感器失效方式。]

=== 一、判别：分清是谁坏了
<sec-discrimination>
这是最基本的一条，也是 #ref(<sec-three-failures>, supplement: [章节]) 讲过的。核心是那句：

#quote(block: true)[
判不了 = 不通过，而且要说清楚"我判不了"， 既不假装通过，也不报成对象的错。
]

在代码里它是一个三态枚举加一个匹配臂顺序。在控制里它叫 #strong[故障检测与隔离] ------ 先检测出异常，再判断异常来自哪个部件。

=== 二、量程校验：这个读数可能吗
<sec-range-check>
哨兵下限做的事情是：#strong[为每一条规则声明一个"它至少应该看到多少个事实"的下界。]

如果某一天匹配数掉到下界以下，更可能的解释是扫描逻辑坏了， 而不是代码一夜之间变干净了。

这在传感器工程里是最标准的一道防线：一个温度传感器读出零下三百度， 你不会认为房间变冷了，你会认为传感器断了。#strong[因为那个读数不在物理可能的范围内。]

而这里的实现有一个细节值得学（#ref(<sec-sentinel>, supplement: [第]) 讲过，这里从控制的角度再看一遍）： 哨兵的类型是 #NormalTok("NonZeroUsize");，而且是#strong[必填]。

也就是说，#strong[你没法写一条不带量程校验的规则，也没法把校验关掉。] 在传感器工程里，这相当于规定"每一个通道都必须声明它的有效量程"------ 而这恰恰是最容易在赶工期时被省掉的东西。

=== 三、解析冗余：用第二个通道验第一个
<sec-analytical-redundancy>
当你只有一个传感器时，你没法知道它对不对。经典的解法是装两个 ------ 但那很贵。控制工程里更常用的是#strong[解析冗余]： 用一个模型从别的可测量算出这个量应该是多少，然后和实测值比。

这套系统里有一个纯粹的例子。构建规则里有一条测试，它的文档字符串只有一句：

#quote(block: true)[
Fails when a checked-in API client differs from its Bazel output. （当签入的 API 客户端与它的构建产物不一致时失败。）
]

签入仓库的生成代码是"实测值"，构建系统当场重新生成的是"模型算出来的值"。 两者必须一致。

#strong[它防的是这样一种失效：有人手改了生成物，但源声明没动。] 这种情况下，代码能编译、测试能通过、行为可能也对 ------ #strong[唯一坏掉的是"生成物由声明派生"这条不变量，而这条不变量坏了之后， 下一次重新生成会把手改的部分静默地抹掉。]

单一测量通道永远发现不了这件事，因为签入的代码本身没有任何异常。 只有第二个独立通道能。

=== 四、机内自检：主动注入已知故障
<sec-bite>
前三条都是被动的 ------ 它们等异常出现。第四条是主动的。

在航空电子里这叫 #strong[BITE（机内自检设备）]：系统定期给自己注入一个已知的信号， 然后检查传感器有没有按预期反应。#strong[如果注入了故障而传感器毫无反应， 那么这个传感器已经失效了，尽管它一直在输出看起来正常的读数。]

这套系统里对应的是两件事：

#strong[变异验证] ------ 把那个修复拿掉，回归测试必须重新变红。 如果它不变红，说明这条测试守的根本不是行为。这是给测试注入一个已知故障， 看它响不响。

#strong[规则的契约测试] ------ 检查器的测试目录里，每一条规则都有一个配对的 #NormalTok("*_tests"); 模块，里面#strong[故意造出违规的输入]，验证检查器确实会报错。

这两件事的共同结构是：#strong[一个从来不会报错的检查器， 和一个不存在的检查器，是同一个东西。] 而你没法通过观察它的正常输出 来区分这两者 ------ 只能主动注入。

== 四种机制对应四种失效方式
<sec-four-failure-modes>
把它们排在一起，能看出这个栈为什么是完整的：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([传感器的失效方式], [对应机制],),
  table.hline(),
  [传感器#strong[不可用]（我读不到）], [退出码 2],
  [传感器#strong[读数不合理]（我读到了，但不可能）], [哨兵下限],
  [传感器#strong[慢慢漂移]（读数看起来正常，但和真相脱节）], [解析冗余],
  [传感器#strong[完全失灵却仍在输出]（永远读同一个正常值）], [机内自检],
)
#strong[第四种是最危险的，因为它是唯一一种从输出上完全看不出来的。] 而它也正是形状 A 在检查器这一层的形态。

大部分做 Agent 系统的人，这四样一个都没有 ------ 他们只有一个布尔值。 而这个栈的存在说明了一件事：#strong[它们不是奢侈品，是任何一个认真做闭环的人 迟早会重新发明的东西。]

== fail closed 与 fail open
<sec-fail-closed>
一个系统在传感器失效时的默认行为，暴露了它真正的设计意图。

绝大多数系统的默认是 #strong[fail open]：检查挂了就跳过， 理由是"不能因为工具坏了就挡住所有人"。

这个默认值在人的世界里是合理的 ------ #strong[人会记得回来补。] 一个被跳过的检查会留在某个人的心里，他会在合并前多看两眼。

#strong[在 Agent 的世界里它是错的，因为没有人会记得。] 一个被跳过的检查，和一个从来不存在的检查，在下一次运行时是同一个东西。 而且它比"从来不存在"更糟，因为#strong[你以为它在]。

所以这套系统的四道证据门全部 fail closed：判不了 = 不通过。

== 哨兵的局限
<sec-sentinel-limits>
这一节是本书对源系统提出的第二条改进建议。

哨兵下限是一个#strong[手写的绝对常量]。类型系统保证了它必填、非零， 这堵死了最省事的绕过路径，但没有解决一个更慢性的问题：

#strong[仓库在长，扫描面在变。] 一条规则今天扫 9,046 处，一年后可能扫 15,000 处。 那个写死的下界什么时候调？谁调？根据什么调？

而只要它需要被手工调整，就存在一条路径：某天一条规则因为哨兵失败而挡住了人， 最快的解法是把下界调低，#strong[而这个动作和"修复一个过时的阈值"在 diff 上长得一模一样。]

更稳的形态是#strong[相对变化率]而不是绝对值：

#quote(block: true)[
这次的扫描数相对上一个版本掉了超过 X%，就判传感器故障。
]

因为真正的信号是#strong[突变]，不是"低于某个数"。一个逐渐增长的仓库里， 扫描数应该是缓慢单调上升的；任何一次断崖式下跌都值得怀疑， 不管它跌到了多少。

这个改法有一个额外的好处：#strong[它不需要任何人去维护阈值] ------ 基线由上一次运行自己提供。这正是这套系统在别处反复用的那条原则 （证据绑定版本），只是还没有用在哨兵上。

== 为什么这四种机制会被独立地重新发明
<sec-reinvention>
这一节讲一个值得注意的现象。

这套系统里的四种传感器故障管理，#strong[没有一种是从控制工程里学来的]。 它们各自是从一次具体的失败里长出来的：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([机制], [逼出它的那次失败],),
  table.hline(),
  [退出码三分], [大量红灯其实是基建故障，而 Agent 在改正确的代码],
  [哨兵下限], [一条规则的扫描范围因为配置变化而缩小，静默失效],
  [生成物对拍], [有人手改了生成物，下次重新生成时被静默抹掉],
  [变异验证], [测试通过，但拿掉修复它照样通过],
)
#strong[四条不同的路径，走到了同一个地方。]

这不是巧合。它说明：#strong[一旦你开始认真依赖某个测量， 你就必然会遇到"测量本身不可信"这个问题] ------ 而这个问题的解法空间不大，所以不同的人会收敛到相似的答案。

这个观察有一个实际用途：#strong[如果你的系统里一个这样的机制都没有， 那不是因为你不需要，是因为你还没有认真依赖过任何一个测量。]

而"认真依赖"的标志很具体：#strong[你会不会因为某个检查是绿的， 就跳过人工确认？] 如果会，那你已经在依赖它了， 而它的自检机制现在还是空的。

== 传感器故障管理的成本
<sec-sensor-cost>
诚实地说，这四种机制不是免费的：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([机制], [成本],),
  table.hline(),
  [退出码三分], [每接一种新工具都要判断它的失败该归哪一类],
  [哨兵下限], [每条规则多一个必须维护的常量],
  [解析冗余], [一条额外的测试，以及生成器要能被独立调用],
  [机内自检], [每次修 bug 多一步，每条规则多一个配对的测试],
)
#strong[其中第二条的成本是持续的]，而且 #ref(<sec-sentinel-limits>, supplement: [第]) 讲过它还没有被很好地解决。

但这些成本有一个共同特点：#strong[它们都在建设时付，不在故障时付。]

而它们避免的那类失败，代价是在故障时付的 ------ 而且是在#strong[你不知道自己在故障]的那段时间里持续地付。

#strong[这个成本结构决定了它们值不值：如果你的系统会活很久，值； 如果它三个月后就没了，不值。]

== 传感器故障和形状 A 是同一件事
<sec-sensor-is-shape-a>
值得把这两个概念对齐一次，因为它们在书里是分开出现的。

#strong[形状 A]（#ref(<sec-shape-a>, supplement: [第])）说的是：探针和被测对象之间 有一条未被验证的因果假设。

#strong[传感器故障]说的是：测量本身不可信。

#strong[这是同一件事的两种表述] ------ 一个从现象说，一个从机制说。

而合起来之后，它们给出了一个更完整的图景：

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([未被验证的假设], [它对应哪种传感器失效], [对应的机制],),
  table.hline(),
  ["能读 ⇒ 能写"], [测的是另一个量], [#strong[需要换测量对象]，四种机制都救不了],
  ["工具跑完 ⇒ 检查执行了"], [测量没有发生], [量程校验（执行数不为零）],
  ["签入的 = 生成的"], [测量慢慢漂移], [解析冗余],
  ["测试在 ⇒ 行为被守住"], [测量失灵但仍在输出], [机内自检],
)
#strong[第一行是最难的]，因为它不是"传感器坏了"， 是#strong["传感器测的从来就不是那个量"]。

而这类问题没有自动化的解法 ------ 它需要一次人的检查： #strong[坐下来，写清楚这个探针实际在测什么， 再写清楚你想知道什么，然后看这两句话一不一样。]

这个练习看起来幼稚，但它是唯一能发现这类问题的方法。 而且做完之后，通常会有一两处让人不安的发现。

== 一个跨领域的对照
<sec-cross-domain>
这四种机制在别的工程领域里都有成熟的对应物， 值得列出来，因为#strong[知道它们有名字，意味着可以去查那个领域的经验]：

#table(
  columns: 4,
  align: (auto,auto,auto,auto,),
  table.header([这里的机制], [航空], [过程控制], [分布式系统],),
  table.hline(),
  [退出码三分], [故障检测与隔离], [传感器有效性判别], [熔断的半开状态],
  [哨兵下限], [量程与合理性检查], [报警死区与量程], [异常检测的下界],
  [解析冗余], [解析余度], [软测量交叉校验], [读修复 / 校验和],
  [机内自检], [机内自检设备], [定期标定], [混沌工程],
)
#strong[最后一列的最后一行值得注意]：混沌工程和机内自检是同一个思想 ------ 主动注入已知故障，验证系统的响应符合预期。

而它们在这套系统里的形态（变异验证、故意造违规变更） 比通常意义上的混沌工程#strong[便宜得多]，因为注入的对象是测试和检查， 不是生产系统。

#strong[这是一条被低估的路径：在验证层做混沌工程， 成本低一个数量级，而它验证的正是你最依赖的那个东西。]

== 什么样的传感器最不该被信任
<sec-least-trustworthy>
给一个排序，按"它坏了却不被发现"的概率从高到低：

#strong[第一名：那些从来不失败的。]

一个跑了半年、一次都没有红过的检查，有两种可能： 它守的东西从来没被违反过，或者#strong[它已经不工作了]。

#strong[而这两种在输出上完全无法区分。]

这就是机内自检（#ref(<sec-bite>, supplement: [第])）存在的全部理由， 也是为什么这套系统里每条规则都有配对的"故意造违规"测试。

#strong[第二名：那些依赖外部服务的。]

一个需要调用外部 API 才能完成的检查， 在那个 API 变慢、返回格式变化、或者悄悄降级时会失效。 #strong[而这些变化通常不会导致明显的错误，只会导致结果不准。]

#strong[第三名：那些配置复杂的。]

配置越多，"配错了但没报错"的可能性越大 ------ 而这正是形状 D（#ref(<sec-shape-d>, supplement: [第])）。

#strong[第四名：那些最近改过的。]

任何一次对检查器自身的修改，都可能引入静默失效。 而检查器的修改#strong[通常不会被同等严格地测试] ------ 因为"测试检查器"这件事本身就不在大部分人的心智模型里。

== 一个跨越三层的例子
<sec-three-layer-example>
用一个具体的场景，展示四种机制怎么配合。

#strong[场景]：一条检查"所有对外接口都有权限校验"的规则。

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([层], [机制], [它防住什么],),
  table.hline(),
  [判别], [规则依赖的接口清单读不出来时，报"判不了"], [在不完整的清单上给出通过],
  [量程], [断言扫描到的接口数不少于某个下界], [清单解析出问题，只扫到三个接口],
  [冗余], [从两个来源（源码扫描 + 路由注册表）各算一遍接口数，对比], [某一个来源开始漏],
  [自检], [测试里故意加一个无权限校验的接口，验证规则会报错], [规则的匹配逻辑失效],
)
#strong[四层里，第三层最容易被省掉，而它防的是最隐蔽的一种失效。]

因为源码扫描和路由注册表#strong[理论上应该给出同一个数]， 而当它们不一致时，说明其中一个的世界观已经过时了 ------ #strong[而你不知道是哪一个。]

#strong["不知道是哪一个"本身就是一个足够的告警]： 它意味着你对这个系统的理解有一处错误， 而这个错误在别的地方也可能造成影响。

== 传感器故障管理的一条元原则
<sec-meta-principle>
把四种机制抽象一层，它们遵循同一条原则：

#quote(block: true)[
#strong[任何一个你依赖的判断，都必须有一个独立于它的方式来验证它还活着。]
]

"独立于它"是关键。

- 判别：用#strong[退出码的语义]来验证，而不是用它的输出内容
- 量程：用#strong[工作量]来验证，而不是用它的结论
- 冗余：用#strong[第二个通道]来验证
- 自检：用#strong[已知的输入]来验证

#strong[四种都在绕开被验证对象自己的说法。]

而这条元原则可以直接推广到这本书之外： 任何一个"它说没问题"的东西 ------ 一个监控、一个健康检查、 一个自动化任务、一份报表 ------ #strong[都需要一个不依赖它自己说法的验证方式。]

== 给读者的自检
<sec-sensor-self-check>
对你系统里的每一道检查，问一个问题：

#quote(block: true)[
#strong[它自己坏了的时候，会表现成通过还是失败？]
]

如果答案是"通过"，你有一个#strong[静默的传感器故障] ------ 它会在你最需要它的那天让你以为一切正常。

把你的检查列出来，逐个填这张表：

#table(
  columns: (20%, 20%, 20%, 20%, 20%),
  align: (auto,auto,auto,auto,auto,),
  table.header([检查], [它坏了会怎样], [有没有量程校验], [有没有第二通道], [有没有主动自检],),
  table.hline(),
  [], [], [], [], [],
)
大部分人第一次填完之后会发现：#strong[绝大多数检查在坏掉的时候会表现成"通过"]， 而且没有任何一列有勾。

这不是什么灾难 ------ 这只是说明这些检查此前从来没有被当成传感器看待过。 而只要开始这么看，前三列都能在一天之内补上。

== 传感器故障管理的投入顺序
<sec-sensor-order>
四种机制不必一次全建。按"成本 ÷ 收益"排：

#strong[第一：量程校验（哨兵）。] 成本最低（打印一个已有的数 + 一个下界比较）， 覆盖面最广（它对任何一种"扫描面异常缩小"都有效）。

#strong[第二：判别（退出码三分）。] 成本半天，而它防的是最贵的一类错误 ------ Agent 在不可测的环境里改正确的代码。

#strong[第三：机内自检（变异验证）。] 手工版本成本为零（修 bug 时先让测试红一次）。 自动化版本很贵（#ref(<sec-mutation-hard>, supplement: [第])）， #strong[所以只在关键路径上做。]

#strong[第四：解析冗余。] 成本最高（需要第二个独立通道）， #strong[但它是唯一能发现"慢慢漂移"的机制]（#ref(<sec-four-failure-modes>, supplement: [第])）。

=== 一个判断该不该建第四种的标准
<sec-when-redundancy>
解析冗余不是每个系统都需要。判据是：

#quote(block: true)[
#strong[这个测量的结果，如果慢慢地偏离真相， 会有别的东西告诉你吗？]
]

- 会 → 不需要冗余
- #strong[不会 → 需要]

而"生成物和它的源声明"正好是"不会"的典型： #strong[手改一个生成物，代码能编译、测试能过、行为可能也对] ------ #strong[唯一坏掉的是那条不变量，而没有别的东西看着它。]

== 这一章和第三部的关系
<sec-sensor-and-part-three>
最后把这一章的位置说清楚。

第三部讲的三层判定，#strong[全都是传感器]。 而这一章讲的是：#strong[传感器自己会坏，而且坏的时候通常不报错。]

#strong[所以这一章不是第三部的补充，是它的前提。]

一个没有传感器故障管理的判定系统，它的所有结论 都带着一个未被验证的假设：#strong["我的测量还在工作。"]

而这个假设在 #ref(<sec-shape-a>, supplement: [第]) 那张表里已经被证伪了五次 ------ 在五个不同的层上。

#strong[这就是为什么这一章值得单独存在， 而且值得放在讲完三层判定之后] ------ #strong[你得先有测量，才谈得上测量的可信度。]

= 观测器：测不到的状态怎么管
<观测器测不到的状态怎么管>
= 观测器
<sec-observer>
#ref(<sec-signing-failure>, supplement: [第]) 留下了一个没解决的问题： 一条定时任务挂了四个月，没有人发现，因为它坏了不产生任何可见后果。

这一章讲这个缺口该怎么补。而答案#strong[不是"加监控"]。

== 测不到的状态，控制不了
<sec-observability>
控制论里有一条硬结论，它不是经验之谈，是一个定理：

#quote(block: true)[
#strong[一个你无法观测的状态，你无法控制。]
]

"无法观测"有精确的含义：不是"没装传感器"， 而是#strong[从你能测到的全部输出，无论怎么组合、观察多久， 都推不出这个状态的值。]

翻译过来就是那句话：#strong[一个不产生判定的动作，坏了你不会知道。]

而这句话还有一个#strong[没被说出来的下半句]：

#quote(block: true)[
#strong[不可观测的子系统同时也是不可控的 ------ 所以你对它的任何"修复"，本身也是不可验证的。]
]

那个挂了四个月的崩溃后来被修了。但在没有观测器的情况下， #strong[没有任何人能知道它会不会再挂四个月。] 修复和不修复， 在可观测的世界里长得一模一样。

这一点比"没发现"更严重。没发现只是一次损失， #strong[而不可验证意味着这个损失会重复。]

== 三个实例，同一个缺陷
<sec-three-blind-spots>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([实例], [状态], [为什么测不到],),
  table.hline(),
  [签名自动刷新挂了四个月], [任务在不在工作], [它失败不产生红灯],
  [28 条工作流里 5 条从未运行], [任务有没有被触发], [#strong[它根本没有状态]],
  [磁盘容量问题重复五次], [分区水位], [没有人测量它],
)
三个实例的共同点：#strong[它们都不产生红灯。]

代码有三层判定盯着，每一次违反都会立刻变成一个信号。 而这些东西一层都没有 ------ #strong[它们是给 Agent 生产确定性的东西， 自己却在确定性覆盖之外。]

第二个实例尤其值得看。"从未运行"这个状态#strong[连一条失败记录都不会产生] ------ 监控作业状态永远发现不了它，因为它根本没有作业实例可供监控。 你只能通过#strong[它应该产生而没有产生的东西]来发现它。

而这正好就是观测器的定义。

== 标准答案不是"加更多传感器"
<sec-not-more-sensors>
面对"状态测不到"，工程上的第一反应总是"那就加个监控"。

控制论给的答案不是这个。它的答案是：#strong[建一个观测器。]

#quote(block: true)[
用一个#strong[模型]，加上你#strong[能测到的]量， 去#strong[估计]你测不到的状态。
]

这个东西在控制里有具体的名字（状态观测器、卡尔曼滤波器）， 但它的核心思想很朴素：#strong[如果这个状态真的在影响世界， 那它一定在某个你能测到的地方留下了痕迹 ------ 去测那个痕迹。]

=== 用在那个签名任务上
<sec-signing-observer>
具体到那条定时任务：

#strong[你不需要监控这个任务本身。]

你已经有它应该产生的效果的模型 ------ #strong[刷新成功意味着证书的到期日往前移。] 而那些证书是#strong[签入仓库的]，状态就在手边，一条命令就能读出来。

于是观测器长这样：

#Skylighting(([#NormalTok("最早的那份证书距离到期还有多少天？");],
[#NormalTok("  > 阈值 → 刷新机制在工作");],
[#NormalTok("  < 阈值 → 刷新机制没在工作（不管那个任务报告了什么）");],));
#strong[从效果估计健康度，比监控作业本身更鲁棒]，原因有三条：

#strong[一、一个作业可以"成功"却什么都没干。] 那 5 条从未运行的工作流是极端情况，但"跑完了、返回成功、 实际没处理任何东西"是一个更常见、更隐蔽的形态。

#strong[二、观测器不关心实现。] 哪天这个刷新换了一种做法、 换了一个工具、拆成了三个任务，观测器不用改 ------ 因为它测的是效果。

#strong[三、观测器覆盖你没想到的失效方式。] 监控作业状态只能发现 "作业失败了"这一种；而观测证书到期日能发现所有导致证书没被刷新的原因， 包括你从来没想过的那些。

=== 用在磁盘那五次上
<sec-disk-observer>
这是观测器价值的最好例证。

五次事故的#strong[表象各不相同]：登录失败、CI 任务失败、全站错误、 监控面板 500、代理 502。

#strong[根因也各不相同]：缓存文件损坏、容器日志、日志插件缓存、 没配保留期、保留期配了但和容量不匹配。

#strong[但它们的可观测量是同一个：分区水位。]

这就是观测器的价值 ------ #strong[它不要求你预测所有的失败模式， 只要求你找到一个所有失败模式都会经过的可测量量。]

五个不同的根因，一个观测器全覆盖。而且它还能覆盖第六个、 第七个你还没遇到的根因，只要它们同样表现为磁盘满。

=== 构造一个观测器的通用方法
<sec-observer-recipe>
三步，任何组件都适用：

#strong[第一步：写下这个组件"在正常工作时，世界上会有什么不同"。]

不是"它会返回成功"，而是"外部世界的哪个可观测量会改变"。 如果你写不出来 ------ 那么这个组件可能本来就没在做事， 这个发现本身就值回票价了。

#strong[第二步：找到那个不同里，可以被便宜地测量的部分。]

便宜很重要。一个需要跑一小时才能算出来的观测器不会被跑。

#strong[第三步：断言它。断言效果，不是断言执行。]

#strong[这三步的顺序不能换。] 大部分人从第三步开始 （"我们给这个任务加个告警吧"），于是断言的永远是执行。

== 为什么这不叫"加监控"
<sec-not-monitoring>
区别不是措辞。

#strong[监控]回答的是"这个组件现在怎么样"，它的输出是一个仪表盘。 #strong[观测器]回答的是"这个我看不见的状态现在是多少"，它的输出是一个估计值 ------ #strong[而估计值可以被断言。]

这个区别在实践中的差距是：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([], [监控], [观测器],),
  table.hline(),
  [输出], [面板上的一条曲线], [一个可以进 #NormalTok("if"); 的数],
  [谁消费], [人，主动去看], [#strong[机器，自动判定]],
  [组件换实现时], [要跟着改], [不用改],
  [覆盖未预见的失效], [不覆盖], [覆盖],
)
#strong[而最要紧的是"谁消费"那一行。]

== 没人看的看板等于没有判定
<sec-dashboard-nobody-reads>
这一节是这一章、也是这本书对单人和小团队最重要的一条建议。

需要被注意的东西在快速增长：28 条工作流、23 条规则、20 份路径清单、 45 份自动化配置、6 条检查通道、260 个工作区。

#strong[而注意力是常数。]

所以正确的设计目标#strong[不是"增加监控面"]。增加监控面在注意力恒定的前提下， 等于降低每一块的被注意概率 ------ 这和 #ref(<sec-always-on>, supplement: [第]) 讲的 常驻文件变长是同一个机制。

正确的目标是：

#quote(block: true)[
#strong[让不需要注意的东西不出现在注意力里， 让需要注意的东西主动找上门。]
]

具体到那 28 条定时任务，正确的补法不是加一块面板，是：

#quote(block: true)[
#strong[任何连续失败 N 次的定时任务，直接开一个改动请求。]
]

这样做的理由是：#strong[改动请求是这个系统里已经有判定覆盖的东西。] 它会进队列、会被看到、会有人（或 Agent）去处理， 因为整个工作流已经围绕它建起来了。

而一块新面板不进任何队列。#strong[它需要一个新的习惯来消费， 而习惯是这个系统里最不可靠的部件。]

#strong[一个信号的价值，取决于它汇入的那条已有的处理流。] 这条原则可以推广：给一个新信号找归宿时， 不要问"怎么让人看到它"，要问"它能不能变成一个已经有人处理的东西"。

== 这条缺口现在有多大
<sec-gap-size>
诚实地量一下。

#strong[有判定覆盖的]：约 310 万行代码，三层检查，四道证据门， 每一次改动都被扫描。

#strong[没有判定覆盖的]：28 条工作流、近四个月 18 万次执行、 以及它们背后的全部基础设施。

#strong[后者是前者赖以运行的地基。]

这不是一个小缺口，它是这套系统目前最明显的一处， 而且它有一个很坏的性质：#strong[因为它不可观测，所以它也不可估量] ------ 上面这段话里唯一可靠的数字是"18 万次执行"， 而"其中有多少是无效的"这个问题，现在答不上来。

== 观测器和判定的关系
<sec-observer-and-verdict>
这一章讲的观测器，和前面三层判定是什么关系？

#strong[观测器是把"不可判定的东西"变成"可判定的东西"的那一步。]

前三层判定都有一个前提：#strong[被判定的对象是可观测的。] 一次代码改动是可观测的 ------ 它有 diff，有构建产物，有测试结果。 所以判定可以直接施加在它上面。

而一个定时任务的健康度不可观测。#strong[所以它不是"缺一层判定"， 是"判定的前提不成立"。]

这个区分决定了修法：

- 缺判定 → 加一道检查
- #strong[缺可观测性 → 先建观测器，再加检查]

而顺序不能反。在一个不可观测的状态上加检查， 你只能检查那些能测到的东西 ------ 也就是作业本身的状态 ------ #strong[而那正好是最不可靠的那个信号]（一个作业可以成功却什么都没干）。

== 三个层次的可观测性
<sec-observability-levels>
不是所有"看不见"都是同一种看不见。分三层，修法完全不同：

#strong[第一层：能测，但没人测。] 最简单的一种。分区水位属于这一类 ------ 数据一直在那儿， 一条命令就能读，只是没有人去读。 #strong[修法：读它，并且断言它。]

#strong[第二层：测不到，但效果可测。] 定时任务的健康度属于这一类。任务本身的成功与否不可信， 但它的效果（证书到期日）是可测的。 #strong[修法：建观测器 ------ 测效果，不测执行。]

#strong[第三层：连效果都不可测。] 比如"这个功能到底有没有用户在用"， 如果你没有埋点，那么它在任何意义上都不可观测。 #strong[修法：这不是观测器能解决的，得先建测量本身。]

#strong[大部分团队以为自己在第三层，实际上在第一层。]

这个误判很常见，因为"我们缺监控"听起来比"我们没去读已经有的数据" 更像一个正当的理由。而实际检查一遍通常会发现： #strong[需要的数据大多已经存在，只是从来没有人把它接进任何一条判定。]

== 一个反例：观测器也会骗人
<sec-observer-lies>
最后一句诚实的话。

观测器是一个#strong[模型加测量]的组合，而模型可能是错的。

如果你用"证书到期日"作为"刷新机制健康"的观测器， 那么你隐含地假设了：#strong[只有那个刷新机制会改变证书到期日。]

如果有人手动刷新过一次，观测器会显示健康 ------ 而机制仍然是坏的。

#strong[所以观测器本身也需要 #ref(<sec-bite>, supplement: [第]) 那种主动自检]： 偶尔停掉那个机制，看观测量会不会如期恶化。

这在生产系统里通常做不到（没人愿意故意让证书过期）， 但它至少应该被#strong[知道] ------ 一个建立在未经验证的模型上的观测器， 提供的是"很可能健康"，不是"健康"。

#strong[而这个区别在写进判定的那一刻会消失] ------ 因为判定的输出是布尔的。所以模型的不确定性必须被记在别处： 记在观测器旁边的注释里，作为下一个读到它的人的背景。

== 观测器的四种常见形态
<sec-observer-patterns>
给一些可以直接套用的模式：

=== 形态一：新鲜度
<sec-pattern-freshness>
#quote(block: true)[
#strong[这个东西最后一次更新是什么时候？]
]

适用于：任何"应该被定期更新"的东西 ------ 证书、缓存、 索引、快照、生成物。

实现：读一个时间戳，断言它在阈值之内。

#strong[这是最便宜的一种观测器，而且它覆盖了大量"任务静默失效"的场景。]

=== 形态二：单调性
<sec-pattern-monotonic>
#quote(block: true)[
#strong[这个应该只增不减的量，减了吗？]
]

适用于：累计计数、版本号、数据行数、覆盖的目标数。

#ref(<sec-sentinel>, supplement: [第]) 那个哨兵就是这个形态的一个特例 ------ 而 #ref(<sec-sentinel-limits>, supplement: [第]) 建议的"相对变化率"版本更是。

=== 形态三：守恒
<sec-pattern-conservation>
#quote(block: true)[
#strong[进去的和出来的对得上吗？]
]

适用于：任何管道 ------ 消息队列、数据管道、批处理。

这个形态的强大之处在于#strong[它不需要知道中间发生了什么]： 上游发了一万条，下游应该收到一万条。 对不上，中间某处有问题，不管那个问题是什么。

#strong[形状 E（边界处的静默降级）几乎总能被这个形态抓到。]

=== 形态四：因果
<sec-pattern-causal>
#quote(block: true)[
#strong[如果 A 真的发生了，B 应该也发生。]
]

适用于：任何"做了一件事应该留下痕迹"的场景。

刷新了证书 → 到期日应该往前移。 发布了版本 → 应该有一个对应的构建产物。 处理了消息 → 位点应该前进。

#strong[这是最强的一种，也是最需要动脑的一种] ------ 因为你得先想清楚"如果它真的工作了，世界上会有什么不同" （#ref(<sec-observer-recipe>, supplement: [第]) 的第一步）。

== 四种形态的覆盖能力
<sec-pattern-coverage>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([形态], [能抓到什么], [抓不到什么],),
  table.hline(),
  [新鲜度], [完全停止工作], [工作了但做错了],
  [单调性], [突然的退化], [缓慢的退化],
  [守恒], [中间的丢失], [中间的错误转换],
  [因果], [做了没做], [做了但做得不对],
)
#strong[四种全都抓不到"做了但做错了"] ------ 那需要的是内容层面的校验，而那属于判定，不属于观测。

#strong[观测器解决的是"我看不见"，判定解决的是"它对不对"。] 先有前者，才谈得上后者。

== 为什么这个缺口在这套系统里特别刺眼
<sec-gap-ironic>
这套系统对代码的判定覆盖做到了很高的程度： 三层判定、四道证据门、每条规则带哨兵、每次判定绑定版本。

#strong[而生产这些判定的东西，一层覆盖都没有。]

这个对比之所以刺眼，不是因为它是一个疏忽， 而是因为#strong[它精确地符合这本书自己讲的那条规律]：

#quote(block: true)[
#strong[判定覆盖到哪里，纪律就执行到哪里。]
]

同一个人，在有判定覆盖的地方做到了极致， 在没有覆盖的地方，问题重复了五次、崩溃挂了四个月。

#strong[这不是能力问题，也不是态度问题。]

这是这本书最重要的一个论据，而它是反直觉的： #strong[你以为你在靠自律维持质量，实际上你在靠判定维持质量] ------ 而在没有判定的地方，自律的实际效力接近于零。

#strong[证据就是同一个人在两侧的表现差异。]

== 这个缺口该由谁来补
<sec-who-fills>
一个实际的问题：#strong[观测器本身也是代码， 那它需要判定覆盖吗？]

答案是#strong[需要，但不能无限递归]。

而终止这个递归的方式是：#strong[让观测器足够简单， 简单到它的正确性可以被一眼看出来。]

#ref(<sec-observer-patterns>, supplement: [第]) 里那四种形态之所以有价值， 正是因为它们都很简单：

- 新鲜度：读一个时间戳，比一个阈值
- 单调性：比两个数
- 守恒：比两个计数
- 因果：断言一个存在性

#strong[四种都是几行代码，都没有分支逻辑，都没有配置。]

#strong[而这是刻意的]：一个复杂的观测器需要它自己的观测器， 而那条递归没有终点。

#strong[所以观测器的设计目标不是"准确"，是"简单到不需要被验证"。]

一个粗糙但显然正确的观测器，比一个精确但需要维护的好 ------ 因为后者会腐化，而它腐化的时候，你会以为你还有覆盖。

== 补这个缺口的最小动作
<sec-minimal-fill>
对任何一个定时任务或自动化，做三件事，总成本大概半小时：

#strong[一、写一句话：它在正常工作时，世界上什么会变。] 写不出来 → 这个任务可能本来就没在做事，先查这个。

#strong[二、找到那个"变"里最便宜的可测量部分。] 通常是一个时间戳、一个计数、一个存在性。

#strong[三、把它接进一个已经有人处理的流。] 不要建面板（#ref(<sec-dashboard-nobody-reads>, supplement: [第])）。 让它变成一个改动请求、一个工单、或者一条会被看到的消息。

#strong[第三步最容易被做错]，因为它不是技术问题 ------ 它是"这个信号最终会被谁看到"的问题， 而这个问题的答案通常在技术之外。

== ⚙️ 小规模怎么做
<sec-observer-small>
#strong[一、把你所有的定时任务列出来，逐个问那三步。] 第一步就会淘汰掉一批 ------ 你会发现有些任务你根本说不出 它在正常工作时世界上有什么不同。

#strong[二、给每个定时任务一个"效果断言"，哪怕很粗糙。] "最近 7 天内应该有至少一次成功的产物"这种级别的断言就够用。

#strong[三、让失败汇入你已有的处理流，不要新建一条。] 如果你的团队盯合并请求，就让它变成合并请求； 如果你的团队盯工单，就让它变成工单。#strong[不要建面板。]

== 观测器和监控的第三个区别
<sec-third-difference>
#ref(<sec-not-monitoring>, supplement: [第]) 列了四个区别。这里补最重要的第五个， 它是前面几个的根源：

#quote(block: true)[
#strong[监控是给人看的，观测器是给判定用的。]
]

而这个区别决定了它们的设计目标完全不同：

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([], [监控], [观测器],),
  table.hline(),
  [优化什么], [#strong[信息量]（尽可能多地展示）], [#strong[可判定性]（一个数，一个阈值）],
  [多了会怎样], [面板变多，但每块的价值不变], [#strong[每多一个都要被维护]],
  [好的样子], [全面], [#strong[少而准]],
)
#strong["多了会怎样"那一行是关键。]

一块新面板的边际成本接近于零（没人看也不会怎样）， #strong[而一个新观测器的边际成本是真实的] ------ 它会产生告警，会误报，会需要被调阈值。

#strong[所以观测器应该少而准，而这和"加监控"的直觉正好相反。]

具体到那 28 条定时任务：正确的做法不是给每一条建一个观测器， 而是#strong[找出它们共同的效果，用尽可能少的观测器覆盖尽可能多的任务] （#ref(<sec-disk-observer>, supplement: [第]) 那个"五个根因，一个观测器"就是这个思路）。

== 这一章的一个自反的观察
<sec-self-referential>
最后一点，它有点绕但很重要。

#strong[这本书讲的整套东西，本身也需要观测器。]

具体地说：#strong[你怎么知道你建的这套判定系统还在工作？]

#ref(<sec-rule-health>, supplement: [第]) 那张清单是规则集的观测器， #ref(<sec-measure-the-loop>, supplement: [第]) 那三条曲线是回路的观测器， #ref(<sec-always-on-health>, supplement: [第]) 那三个指标是常驻文件的观测器。

#strong[三处，而它们在源系统里一处都没有被建起来。]

这不是批评 ------ 它恰恰印证了这一章的核心论点：

#quote(block: true)[
#strong[判定覆盖到哪里，确定性就只到哪里。 而"判定系统自己"是最容易被漏掉的那一层， 因为建它的人最相信它。]
]

#strong[而"最相信它"正是问题所在] ------ #ref(<sec-assertion-density>, supplement: [第]) 里那个观察在这里再次出现： #strong[手艺最强的地方，验证反而最弱， 因为"我知道它对"会降低建验证的动力。]

== 这一章能被压成的三句话
<sec-observer-three-lines>
#strong[一、测不到的状态，控制不了 ------ 而且对它的修复也是不可验证的。]

后半句是这一章补上的那半句（#ref(<sec-observability>, supplement: [第])）： 那个挂了四个月的崩溃后来被修了， #strong[但在没有观测器的情况下，没有人能知道它会不会再挂四个月。]

#strong[二、答案不是加监控，是建观测器：测效果，不测执行。]

因为一个作业可以"成功"却什么都没干 （#ref(<sec-not-more-sensors>, supplement: [第])）， #strong[而那五条从未运行的工作流甚至连失败记录都不会产生。]

#strong[三、让需要注意的东西主动找上门，而不是增加监控面。]

因为注意力是常数，而需要被注意的东西在增长 （#ref(<sec-dashboard-nobody-reads>, supplement: [第])）------ #strong[所以一个新信号的价值，取决于它汇入的那条已有的处理流。]

== 这一章的一个练习
<sec-observer-exercise>
对你系统里的每一个自动化任务（定时的、事件驱动的、 手工触发但很少被检查的），填一行：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([任务], [它正常工作时，世界上什么会变？], [那个"变"能被便宜地测到吗？],),
  table.hline(),
  [], [], [],
)
#strong[第二列填不出来的每一行，都值得立刻查一下] ------ 因为"它在正常工作时世界上什么都不变" 通常意味着它本来就没在做事。

而第三列填"能"的每一行，#strong[都是一个成本极低的观测器]： 读那个量，断言它在合理范围内， 把失败接进一条已经有人处理的流。

#strong[十分钟填表，而它的产出通常包含一到两个 "原来这个东西早就不工作了"。]

= 参考输入在环外
<参考输入在环外>
= 参考输入在环外
<sec-setpoint-outside>
这是全书最短的一章，因为它讲的是一件很快就能说清、 但很容易被忽略的事：#strong[这套系统有一类问题按定义就回答不了。]

不是"还没做到"，是#strong[范畴上做不到]。

== 全部是约束满足，不是参考跟踪
<sec-constraint-not-tracking>
把三层判定放在一起看：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([层], [它问什么],),
  table.hline(),
  [测试], [这段代码的行为#strong[符合断言]吗],
  [结构检查], [这段代码的位置#strong[符合规则]吗],
  [路径不变量], [这次改动#strong[违反了这条路径的约定]吗],
)
#strong[三层全部在问"有没有违反什么"。没有一层在问"这是不是我们要的"。]

用控制的语言说：这是#strong[约束满足]，不是#strong[参考跟踪]。

用航空的话说更直观：这是一套非常好的#strong[包线保护] ------ 防失速、防超速、防过载，任何一个参数越界都会被立刻拉回来。

#strong[但包线保护不负责把飞机飞到目的地。]

一架被包线保护得完美的飞机，可以非常安全地飞到一个错误的机场。

== 闭环系统不能生成自己的设定点
<sec-no-self-setpoint>
这不是这套系统的缺陷，这是一个范畴事实。

一个控制回路需要一个#strong[参考输入] ------ 输出应该是多少。 而这个参考输入#strong[必须来自回路之外]，理由很简单：

#quote(block: true)[
#strong[一个能修改自己目标的控制器，永远会报告成功。]
]

它会在遇到困难时，悄悄把目标改成自己已经做到的那个 ------ 而且这个动作在回路内部完全看不出异常：误差归零了， 控制器"完成"了任务。

#strong[作者在长任务机制里做对了这件事。] #ref(<sec-memory-split>, supplement: [第]) 里那六类记忆， 第一条就是：

#quote(block: true)[
不变意图：#strong[永不被迭代改；改它 = 人的决定。]
]

#strong[这条设计是完全正确的，而且它正是上面那条定理的直接应用。]

但它只被用在了单个长任务这一层。#strong[在整个系统这一层， 同样的问题存在，而且还没有被同样对待。]

== 这个系统里最不冗余的一个元件
<sec-least-redundant>
这是全书最锋利的一段，而它是从系统自己的原则里推出来的。

"每份可变状态收敛到单一 owner"这条原则被贯彻到了整个仓库 ------ 贯彻到#strong[超过一半的路径不变量都在回答"这块状态归谁写"] （见 #ref(<sec-ownership-pattern>, supplement: [第])）。

而这个系统里最重要的那份可变状态 ------ #strong["该做什么"] ------ 确实只有一个 owner：那个人自己。

#strong[没有第四格 #NormalTok("Testing/");，没有判定，没有观测器，没有第二个 writer。]

具体的表现是：26 个产品，而全部材料里#strong[没有一处]讨论 哪个有用户、留存多少、哪个该砍。

这不是疏忽，这恰恰是这套系统的边界所在。但它带来一个后果：

#quote(block: true)[
#strong[参考输入是这个系统里唯一没有被仪表化的元件， 而它恰恰是决定最终结果的那一个。]
]

一个前馈完美、反馈严密、传感器带自检、观测器覆盖全面的控制系统， 如果设定点给错了，它会#strong[极其高效地]收敛到一个错误的地方。

#strong[而且它跑得越好，收敛得越快。]

== 参考输入的质量决定一切，而它无法被这套系统改善
<sec-setpoint-quality>
这一节要说清楚一件容易被误解的事。

这套系统#strong[提高了产出的效率和可靠性]。它没有、也不可能提高 #strong[产出的正确性]，如果"正确"指的是"做对了该做的事"。

两者的关系是#strong[乘法]：

#Skylighting(([#NormalTok("最终价值 = 参考输入的质量 × 执行的效率");],));
而这套系统只作用在第二项上。

这意味着一件反直觉的事：#strong[执行效率越高，参考输入的质量就越重要。]

一个执行效率很低的团队，做错方向的代价被自己的低效限制住了 ------ 半年只能做错一件事。而一个能让几十个 Agent 并行、 一天合入五十二次的系统，#strong[做错方向的代价被同样地放大了。]

== 人还要做什么
<sec-what-humans-do>
所以"不用人做代码审查"这句话必须被精确化。

审的东西变了，不是不审了：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([人还要审的], [为什么机器判不了],),
  table.hline(),
  [这个需求到底要解决什么问题], [没有可比对的真值],
  [两个方案的取舍], [取舍依赖于外部目标],
  [边界是否定义完整], ["完整"相对于意图而言],
  [#strong[一个不可逆的动作是否真的应该发生]], [见下],
)
#strong[最后一条是唯一一条既在环外、又能被机制辅助的。]

路径清单里那四条最高风险的不变量，守的正是这一类 （见 #ref(<sec-risk-distribution>, supplement: [第])）。它们#strong[不能替人做决定]， 但它们能保证：

#quote(block: true)[
#strong[这个决定被显式地做出，而不是被某次重试悄悄做掉。]
]

这是机制在这条边界上能做到的极限，而它已经很有价值了 ------ 因为大部分不可逆的错误，不是有人错误地决定要做它， 而是#strong[根本没有人意识到自己在决定。]

== 一个容易被混淆的边界
<sec-adjacent-boundary>
有一类问题看起来在环外，实际在环内，值得单独拎出来：

#quote(block: true)[
#strong["这个实现方案好不好"] ------ 在环内。
]

因为"好"在这里有一个可以被判定的定义：#strong[它满足那五条边界吗] （#ref(<sec-same-boundary>, supplement: [第])）。行为能被观察、结构符合约定、 尊重 owner 和不变量、高风险动作显式、失败能定位。

而下面这些在环外：

#quote(block: true)[
#strong["这个功能该不该做"] ------ 环外，没有真值可比对。 #strong["这两个方案哪个更符合我们三年后的方向"] ------ 环外，依赖外部目标。 #strong["这个技术债现在该不该还"] ------ 环外，是资源分配问题。
]

#strong[分清这两类很重要]，因为把环内的问题当成环外的， 会让人不去建本可以建的判定；而把环外的当成环内的， 会让人徒劳地找一个不存在的自动化答案。

一个实用的判据：

#quote(block: true)[
#strong[这个问题的答案，会不会因为公司的战略变了而变？]
]

会变 → 环外。不会变 → 环内，可以判定。

== 参考输入失效的三种形态
<sec-setpoint-failures>
既然它是系统里最不冗余的元件，值得列出它的失效方式 ------ 虽然这本书给不出解法，但#strong[知道形态至少能识别它]。

#strong[一、目标漂移。] 做着做着，目标悄悄变成了"把这个做完"， 而不是"解决那个问题"。#ref(<sec-memory-split>, supplement: [第]) 里的 "不变意图永不被迭代改"就是防这个的，但它只在单个长任务这一层有效。

#strong[二、目标被指标替代。] 拦截率、合并次数、覆盖率 ------ 这些是执行效率指标，而它们全都在变好的时候，很容易被当成"我们在做对的事"。 #strong[这本书自己就是这个问题的一个例子]：#ref(<sec-no-escape-rate>, supplement: [第]) 讲过， 所有指标都是过程指标，没有一个是结果指标。

#strong[三、目标从未被明确表述。] 最常见的一种。 如果"我们要做什么"从来没有被写成一句可以被反驳的话， 那么它无法失效 ------ 也无法被检验。

#strong[三种形态的共同点：它们都不会让任何检查变红。]

这就是为什么这一章必须存在。一本讲判定的书， 如果不明确说出"有一整类东西不在判定范围内"， #strong[它就会被误读成一个完整的答案，而它不是。]

== 一个人的系统里，这一章最要紧
<sec-solo-setpoint>
这本书讲的所有东西，在一个人的系统里都成立。 #strong[而这一章在一个人的系统里，成立得最狠。]

因为参考输入的所有冗余机制 ------ 讨论、争论、有人提出反对意见、 有人从另一个角度看同一个问题 ------ #strong[在一个人的系统里全都不存在。]

而这个缺失和别的缺失不一样：

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([缺失], [表现],),
  table.hline(),
  [缺一道检查], [某类问题会漏过去，迟早被发现],
  [缺一个工具], [Agent 只能猜，产出质量下降],
  [#strong[缺参考输入的冗余]], [#strong[你会极其高效地把一件不该做的事做完，而且过程中一切指标都很好看]],
)
#strong[第三行没有自我纠正机制。]

而这套系统的性质让它更严重：因为执行效率极高， 从"决定做"到"做完"的时间被压缩了 ------ #strong[留给"等一等，这件事对吗"的窗口也被压缩了。]

一个执行效率低的系统，一个错误的决定要花三个月才能做完， 而这三个月里有很多次机会意识到它是错的。

#strong[一个一天能合五十二次的系统，那个窗口是几天。]

=== 唯一可行的缓解
<sec-solo-mitigation>
这本书给不出解法，但可以指出一个方向：

#strong[把参考输入也变成一个有判定的东西。]

具体形态是 #ref(<sec-memory-split>, supplement: [第]) 里那个"不变意图"的放大版：

- 把"我要做什么、为什么"#strong[写下来]，写成一句可以被反驳的话
- 定期（比如每月）#strong[回去读它]，问"这句话现在还成立吗"
- 记下每一次改变它的#strong[理由]

这三条看起来像是自我管理，但它们的实质是#strong[给一个不可观测的状态 建一个最简陋的观测器]（#ref(<sec-observer>, supplement: [章节])）------ 把一个存在于脑子里的东西，变成一个存在于文件里的、可以被对照的东西。

#strong[不能保证它是对的，但至少能发现它变了。]

而"发现它变了"这件事，对 #ref(<sec-setpoint-failures>, supplement: [第]) 里那三种失效形态 中的前两种（目标漂移、目标被指标替代）是有效的。

== 参考输入的三个可以做的事
<sec-setpoint-actions>
虽然它在环外，但有三件事是可以做的， 而且它们的共同点是：#strong[把一个存在于脑子里的东西变成一个可以被对照的东西。]

=== 一、把它写成一句可以被反驳的话
<sec-falsifiable-goal>
"我们要做一个好用的产品"无法被反驳，所以它也无法失效。

"#strong[这批用户现在用 X 方式解决 Y 问题， 而我们认为他们会为一个更快的方式付费]"可以被反驳 ------ 用户可能不这么解决，可能不觉得慢是问题，可能不付费。

#strong[而可以被反驳意味着可以被检验。]

=== 二、把改变它的理由记下来
<sec-record-changes>
不是记"目标变成了什么"，是记#strong["为什么变"]。

因为目标漂移（#ref(<sec-setpoint-failures>, supplement: [第]) 的第一种）的特征是： #strong[每一次微小的改变都有理由，而累积起来变成了另一件事。]

只有把理由记下来，才能在半年后回头看这条链， 判断它是"逐步逼近"还是"逐步走偏"。

#strong[这正是那六类记忆里"决策叙事"的作用] （#ref(<sec-memory-split>, supplement: [第])）------ 只追加、不可变、一轮一条。

=== 三、给它一个固定的复核时刻
<sec-review-cadence>
不是"想起来就看看"，是一个固定的节奏。

而这个节奏该多长，用 #ref(<sec-cadence-theory>, supplement: [第]) 那条规则来定： #strong[取决于外部世界给你反馈的延迟。]

- 如果你的产品每周有数据 → 每月复核一次
- 如果要等一个季度才知道效果 → 每季度

#strong[采样快于反馈延迟，采到的是噪声] ------ 而依据噪声调整目标， 正好就是目标漂移。

== 这一章和第一章的呼应
<sec-echo-chapter-one>
第一章讲两堵墙，说的是"判定跟不上产出"。

而这一章说的是：#strong[判定这一侧建好之后， 瓶颈会移到一个判定管不到的地方。]

#strong[这两件事合起来是一条完整的轨迹：]

#Skylighting(([#NormalTok("① 产出慢，判定够 → 没有问题");],
[#NormalTok("② 产出快了，判定跟不上 → 第一、二堵墙");],
[#NormalTok("③ 判定建好了 → 瓶颈移到参考输入");],));
#strong[大部分讲 Agent 工程的内容停在第②步， 把"建好判定"当成终点。]

而这本书想说的是：#strong[它是一个阶段，不是终点。] 而知道下一个阶段在哪，决定了你什么时候该停下来 （#ref(<sec-when-to-stop>, supplement: [第])）。

#strong[这也是这一章必须存在的理由]： 一本讲判定的书，如果不说清楚"判定的尽头是什么"， 它会被误读成一个完整的答案。

== 这一章的实际后果
<sec-setpoint-consequences>
三条：

#strong[一、不要用这套系统的指标去回答它回答不了的问题。] 拦截率、失败率、转绿时长 ------ 这些都是执行效率指标。 它们全都变好，和"我们在做正确的事"之间没有任何关系。

#strong[二、参考输入需要它自己的一套东西，而那套东西不在这本书里。] 用户访谈、留存数据、单位经济模型 ------ 那是另一个领域的方法论。 这本书唯一能贡献的是：#strong[别指望判定边界能替你做那件事。]

#strong[三、如果你只有一个人，参考输入是你系统里风险最高的部件。] 它无冗余、无判定、无观测器，而且它的失效是静默的 ------ 你会非常高效地把一件不该做的事做完。

== 这一章不是在推卸责任
<sec-not-excuse>
有一种读法值得提前堵住：

#quote(block: true)[
"参考输入在环外" 听起来像是在说 "做错方向不是这套系统的责任"。
]

#strong[它确实不是这套系统的责任 ------ 但它是你的责任， 而且这套系统会放大它的后果。]

#ref(<sec-setpoint-quality>, supplement: [第]) 那个乘法关系是双向的： 执行效率越高，正确的方向收益越大，#strong[错误的方向代价也越大。]

所以正确的读法是：

#quote(block: true)[
#strong[建这套系统的同时，必须同等地投入到"做什么"上 ------ 因为你刚刚把另一半的乘数放大了。]
]

而这本书唯一能提供的帮助是#strong[指出这件事]， 以及 #ref(<sec-setpoint-actions>, supplement: [第]) 那三个最低限度的动作。

#strong[一本讲执行的书，如果不提醒读者去看方向， 它就是在帮读者更快地走错路。]

== 这一章在全书里的位置
<sec-chapter-position>
第四部的四章有一个递进关系，而这一章是终点：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([章], [它说的],),
  table.hline(),
  [#ref(<sec-gain-and-delay>, supplement: [章节])], [回路可以被调],
  [#ref(<sec-sensor-faults>, supplement: [章节])], [但测量本身要可信],
  [#ref(<sec-observer>, supplement: [章节])], [而有些状态根本测不到],
  [#strong[本章]], [#strong[而有一样东西按定义就在回路之外]],
)
#strong[四章是一个逐步收窄的过程]：从"能做什么" 走到"做不到什么"。

而这个顺序是刻意的。#strong[一本讲方法的书， 如果不在最后划出方法的边界， 它会被当成一个通用解。]

#strong[而这本书不是。] 它解决的是一个具体的、 有边界的问题：#strong[在有外部真值的领域里， 怎么让不确定的产出变得可以被判定。]

#strong[边界之外的东西 ------ 做什么、为什么做、值不值得做 ------ 这本书一个字都答不了。]

== 最后一次回到那个乘法
<sec-final-multiplication>
#Skylighting(([#NormalTok("最终价值 = 参考输入的质量 × 执行的效率");],));
这本书作用在第二项上，而且作用得相当彻底。

#strong[而这意味着：读完这本书之后， 第一项的重要性对你来说变高了，不是变低了。]

如果你的执行效率翻了三倍，那么#strong[同样的方向误差， 现在的代价也是三倍。]

#strong[所以这本书唯一的一条书外建议是]： 在建这套系统的同时，拿出同等的注意力 去看"我们在做的事对不对"。

而那件事的方法论不在这里 ------ 它在用户研究、在数据分析、在市场判断， #strong[在一个和这本书完全不同的领域里。]

#strong[这本书能做的，只是提醒你它存在， 以及提醒你：这套系统建得越好，它就越重要。]

= 这套东西的边界
<这套东西的边界>
= 这套东西的边界
<sec-boundaries>
这是最后一章。它的作用是#strong[把这本书的适用范围划出来]， 以及诚实地列出还没有被证明的部分。

一本讲"怎么建立可信判定"的书，如果对自己的主张不给出判定边界， 那它就违反了自己的第一条原则。

== 三个还没有被证明的东西
<sec-unproven>
=== 一、缺陷逃逸率没有被测量
<sec-no-escape-rate>
书里所有的指标都是#strong[过程指标]：拦截率 27%、结构检查失败率 7.0%、 中位转绿 1.4 小时、合并 2,675 次、成功率 98.3%。

#strong[它们全都是"检查在触发"的证据，没有一个是"拦对了"的证据。]

真正能验证这套体系的只有一个数：

#quote(block: true)[
#strong[缺陷逃逸率 ------ 合并之后才被发现的问题占多少。]
]

这个数不在。而它的缺席意味着一件具体的事： "27% 的改动被拦过"和"拦下的都是文件超过 200 行"可以同时成立。

#strong[唯一走完全程的那个例子里，被拦下的正是文件健康度那条规则。]

有意思的是：#strong[能用来算这个数的数据全都在手边。] 崩溃扫描每 5 分钟在跑，自动归因已经在做。 缺的只是把崩溃反向关联到引入它的那次改动。

而更好的一件事是，#strong[有一个天然的对照组存在过]： 第一条自动检查比 Agent 规模化晚了两个月（#ref(<sec-two-months-late>, supplement: [第])）。 那两个月的合并，和之后的合并，是一个现成的前后切片。

=== 二、负载类型限制了结论的可迁移性
<sec-load-type>
这套系统跑的是 26 个消费级 App。这类产品有两个性质， 而这两个性质恰好让这套方法特别有效：

#strong[第一，质量下限的容忍度。] 一个剪辑工具偶发的界面错位， 和一个支付系统的金额计算错误，不是一个量级的事。 这本书里的方法在两种场景下都能用，但#strong[它们的收益曲线不一样]。

#strong[第二，产品之间耦合度低、影响面天然可切割。] "产品互不依赖"本身就是一条被强制的规则。 而这恰恰是#strong[稀疏测量能生效的前提] ------ 依赖图之所以能大幅缩小测量范围， 是因为改动的影响面本来就是局部的。

#strong[一个 300 万行但只有一个产品、模块间深度耦合的系统会怎样？] 每次改动的影响面可能覆盖大半个仓库，稀疏测量的收益会大幅下降， #ref(<sec-gain-and-delay>, supplement: [章节]) 那套增益与延迟的分析仍然成立， 但结论会不同 ------ 那种系统的出路更可能在"降增益"那一支。

#strong[这本书不知道那种系统会怎样。] 说不知道比编一个答案好。

=== 三、规则集的长期腐化没有被观察到
<sec-no-decay-data>
这套系统只运行了半年多。

#ref(<sec-rule-retirement>, supplement: [第]) 提出的三个问题 ------ 规则怎么退休、 重构时路径范围怎么跟着改、报数模式的规则谁负责收敛 ------ #strong[它们的答案要再过两年才知道。]

而且现在#strong[连问题的严重程度都测不出来]，因为绕过率 （#ref(<sec-bypass-rate>, supplement: [第])）还没有被测量。

== 什么时候不该用这套
<sec-when-not>
四种情况，前三种和 #ref(<sec-when-not-to>, supplement: [第]) 呼应，第四种是新的：

#strong[一、项目生命周期短于规则的回本周期。] 规则的收益来自复利 ------ 它拦下的第一百次比第一次值钱得多。 一个三个月的项目等不到那个时候。

#strong[二、团队还没就"什么是对的"达成一致。] 这时候写规则会#strong[把分歧固化成机制]，而机制比争论更难改。 先吵完，再写规则。

#strong[三、需求本身高度不确定。] 这时候瓶颈在参考输入（#ref(<sec-setpoint-outside>, supplement: [章节])），不在判定。 把力气花在判定上是在优化一个不是瓶颈的环节。

#strong[四、你的误报率会超过某个阈值。] #ref(<sec-bypass>, supplement: [第]) 讲过，会被绕过的规则比没有规则更糟。 如果你还没有足够的真实数据来校准规则边界 ------ #strong[那么"还没到时候"是一个正确的答案。]

== 一个模型的代价
<sec-model-cost>
回到 #ref(<sec-where-uncertainty-lives>, supplement: [章节]) 那个编解码器模型。

它生成了正确的行为 ------ 这本书描述的整套系统，是在那个模型下建成的， 而且建对了。#strong[这说明一个错的模型也可以生成正确的行为， 只要它错的方向凑巧指向对的一侧。]

但错的模型有代价，而且这个代价在书里已经显现了三处：

#strong[一、它解释不了这套系统最好的那个抽象。] 载体分类（#ref(<sec-carriers>, supplement: [章节])）之所以有效，是因为注意力分布、 位置效应、上下文与先验的强度之争 ------ #strong[这些跟解码的确定性一点关系都没有。] 一个解释不了自己最强发明的模型，也预测不了下一个发明该往哪找。

#strong[二、它预测不了语义失败。] 编解码器的噪声是#strong[局部有界]的：坏一个块，烂一片。 而模型的失败是#strong[全局自洽且自信地错] ------ 它交出一个格式完美、看起来合理、整体错误的实现。 这本书里的解药（变异验证、假绿检测）是从经验里长出来的， 不是从那个模型里推出来的。

#strong[三、它会把路线图指向错误的一半。] 如果不确定性是解码器的属性，前沿就是更好的解码； 如果它是规格问题，前沿是#strong[更便宜更密的验证]。 后者才是这套系统实际在建的东西。

#strong[所以第四部不是学术装饰。] 换一个能预测的模型， 比守着一个能解释的模型值钱 ------ 而这个差别只有在 你需要知道"下一步该往哪走"的时候才显现出来。

== 这套东西最明显的一处缺口
<sec-biggest-gap>
如果只能指出一处，是 #ref(<sec-observer>, supplement: [章节]) 那一处：

#strong[判定覆盖到代码，但没有覆盖到生产这个判定的工具链自己。]

一条定时任务挂了四个月没人发现，5 条工作流从注册后一次没跑过， 磁盘容量问题重复了五次才被提到机制层面。

而这三件事的共同点，用这本书自己的话说：

#quote(block: true)[
#strong[它们都不产生判定。而一个不产生判定的动作，坏了你不会知道。]
]

== 这本书希望被怎么用
<sec-how-to-use-book>
三种用法，价值递减：

#strong[最好的用法：当成一份形状清单。]

七个形状（#ref(<sec-seven-shapes>, supplement: [章节])）是这本书里唯一完全可迁移的部分。 它们不依赖任何技术栈、任何规模、任何工具。 #strong[读完之后能在自己系统里指认出三个实例，这本书就值了。]

#strong[次好的用法：当成一份判据清单。]

书里有一批可以直接用的判据，它们的共同特点是#strong[把品味问题变成事实问题]：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([判据], [用在哪],),
  table.hline(),
  [这一层被第二个实例挣得了吗], [目录],
  [这条规则换来了什么可测性], [架构],
  [这条规则什么时候需要到达], [载体],
  [这道检查坏了会表现成通过还是失败], [判定],
  [出错之后重试能不能挽回], [风险等级],
  [同一个判断你做过几次], [该不该建机制],
)
#strong[六条判据，每一条都能在十分钟内用完一遍。]

（它们用到的术语，#ref(<sec-appendix-glossary>, supplement: [附录]) 里按使用场景分组索引了一遍。）

#strong[最差的用法：照着抄那二十三条规则。]

#ref(<sec-two-months-late>, supplement: [第]) 讲过为什么。抄来的规则边界没有被你的代码校准过， 误报率会高，然后被绕过，然后连带损害你对整套东西的信任。

== 三件这本书没做到的事
<sec-book-shortcomings>
对称地，这本书也该有自己的判定边界：

#strong[一、它没有证明这套做法值得。] #ref(<sec-no-escape-rate>, supplement: [第]) 讲过：所有数字都是过程指标。 "这套东西让质量变好了"这个命题，#strong[书里没有证据]， 只有"这套东西在按设计工作"的证据。

#strong[二、它的样本量是一。] 一个仓库、一个人、半年多。所有的"这样做有效"都是从这一个样本里读出来的。 其中哪些是普适的、哪些是这个特定环境的产物，#strong[书里的划分是推理，不是数据。]

#strong[三、它的理论部分是后加的。] 第四部用控制论重述了一套已经建成的实践。 这个重述是有价值的（它预测了几件经验推不出的事）， 但它#strong[没有经过检验] ------ 那三条建议（振荡次数、观测器、增益调度） 一条都还没有被实施过。

== 接下来这套东西会怎么变
<sec-whats-next>
一个诚实的预测，以及为什么这本书敢做这个预测。

#strong[判定这一侧的成本会继续下降。] 检查器会更快、更聪明、更便宜。 这是确定的趋势。

#strong[而参考输入的成本不会下降。]

这两条合起来给出一个方向：

#quote(block: true)[
#strong[判定和执行会越来越不是瓶颈， 而"该做什么"会越来越是瓶颈。]
]

对读者的实际含义：#strong[这本书讲的东西，投入回报期是有限的。]

不是说它会过时 ------ 七个形状和五条判据大概会长期有效。 而是说：#strong[当你把判定这一侧建到"不再是瓶颈"之后， 继续投入的回报会迅速趋近于零]，而那时候该停 （#ref(<sec-when-to-stop>, supplement: [第])）。

而这个时刻会比大部分人预期的更早到来。

== 这本书如果只有一章
<sec-one-chapter>
如果只能保留一章，是 #ref(<sec-carriers>, supplement: [章节])（载体）。

三个理由：

#strong[一、它零基建成本]，任何规模的团队今天就能用。

#strong[二、它是唯一一个"分类本身就是答案"的章节。] 其余每一章都在讲"这样做更好"，而那一章讲的是 "按这个维度分开，问题就消失了"------ #strong[一个分类如果是对的，它会让原来的争论变得不必要。]

#strong[三、它是这套系统里最不依赖具体技术的部分。] 换语言、换构建系统、换 Agent，那五种载体的划分仍然成立。

而如果只能保留一节，是 #ref(<sec-rule-with-failure>, supplement: [第]) ------ "每条规则都要带着它的失败形态"。

#strong[因为它是唯一一条今天下午就能做完、 而且明天就能看到效果的建议。]

== 最后的最后
<sec-really-final>
这本书从一个具体的仓库开始，也应该在一个具体的地方结束。

那个仓库里现在有三百多万行代码、二十几个产品、 二十三条规则、二十份路径清单、二十八条定时任务， 以及#strong[其中五条从来没有跑过、一条挂了四个月没人发现]。

#strong[这两组数字必须放在一起看。]

因为它们说的是同一件事：#strong[一个系统在有判定覆盖的地方 可以做到非常好，在没有判定覆盖的地方会烂到你无法想象。]

而这两个地方之间，没有中间状态。

== 如果只记住一句
<sec-one-line>
不是那句"确定性不是 Agent 的性格"，虽然它更好听。

是这一句：

#quote(block: true)[
#strong[判定覆盖到哪里，确定性就只到哪里。]
]

因为它同时是这套做法的#strong[方法]和它的#strong[边界] ------ 它告诉你该往哪投入，也告诉你为什么那个挂了四个月的崩溃 一定会发生在没有判定覆盖的地方，而不是别的地方。

而它最有用的形态是一个问题，可以对任何一个系统问：

#quote(block: true)[
#strong[这里，什么东西在产生判定？]
]

如果答案是"没有"，那么那个地方#strong[现在是什么状态，你不知道] ------ 不管它看起来多正常。

== 最后
<sec-final>
把这本书压成一段话：

#quote(block: true)[
我们不要求 Agent 永远不犯错。我们要求的是： #strong[错误能在副作用发生之前被发现，原因说得清楚，修正有明确方向， 修完以后还能用同一套证据确认它真的变好了。]
]

而这个要求目前只对代码成立。

一个功能可以有很多种正确实现。只要它满足同一组边界， Agent 就可以在里面自由探索：行为能够被测试观察， 结构符合仓库的架构约定，改动尊重 owner 和不变量， 高风险动作保持显式，失败能定位、修复能复验。

#quote(block: true)[
#strong[不承诺同样的代码，只承诺同样的判定边界。]
]

回到最开始那两个问题。

#strong[环境决定 Agent 能不能做对]，靠的是把规则写进结构而不是写进文档 ------ 代码库是它读到的上下文，架构让仓库不随规模腐化， 工作指导让规则在正确的时刻到达它面前，工具链决定它的手能伸到哪里。

#strong[检查决定我们能不能知道它做对了] ------ 测试看运行时的事实， 结构检查看结构上的事实，路径不变量看这条路径背后的约定。

而第四部想说的是：#strong[这两半合起来是一个闭环控制系统。] 前馈决定性能，反馈提供鲁棒性，传感器需要自己的故障管理， 测不到的状态需要观测器，而设定点永远在环外。

这四块环境里，工具链是唯一一块光靠约束长不出来的 ------ 目录可以规定、依赖方向可以拦、规则的载体可以安排， 但"Agent 够不够得着"只能靠一件一件把东西造出来。 #strong[7.4% 的代码量花在这上面，是这个仓库做过的最不显眼、也最难省掉的一笔投入。]

如果要把这套做法压成一句话：

#quote(block: true)[
#strong[把重复出现的判断变成机制， 把高风险的边界变成协议， 把每一次失败变成可以行动的证据。]
]

#quote(block: true)[
#strong[确定性不是 Agent 的性格，而是环境给它的边界。 把 Agent 包围起来，最终是为了让我们敢把更多事情交给它。]
]

== 这本书的六条建议汇总
<sec-six-suggestions>
书里散落着几条对源系统的具体建议，集中列一遍 ------ 它们的共同点是：#strong[数据全都在手边，缺的只是把它接进一条判定。]

#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([\#], [建议], [数据在哪], [在哪章],),
  table.hline(),
  [1], [把振荡次数做成时间序列], [流水线记录], [#ref(<sec-measure-the-loop>, supplement: [第])],
  [2], [给定时任务建观测器（测效果不测执行）], [签入的证书等状态], [#ref(<sec-signing-observer>, supplement: [第])],
  [3], [哨兵改成相对变化率], [每次运行的扫描数], [#ref(<sec-sentinel-limits>, supplement: [第])],
  [4], [测量绕过率], [改规则的提交历史], [#ref(<sec-bypass-rate>, supplement: [第])],
  [5], [规则集的健康度自动化], [每次运行的输出], [#ref(<sec-checker-gap>, supplement: [第])],
  [6], [重构后主动检查规则的扫描数], [同上], [#ref(<sec-refactor-cost>, supplement: [第])],
)
#strong[六条里有四条用的是同一份数据：每次运行输出里的扫描数。]

而那个数现在只被用作一次性的哨兵比较 ------ #strong[它的时间序列没有被保存。]

#strong[这可能是整本书里投入产出比最高的一条建议]： 把每次运行的每条规则的扫描数追加到一个文件里。 一行代码，而它同时支撑了第 3、5、6 三条。

== 一个对读者的请求
<sec-request>
这本书里所有的结论都来自一个样本 （#ref(<sec-load-type>, supplement: [第])、#ref(<sec-no-decay-data>, supplement: [第])）。

#strong[如果你按书里的方法量了自己的系统，而结果不一样 ------ 那是有价值的信息，而不是你做错了。]

具体地说，下面四个数如果在你的系统里差别很大， 说明这本书的某个前提在你那里不成立：

- #strong[基建故障占比]（这里是 23.8%）
- #strong[零断言测试占比]（这里是 4.0%）
- #strong[结构检查 vs 端到端的耗时比]（这里约 1:3）
- #strong[规则的绕过率]（这里未知）

#strong[第三个尤其值得对照] ------ 如果你的比例接近 1:1， 那么串级控制（#ref(<sec-cascade>, supplement: [第])）在你那里不成立， 而这一整套关于回路的分析需要被重新做一遍。

== 一份读完之后的行动清单
<sec-action-list>
按"今天能做完"到"需要几个月"排：

=== 今天（半小时到两小时）
<今天半小时到两小时>
- 断言测试执行数不为零（#ref(<sec-impl-nonzero>, supplement: [第])）
- 数一数你的常驻文件，标出写不出失败形态的条目（#ref(<sec-exercise-count>, supplement: [第])）
- 列出你系统里不可逆的动作（#ref(<sec-exercise-irreversible>, supplement: [第])）
- 翻最近十次红灯，标注代码问题还是基建问题（#ref(<sec-exercise-red>, supplement: [第])）

=== 这周（半天到一天）
<这周半天到一天>
- 退出码三分（#ref(<sec-impl-exit-codes>, supplement: [第])）
- 重写常驻文件里的三条规则，每条补上五个部分（#ref(<sec-rewrite-exercise>, supplement: [第])）
- 给最危险的一条路径写一份清单，打印不拦（#ref(<sec-arbiter-mvp>, supplement: [第])）

=== 这个月（观察为主）
<这个月观察为主>
- 记评审里重复说的话
- 记每次 CI 红灯的分类和定位耗时（#ref(<sec-classification-exercise>, supplement: [第])）
- #strong[什么规则都不加]

=== 三个月
<三个月>
- 第一条规则，报数模式
- 开始记录扫描数的时间序列（#ref(<sec-six-suggestions>, supplement: [第]) 的第 6 条）
- 量三个数：测量延迟、回路延迟、振荡次数（#ref(<sec-measure-the-loop>, supplement: [第])）

=== 六个月
<六个月>
- 判断自己在哪个稳态（#ref(<sec-three-equilibria>, supplement: [第])），据此决定下一步

#strong[注意"这个月"那一格里那句"什么规则都不加"] ------ 它是整张清单里最难执行、也最重要的一条。

== 这本书的最后一句
<sec-last-line>
#quote(block: true)[
#strong[判定覆盖到哪里，确定性就只到哪里。]
]

而这句话最有用的形态是一个问题， 可以对任何一个系统、任何一个角落问：

#quote(block: true)[
#strong[这里，什么东西在产生判定？]
]

如果答案是"没有" ------ 那么那个地方现在是什么状态， #strong[你不知道。]

不管它看起来多正常，不管它跑了多久没出过问题， 不管建它的人多相信它。

#strong[你不知道，而且你不会知道，直到它以某种方式撞出来。]

#show: appendices.with("附录", hide-parent: true)
#heading(level: 1, numbering: none)[附录]
= 附录 A · 规则全量表
<附录-a-规则全量表>
= 附录 A · 规则全量表
<sec-appendix-rules>
二十三条架构规则的全量清单。#strong[排序不按字母，按"值得先抄哪条"。]

== 先看一个统计
<sec-rule-kinds>
按实现方式分，二十三条规则分成两类：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([实现方式], [条数], [说明],),
  table.hline(),
  [文本模式匹配], [9], [#NormalTok("forbid_pattern"); 及其跨模块变体],
  [#strong[语义分析]], [#strong[14]], [每一类有自己的分析器],
)
#strong[超过一半的规则不是"grep 一个字符串"。]

那十四个语义类型各自是一个独立的分析器：服务查找归属、 访问器契约、可选用法契约、兜底契约、目标分离、单例绕过、 界面目标粒度、本地化表归属、依赖规则、注释代码、文件健康度、 测试宿主契约……

这个比例本身就是一条信息：#strong[当你认真对付一类问题时， 文本匹配很快就不够用了]（见 #ref(<sec-semantic-rules>, supplement: [第]) 里那个五层过滤的例子）。

档位分布：#strong[20 条拦截，3 条报数。]

== 第一梯队：任何团队都该有，零基建
<sec-tier-one>
这五条不依赖任何构建系统，用一个脚本加一份配置就能实现。

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([规则], [它守什么], [换来的可测性],),
  table.hline(),
  [#strong[无条件跳过检测]], [跳过语句必须有真实的运行时理由], [覆盖不会被静默删除],
  [#strong[注释掉的代码]], [代码即唯一事实源，历史归版本控制], [读代码时不必判断哪段是活的],
  [#strong[单一日志 owner]], [日志只在一个文件里定义], [日志配置有唯一入口，可改可测],
  [#strong[文件健康度]], [按变更原因拆，行数是启发式上限], [单个文件的变更原因唯一],
  [#strong[重试点击辅助函数]], [禁止"点到成功为止"], [一次意图只提交一次],
)
第一条和第五条是#strong[专门用来防"测试看起来通过了"的]（见 #ref(<sec-anti-fake-rules>, supplement: [第])）， 而它们值得排在最前面，因为#strong[假绿比没有测试更危险]。

== 第二梯队：有共享层之后
<sec-tier-two>
需要一个"共享层 / 产品层"的划分，但不需要构建图。

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([规则], [它守什么], [换来的可测性],),
  table.hline(),
  [#strong[协议优先查找]], [只在协议层顶层做服务查找], [契约不被绕过],
  [#strong[可选访问器契约]], [返回可选的访问器不许在未注册时崩], [调用方的可选分支是真的],
  [#strong[禁止服务兜底]], [没有不经过正常装配的隐藏路径], [行为唯一，可断言],
  [#strong[协议与实现目标分离]], [契约和实现不编在同一个目标], [分层不是伪边界],
  [#strong[具体单例绕过]], [消费者不许直接用具体实现的单例], [生命周期归微内核],
  [#strong[产品互不依赖]], [跨产品复用必须下沉共享层], [产品可独立构建与测试],
  [#strong[本地化表归属]], [只有一个消费者的文案不放共享表], [改一句文案不动全产品],
  [#strong[权益单一 owner]], [权益查询收口到一个服务], [不存在第二个真相源],
)
#strong["禁止服务兜底"是这一梯队里最值钱的一条]， 而它也是实现最复杂的一条（#ref(<sec-semantic-rules>, supplement: [第])）。

== 第三梯队：需要构建依赖图
<sec-tier-three>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([规则], [它守什么],),
  table.hline(),
  [界面目标粒度], [页面/组件按功能拆成独立目标],
  [部署件归属], [兄弟部署件不许直连，只经共享层],
  [测试宿主契约], [有界面测试就必须有可执行宿主],
  [测试 bundle 经包装器], [名字由包装器推出，不由调用方起],
  [发布走账本], [发布流水线不许绕过账本直接触发],
  [构建工具不依赖客户端], [构建期工具与客户端图隔离],
)
== 三条报数模式的
<sec-report-only-three>
#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([规则], [现状], [为什么还没拦],),
  table.hline(),
  [本地化表归属], [#strong[966 处违规]], [存量太大，正在收敛],
  [产品互不依赖], [零违规], [已经干净，随时可切],
  [音频会话单一写者], [零违规], [产品域规则，观察期],
)
#strong[第二行和第三行值得注意：它们已经零违规了，却还在报数模式。]

这说明一件事：#strong[从"零违规"到"切成拦截"之间，还差一个决定， 而这个决定没有 owner]（见 #ref(<sec-rule-retirement>, supplement: [第])）。

== 每条规则必须有的四个字段
<sec-four-fields>
不管是哪一类，这四个字段是强制的：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([字段], [作用], [如果缺了],),
  table.hline(),
  [#NormalTok("incident");], [产生它的那次失败], [半年后没人能判断它该不该留],
  [#NormalTok("fix_hint");], [怎么修], [Agent 换个写法再撞一次],
  [#NormalTok("sentinel_min");], [至少应该看到多少个事实], [#strong[规则坏了会表现成通过]],
  [档位], [拦截还是报数], [上线即停摆],
)
第三个字段在实现上是#strong[必填且类型上不能为零]（#ref(<sec-sentinel>, supplement: [第])）------ #strong[你没法写一条不带自检的规则。]

== 语义规则和文本规则的分界线在哪
<sec-semantic-boundary>
十四条语义规则、九条文本规则 ------ 这个分界线不是随意的， 它有一个清楚的判据：

#quote(block: true)[
#strong[这条规则要判断的东西，能不能从单行文本读出来？]
]

能 → 文本模式够用。不能 → 需要语义分析。

三个例子：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([规则], [需要知道什么], [够不够],),
  table.hline(),
  [禁止内联日志器], [这一行有没有那个构造调用], [#strong[单行够]],
  [禁止无条件跳过], [这一行的参数是不是常量], [#strong[单行够]],
  [禁止服务兜底], [这个 #NormalTok("??"); 左边的值是从哪来的], [#strong[单行不够]],
)
第三条需要知道：这个变量是不是从一个已知可选的访问器来的？ 它有没有被局部变量遮蔽？这个 #NormalTok("??"); 是不是在同一条语句里？ 右值是不是那个被明确允许的"不可用"？

#strong[四个问题，全都超出了单行的范围。]

而这个分界线有一个实用推论：

#quote(block: true)[
#strong[当你发现自己在给一条文本规则加第三个例外时， 它可能已经该变成语义规则了。]
]

因为例外的数量，正是"单行信息不够"的症状 ------ 每一个例外都是在用一个笨拙的方式补充上下文。

== 一条规则的可移植性
<sec-rule-portability>
这张表里有多少条能直接搬到别的仓库？诚实地估：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([类别], [可移植性],),
  table.hline(),
  [无条件跳过、注释代码、文件健康度], [#strong[高] ------ 概念和实现都通用],
  [单一日志 owner、协议优先], [#strong[中] ------ 概念通用，实现绑定语言],
  [服务兜底、访问器契约], [#strong[低] ------ 绑定这套微内核架构],
  [目标粒度、部署件归属], [#strong[低] ------ 绑定构建系统],
)
#strong[高可移植的只有三到四条。]

这个诚实的估计比"抄这二十三条"有用得多， 因为它把注意力引向了真正可移植的东西：#strong[不是规则，是方法。]

- #strong[怎么发现该有哪条规则]（#ref(<sec-two-months-late>, supplement: [第])）
- #strong[怎么调它的边界]（#ref(<sec-forbid-tuning>, supplement: [第])）
- #strong[怎么让它上线而不停摆]（#ref(<sec-four-steps>, supplement: [第])）
- #strong[怎么让它自检]（#ref(<sec-sentinel>, supplement: [第])）
- #strong[怎么判断它该退休]（#ref(<sec-rule-retirement>, supplement: [第])）

#strong[这五条方法，可移植性是百分之百。]

== 二十三条规则的分布说明了什么
<sec-distribution-meaning>
把这二十三条按"它守什么"归类，会看到一个不均匀的分布：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([守什么], [条数],),
  table.hline(),
  [#strong[单一 owner / 写入权]], [#strong[8]],
  [测试的可信度], [4],
  [分层与依赖方向], [4],
  [目标粒度与资源], [3],
  [代码即事实源], [2],
  [产品域特定], [2],
)
#strong[第一行占了三分之一以上。]

而加上路径不变量那二十份里的九份 （#ref(<sec-ownership-pattern>, supplement: [第])），#strong[整个规则体系里 超过 40% 在回答同一个问题：这块状态归谁写。]

这个分布不是设计出来的，是撞出来的 （#ref(<sec-rule-sources>, supplement: [第])）------ 也就是说：

#quote(block: true)[
#strong[在这个系统撞过的所有墙里， "同一份状态有两个写者"占了将近一半。]
]

这个数字给形状 B（#ref(<sec-shape-b>, supplement: [第])）提供了一个量化的支撑， 而它对读者的用处是：#strong[如果你只能防一个形状，防这个。]

== 第二行也值得注意
<sec-test-credibility-rules>
#strong[四条规则守的是"测试的可信度"，而不是"测试的覆盖"。]

- 无条件跳过
- 重试点击辅助函数
- 界面测试必须有可执行宿主
- 测试 bundle 经包装器

#strong[没有一条是"必须写测试"或"覆盖率必须达标"。]

这个选择很能说明这套系统的判断： #strong[覆盖率这类指标可以用别的方式保证（流程、评审、习惯）， 而"绿灯可不可信"必须有独立的守卫。]

因为前者失效时会被发现（覆盖率数字会掉）， #strong[后者失效时不会]（#ref(<sec-fake-green>, supplement: [第])）。

== 一条规则的"值不值"怎么算
<sec-rule-worth>
和路径清单那个算法（#ref(<sec-arbiter-value>, supplement: [第])）类似，但变量不同：

#Skylighting(([#NormalTok("收益 ≈ 违规发生的频率 × 每次违规漏进主干的代价");],
[#NormalTok("成本 ≈ 实现 + 调参 + 持续的误报打断");],));
而这个算式给出了一个反直觉的结论：

#strong[一条从来不报违规的规则，收益是零。]

不管它守的东西多重要 ------ 如果没有人试图违反它， 那么它没有拦住任何东西。

#strong[这就是 #ref(<sec-report-only-three>, supplement: [第]) 里那两条零违规的报数规则 处境尴尬的原因]：它们既不拦人（无保护）， 又没有违规（无收益），只是每次多跑一遍扫描。

#strong[而正确的处理不是删掉它们]，因为"现在没人违反" 不等于"以后没人违反" ------ 正确的处理是#strong[切成拦截]： 成本仍然接近零（不会误报，因为没有违规）， 而它从此提供了保护。

#strong[一条零违规的报数规则，是唯一一种可以零成本切成拦截的规则。] 而这套系统里有两条这样的规则，都还没切。

== 怎么用这张表
<sec-how-to-use>
#strong[不要从上往下抄。]

正确的用法是：#strong[读一遍，然后合上书，写下你团队在评审里 重复说得最多的那三句话。] 如果其中有一条和这张表里的某条重合， 那说明你已经"挣得"了那条规则，可以直接开始实现。

如果一条都不重合 ------ #strong[那就实现你自己那三条，别管这张表。] #ref(<sec-two-months-late>, supplement: [第]) 讲过为什么。

== 一张规则的自查表
<sec-rule-checklist>
对你自己的每一条规则，逐项打勾：

#Skylighting(([#NormalTok("□ 我能说出它诞生于哪次具体的失败");],
[#NormalTok("□ 它有 incident 字段（或等价的\"为什么有这条\"）");],
[#NormalTok("□ 它有 fix_hint 字段（或等价的\"怎么修\"）");],
[#NormalTok("□ 它有哨兵下限，且哨兵不能被关掉");],
[#NormalTok("□ 它上线时走了报数模式");],
[#NormalTok("□ 它的误报率我知道是多少");],
[#NormalTok("□ 它有一个有名字的 owner");],
[#NormalTok("□ 我知道它变成结构之后会是什么样");],));
#strong[八项，而大部分规则集能打勾的不超过三项。]

而这八项的价值不在于"全打勾才合格" ------ 在于#strong[每一个没打勾的项，都对应一种具体的死法]：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([没打勾的], [对应的死法],),
  table.hline(),
  [诞生原因], [半年后没人能判断它该不该留],
  [fix\_hint], [Agent 换个写法再撞一次],
  [哨兵], [规则坏了会表现成通过],
  [报数模式], [上线即停摆，然后被关掉],
  [误报率], [被绕过而你不知道],
  [owner], [没人判断它该不该退休],
  [结构化的终点], [规则集单调增长],
)
#strong[七种死法，#ref(<sec-three-deaths>, supplement: [第]) 讲了其中三种的检测方式。]

= 附录 B · 路径不变量全量表
<附录-b-路径不变量全量表>
= 附录 B · 路径不变量全量表
<sec-appendix-arbiters>
二十份清单，按风险等级排。

== 四条最高等级
<sec-critical-four>
它们守的都是#strong[不可逆]的东西。

#table(
  columns: (33.33%, 33.33%, 33.33%),
  align: (auto,auto,auto,),
  table.header([不变量], [禁止的新增], [出错的后果],),
  table.hline(),
  [#strong[迁移只演进 schema]], [整表清空 · 删库删 schema · 删分区 · 集群广播], [删掉的行没有任何回滚能还原],
  [#strong[不新增数据库外键]], [外键 · 级联 · 置空], [删除语义被数据库隐式决定，无法断言],
  [#strong[发布走指定通道]], [关掉预演 · 跳过确认], [外部副作用已经发生],
  [#strong[消费位点按已处理记录提交]], [批量提交 · 提前推进], [越过的记录永久丢失],
)
#strong[四条的共同点：出错之后重试也回不来。]

而这一点和 Agent 的行为模式直接冲突 ------ #strong["重试一次"恰恰是 Agent 遇到问题时最自然的反应]（#ref(<sec-risk-distribution>, supplement: [第])）。

== 十六条高等级
<sec-high-sixteen>
按主题分组：

#strong[归属类（占了将近一半）]

#table(
  columns: 1,
  align: (auto,),
  table.header([不变量],),
  table.hline(),
  [构建产物归属按工作区，宿主策略是唯一写者],
  [依赖生态只有一个 owner],
  [测试结论属于跑测试的那一方],
  [同上，CI 侧的对应约束],
  [持久化配置只有一个 owner],
  [跨产品身份表字面声明，不加载任何产品声明],
  [产品元数据由指定生成器在加载期投射],
)
#strong[七条的 id 里直接带着"归属"，另有两条的不变量文本里写着"只有一个 owner"] ------ #strong[超过一半的路径不变量在回答同一个问题：这块状态归谁写] （#ref(<sec-ownership-pattern>, supplement: [第])）。

#strong[契约类]

#table(
  columns: 1,
  align: (auto,),
  table.header([不变量],),
  table.hline(),
  [声明是四端接口类型的唯一事实源],
  [生成物必须由其事实源派生，改生成器不改产物],
  [共享服务协议优先、经微内核注册],
  [一个 owner 每执行环境一个测试 bundle],
  [新增可发布产物必须同时登记类型],
  [埋点的交互粒度：一次用户意图对应一条事件],
  [收入字段的词表：写入侧归一函数与消费侧声明必须同时改],
)
== 一份清单里最值钱的不是禁止模式
<sec-invariant-text-value>
看两份清单的对比：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([], [一份典型的], [那份收入词表的],),
  table.hline(),
  [禁止模式], [七条], [#strong[空的]],
  [不变量文本], [三行], [#strong[一大段，含一次完整的事故复盘]],
)
#strong[空的禁止模式是刻意的]，而注释里写明了原因：

#quote(block: true)[
这条不变量是"两处必须同时改"，不是"某个字面量不许出现"。 执行力由检查通道承担。
]

#strong[知道一个机制表达不了什么，比会用这个机制更难。]

而那段不变量文本里记着一次完整的事故：一端写大写、一端写小写、 下游过滤器比小写，#strong[三方各自都有测试且各自都绿]， 而某一类收入数据一行都进不了任何报表。

#strong[这段文字是这份清单里最有价值的部分]， 它比七条禁止模式加起来更能防住下一次同类问题 ------ 因为下一次的形态一定不一样，而理解了机制的人能认出它。

== 二十份清单的覆盖面盘点
<sec-coverage-audit>
值得看一眼这二十份覆盖到了什么、漏了什么。

#strong[覆盖到的：]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([领域], [份数],),
  table.hline(),
  [构建与产物归属], [4],
  [服务与运行时契约], [3],
  [数据与迁移], [3],
  [发布与交付], [2],
  [测试判定归属], [2],
  [埋点与数据管道], [3],
  [产品元数据与身份], [3],
)
#strong[明显没有覆盖的：]

- #strong[工具链自己]（#ref(<sec-toolchain>, supplement: [章节])）------ 那 28 条定时任务不在任何清单的路径下
- #strong[基础设施配置] ------ 容器编排、网络、存储的配置文件
- #strong[依赖升级] ------ 引入或升级外部依赖没有专门的不变量

第一条是这套系统已经自己承认的缺口。 #strong[而后两条更有意思，因为它们连"缺口"都还没被识别出来。]

依赖升级那条尤其值得说：一次外部依赖的升级， 可能同时改变构建行为、运行时行为和安全面 ------ #strong[它满足"高风险 + 需要额外上下文"这两个条件]， 按这套系统自己的标准，它应该有一份清单。

它没有的原因大概率是：#strong[这类事故还没有发生过。] 而这完全符合 #ref(<sec-two-months-late>, supplement: [第]) 那条 ------ 规则是从失败里长出来的，所以规则集的形状， 就是这个系统撞过的墙的形状。

#strong[这既是它的优点（没有装饰性规则），也是它的局限（覆盖面等于经验面）。]

== 六个字段各自能省掉什么
<sec-field-savings>
用"如果没有这个字段会怎样"来说明每个字段的价值：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([字段], [没有它会怎样],),
  table.hline(),
  [#NormalTok("paths");], [这份清单永远不会被触发，等于不存在],
  [#NormalTok("risk");], [Agent 无法判断该多谨慎，会用同一种态度对待所有路径],
  [#NormalTok("invariant");], [#strong[只知道不能做什么，不知道为什么] → 换个写法绕过去],
  [#NormalTok("read");], [需要的背景知识不在场，Agent 会基于不完整的理解动手],
  [#NormalTok("forbid");], [没有机器执行的部分，全靠自觉],
  [#NormalTok("checks");], [改完之后不知道该跑什么来验证],
)
#strong[第三行的代价最大]，而它最容易被省 ------ 因为 #NormalTok("forbid"); 看起来已经表达了同样的意思。

#strong[但它们表达的不是同一件事]：#NormalTok("forbid"); 是一个列举， #NormalTok("invariant"); 是一个原则。#strong[列举可以被绕过，原则不能。]

== 二十份清单的规模分布
<sec-arbiter-sizes>
一个观察：这二十份清单的长度差别很大。

最短的只有几行 ------ 路径、一句不变量、几个禁止模式。 最长的那份，#strong[光 #NormalTok("invariant"); 一个字段就是一大段]， 包含了一次完整的事故复盘（#ref(<sec-invariant-text-value>, supplement: [第])）。

#strong[而长度和风险等级不相关。]

那份最长的是"高"，不是"最高"。它长是因为 #strong[它守的那条不变量最难被理解] ------ 它涉及三个系统、两种大小写、一个下游过滤器， 而且三方各自的测试都是绿的。

#strong[所以清单的长度应该由"理解这条不变量需要多少背景"决定， 而不是由"它多重要"决定。]

这条在写清单时很实用：#strong[写完之后问一句， 一个不了解这个系统的人读完这段，能不能自己判断 一个新的写法算不算违反？] 不能 → 还得补。

== 一份清单最容易犯的错
<sec-arbiter-mistakes>
三个，按频率排：

#strong[一、路径写得太宽。] 一份覆盖 #NormalTok("src/**"); 的清单会在几乎每次改动时触发， 然后它的输出会变成背景噪音（#ref(<sec-report-only-cost>, supplement: [第])）。

#strong[判据]：如果一份清单在超过三分之一的改动上触发，它太宽了。

#strong[二、#NormalTok("forbid"); 里放了"所有危险的东西"。] #ref(<sec-ttl-allowed>, supplement: [第]) 讲过：规则要守的是"不该发生的动作"， 不是"所有危险的动作"。

#strong[三、#NormalTok("invariant"); 写成了规则的复述。] "禁止使用 X" 不是不变量，是禁令的复述。 #strong[不变量应该是一个陈述句，描述一个必须保持为真的事实] ------ "这张表的每一行都能被追溯到一个源事件"是不变量， "禁止直接插入这张表"是它的一个执行手段。

== 怎么判断自己漏了哪条路径
<sec-find-missing-paths>
不用等事故，有一个可以主动做的盘点：

#strong[第一步]：列出你系统里所有"做错了重试挽回不了"的动作。 提示：涉及外部世界的、涉及删除的、涉及钱的、涉及身份的。

#strong[第二步]：对每一个，问"哪些文件的改动可能导致它"。

#strong[第三步]：那些文件的路径，就是候选清单。

#strong[第四步]：对每一条候选，问"这条路径上有没有一个只有某个人知道的讲究"。 有 → 立刻写下来，那正是最该被清单化的东西 （#ref(<sec-premise-routing>, supplement: [第]) 讲过为什么）。

#strong[这个盘点通常一两个小时就能做完，而它的产出是一份优先级清单。]

== 一份清单的最小形态
<sec-minimal-arbiter>
给读者直接抄：

#Skylighting(([#NormalTok("路径：      Backends/**/migrations/**/*.up.sql");],
[#NormalTok("风险：      最高");],
[#NormalTok("必须保持：  迁移只演进 schema，绝不整表清空或删分区。");],
[#NormalTok("            删除一张退役的表是可接受的演进，");],
[#NormalTok("            但清空和删分区删掉的行，没有任何回滚能还原。");],
[#NormalTok("动手前读：  <你们的数据完整性约定>");],
[#NormalTok("            <迁移执行器的源码>");],
[#NormalTok("完成后跑：  <你们的后端检查命令>");],));
#strong[先不要写禁止模式。] 它需要拿你自己仓库的真实数据来调 （#ref(<sec-forbid-tuning>, supplement: [第])），而你现在还没有那个数据。

= 附录 C · 一份常驻文件的逐行注解
<附录-c-一份常驻文件的逐行注解>
= 附录 C · 一份常驻文件的逐行注解
<sec-appendix-always-on>
一份 #strong[153 行]的常驻文件，管 #strong[3,104,960 行]代码。比例约 #strong[1:20,000]。

这份附录不复述那份文件，而是挑几条做深度注解 ------ #strong[因为它们的写法比它们的内容更值得学。]

== 注解一：一条禁令的完整形态
<sec-annot-sed>
#quote(block: true)[
#strong[绝不用原地批量替换修改文件。] 一个为你推理过的那些调用点写的模式，也会重写你没有推理过的： 已经应用过的 SQL 迁移、生成的锁文件、fixture 与 golden 数据、 设计文档、CI 配置。#strong[损坏是静默的] ------ 构建照样通过， diff 大到没法逐行看，#strong[而一个被重写的迁移在已经跑过它的数据库里无法撤销]。 用版本控制的移动命令移动文件，然后搜索剩余引用，逐个打开、逐个改。 一次跨几百个文件的重命名也是这么做：先枚举全部命中， 提交前读一遍每一个非机械文件的 diff。
]

#strong[结构拆解：]

#table(
  columns: (50%, 50%),
  align: (auto,auto,),
  table.header([部分], [作用],),
  table.hline(),
  ["绝不用……"], [禁令本身 ------ 一行],
  ["也会重写你没有推理过的：……"], [#strong[失败机制]，带五个具体的受害者],
  ["损坏是静默的"], [#strong[为什么这个失败特别危险]],
  ["而一个被重写的迁移……无法撤销"], [#strong[不可逆性]],
  ["用移动命令……逐个改"], [#strong[替代方案]],
  ["一次跨几百个文件的重命名也是这么做"], [#strong[堵住"但我这次量很大"这个例外]],
)
#strong[六个部分，缺一不可。] 大部分团队的规范只写了第一部分。

而最后一部分尤其值得学：#strong[它预判了这条规则最可能被绕过的理由。] "我这次要改三百个文件，逐个改不现实" ------ 这是每个人（和每个 Agent） 第一个会想到的例外，而规则提前回答了它。

== 注解二：一条带验证动作的规则
<sec-annot-recursive>
#quote(block: true)[
#strong[绝不对仓库根目录跑递归命令。] 兄弟工作区就住在树内部，所以递归搜索和从它们管道出来的一切 都会走进每一个其它检出 ------ 一次写入会同时到达几十个不相干的 worktree， 在你从没看过的分支下。把每一次递归读取和每一次批量编辑 限定到任务拥有的具体目录，#strong[并在动作之前确认匹配列表里没有工作区路径。]
]

最后半句是关键：#strong[它给了一个可执行的验证步骤。]

对比"请小心使用递归命令" ------ 后者对 Agent 等于不存在， 因为"小心"不是一个可以执行的动作。

#strong[一条规则如果只说"要小心"，它不是规则，是祈祷。]

== 注解三：一条规则给了三个判例
<sec-annot-earned>
目录可选层那条（#ref(<sec-earned-level>, supplement: [第])）不只是说"每层必须被挣得"， 而是紧接着给了三个真实路径：

- 双平台的产品长什么样
- 多进程的产品长什么样
- 单平台单进程的产品长什么样

#strong[判例的作用是让规则可以被机械地应用。]

一个 Agent 遇到一个新产品时，不需要理解"挣得"这个概念的哲学含义， 它只需要把当前情况和三个判例比对。

#strong[规则 + 判例，比规则 + 解释更管用。]

== 注解四：预判 Agent 会怎么想错
<sec-annot-agent-failures>
文件里有几句不是在描述架构，是在描述#strong[Agent 的失败方式]：

#quote(block: true)[
把评审和追问当成#strong[提高抽象层级的信号]，而不是打点修复的请求。
]

Agent 收到"这里有问题"时的默认反应是修那个点。 这句话改变的是它对反馈的解读方式。

#quote(block: true)[
不要在一个重复的机制之上打磨业务 bug。
]

它预判的是：Agent 会在一个本该被上移的重复机制上， 一次次地修表面症状。

#quote(block: true)[
有"页面"这个词、或者能被展示，都不足以让它成为一个页面。
]

它预判的是：Agent 会按名字和直觉分类，而不是按获取方式分类。

#strong[这三句的共同点：它们是观察的产物，不是设计的产物。] 写这三句的人看着 Agent 在这些地方失败过。

== 注解五：一条规则的压缩
<sec-annot-compression>
常驻文件的克制不是靠删规则达到的，是靠#strong[压缩]。

看这条关于共享基础设施的规则，它压缩了大量内容：

#quote(block: true)[
#strong[实现任何能力之前，先勘察共享基础设施]：搜索共享层的全部子树、 相关平台的子树，以及所属部署件的共享包。找找有没有现成的机制 提供了全部或大部分能力（提示、存储、重试、队列、窗口、主题、密钥……）。 #strong[默认复用或扩展现有基础设施，充分利用它优先于写新代码。 重新实现一个共享层已经提供的能力是一个缺陷。] 只有在确认没有匹配之后才动手建。
]

#strong[这一条压缩了什么：]

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([压缩掉的内容], [它被压成了],),
  table.hline(),
  [共享层有哪些子树], [一句"搜索全部子树"],
  [有哪些现成机制], [括号里的七个例子],
  [怎么判断"匹配"], ["全部或大部分能力"],
  [违反的后果], [#strong["是一个缺陷"这四个字]],
)
#strong[最后一行是压缩率最高的部分。]

"重新实现一个共享层已经提供的能力是一个缺陷" ------ 这句话把一个价值判断（"我们希望大家复用"） 变成了一个#strong[分类判断]（"这属于缺陷"）。

而这个转换有实际效果：一个缺陷会被修， 一个"希望"不会。#strong[它把这条规则接进了已有的处理流] （#ref(<sec-dashboard-nobody-reads>, supplement: [第]) 讲过这条原则）。

== 注解六：那些没有出现在这份文件里的东西
<sec-annot-absent>
一份 153 行的文件，同样重要的是它#strong[不包含]什么。

对照一份典型的团队规范，下面这些通常会有，而这里没有：

#table(
  columns: 2,
  align: (auto,auto,),
  table.header([常见但这里没有的], [它去哪了],),
  table.hline(),
  [代码风格（缩进、命名格式）], [交给格式化工具，零人工],
  [提交信息格式], [没有强制],
  [分支命名规范], [没有强制（工作区名是生成的）],
  [各种"最佳实践"清单], [#strong[要么进结构，要么不存在]],
  [技术选型指南], [进了按需查阅的说明],
  [目录清单 / 模块索引], [文件后半部分有，但只是引用性质],
)
#strong[前三行的共同点：它们都可以被工具无成本地保证， 所以不需要占用注意力。]

第四行是最重要的：#strong["最佳实践"这类内容之所以不在， 是因为它们无法通过 #ref(<sec-always-on-criteria>, supplement: [第]) 的第二条测试] ------ 写不出具体的失败形态。

一条写不出失败形态的"最佳实践"，本质上是品味 （#ref(<sec-testability-judge>, supplement: [第]) 讲过怎么对待品味）。

== 一份常驻文件的健康指标
<sec-always-on-health>
给三个可以定期自查的数：

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([指标], [健康值], [为什么],),
  table.hline(),
  [行数 / 代码行数], [越小越好，这里是 1:20,000], [稀释效应],
  [#strong[写不出失败形态的条目占比]], [#strong[应为 0]], [它们不是规则],
  [#strong[能写进结构却没写的条目占比]], [越小越好], [每一条都是一次错过的前馈],
)
第三个指标最难测，但它可以被近似： #strong[过去半年里，有几条规则从这份文件里被删除， 因为它对应的问题已经在结构上消失了？]

如果是零，那说明"把规则变成结构"这条路径没有在走 （#ref(<sec-rule-count>, supplement: [第]) 讲过同样的判据）。

== 注解七：文件的后半部分是一份地图
<sec-annot-map>
那 153 行不全是规则。后半部分是一份#strong[目录地图] ------ 哪个顶层目录放什么、文档该归到哪。

而这部分值得单独说，因为它示范了一个取舍：

#quote(block: true)[
#strong[地图信息该不该占用常驻文件的位置？]
]

按 #ref(<sec-always-on-criteria>, supplement: [第]) 那三条判据，答案应该是"不该"------ 地图可以被 Agent 自己看目录得到，它不需要被"记住"。

#strong[而它仍然在那里，理由是：目录名不等于目录的用途。]

看到 #NormalTok("Docs/"); 这个名字，Agent 会假设"文档放这里"。 而这套系统的实际规则是相反的：

#quote(block: true)[
#strong[一份文档由它描述的东西拥有，不由一个 #NormalTok("Docs/"); 桶拥有。] #NormalTok("Docs/"); 只剩两类，而且两类都不是工程材料的家。
]

#strong[这条规则必须常驻，因为它推翻的是一个非常强的先验] （#ref(<sec-why-carriers-work>, supplement: [第]) 的第二个机制）。

#strong[而这给出了一条判据的补充]： 当一个结构的名字会误导 Agent 时，纠正它值得占用常驻位置。

== 注解八：这份文件的自我约束
<sec-annot-self>
最后一处值得注意的：#strong[这份文件对自己也有约束。]

配套的说明里写着：必须无条件触发的规则要留在这份文件本体， 不能挪进按需发现的地方（#ref(<sec-unconditional-stays>, supplement: [第])）。

#strong[这是一条关于"什么该放进这份文件"的规则， 而它本身就放在这个体系里。]

它的效果是：#strong[当有人想把一条规则挪出去以缩短文件时， 这条约束会先拦住他] ------ 而这正是常驻文件最常见的腐化方式 （#ref(<sec-how-it-grows>, supplement: [第]) 的反向：为了瘦身而把无条件规则挪走）。

#strong[一个体系如果不能约束自己的演化方式，它会在维护中漂移。]

而这条自我约束的成本是一句话，收益是防住了一整类错误的重构。

== 从这份文件能学到的三条
<sec-three-lessons-c>
#strong[一、长度是一个设计约束，不是一个结果。] 153 行不是"写着写着就这么长了"，是#strong[被守住的]。 而守住它的方式是：每加一条，先问那三条判据。

#strong[二、每一条规则的形状是固定的。] 禁令 + 失败机制 + 不可逆性（如果有）+ 替代方案 + 例外的堵截。 #strong[固定的形状让规则可以被快速扫描]，也让缺失的部分一眼看出来。

#strong[三、它预判了读者会怎么想错。] #ref(<sec-annot-agent-failures>, supplement: [第]) 里那三句 ------ 它们不描述系统， 描述的是#strong[Agent 的失败方式]。

而第三条是最难做到的，因为它需要#strong[观察]： 你得先看着 Agent 在某个地方失败很多次， 才能写出那一句预判。

#strong[这也是为什么一份好的常驻文件不可能被一次写成] ------ 它的质量取决于你观察了多久。

== 怎么用这份附录
<sec-how-to-use-c>
打开你自己的常驻文件，对每一条问三个问题：

#strong[一、它有失败形态吗？] 没有的话，补上；补不出来的，删掉。

#strong[二、它有可执行的验证动作吗？] 如果它说的是"注意""小心""尽量"，它不是一条规则。

#strong[三、它能被写进结构吗？] 能的话，写进去，然后从这份文件里删掉。 #strong[这一条通常能砍掉最多。]

三个问题过一遍，大部分团队的常驻文件会掉下去一半以上 ------ #strong[而剩下的那一半，每一条的到达概率都提高了。]

== 一份常驻文件的最小版本
<sec-minimal-always-on>
给一个可以直接抄的骨架，适用于任何规模：

#Skylighting(([#FunctionTok("# 仓库指导");],
[],
[#FunctionTok("## 动手原则");],
[#SpecialStringTok("- ");#NormalTok("改代码前，先问这次改动涉及哪个不变量、它的 owner 是谁。");],
[#NormalTok("  在 owner 那里修，不在症状点打补丁。");],
[#SpecialStringTok("- ");#NormalTok("实现任何能力之前，先搜共享层有没有现成的。");],
[#NormalTok("  重新实现共享层已经提供的东西是一个缺陷。");],
[],
[#FunctionTok("## 不许做的事（每条带失败形态）");],
[#SpecialStringTok("- ");#NormalTok("绝不批量原地替换文件。");#CommentTok("[");#OtherTok("失败形态：...");#CommentTok("]");],
[#SpecialStringTok("- ");#NormalTok("绝不对仓库根跑递归命令。");#CommentTok("[");#OtherTok("失败形态：...");#CommentTok("]");],
[#SpecialStringTok("- ");#CommentTok("[");#OtherTok("你自己的第三条");#CommentTok("]");],
[],
[#FunctionTok("## 结构");],
[#SpecialStringTok("- ");#CommentTok("[");#OtherTok("三到五行，说明目录怎么组织，以及一条判据");#CommentTok("]");],
[],
[#FunctionTok("## 验证");],
[#SpecialStringTok("- ");#NormalTok("改完必须跑 ");#CommentTok("[");#OtherTok("你的检查命令");#CommentTok("]");#NormalTok("，不通过不算写完。");],
[#SpecialStringTok("- ");#NormalTok("退出码 2 表示环境问题，不要改代码。");],
[#SpecialStringTok("- ");#NormalTok("修 bug 时，先让新测试红一次再让它绿。");],));
#strong[大概 30 行，而它覆盖了这本书里成本最低、收益最高的那几条。]

=== 为什么这个骨架长这样
<sec-skeleton-rationale>
四个小节，各对应一件事：

#strong["动手原则"] ------ 它们是无法被结构表达的 （#ref(<sec-always-on-criteria>, supplement: [第]) 的第三条测试没通过）， 所以必须常驻。

#strong["不许做的事"] ------ 每一条都是不可逆或静默的 （第二条测试），所以必须在落笔前在场。

#strong["结构"] ------ 只有三到五行，因为#strong[大部分结构信息 由目录自己传递]（#ref(<sec-codebase-oneline>, supplement: [第])）， 这里只写目录名传递不了的那部分。

#strong["验证"] ------ 它们是判定层和 Agent 之间的接口， 而这个接口必须无条件生效（#ref(<sec-consumer>, supplement: [第])）。

#strong[四个小节，而没有"代码风格"那一节] ------ 因为那些交给格式化工具，零人工（#ref(<sec-annot-absent>, supplement: [第])）。

= 附录 D · 术语表
<附录-d-术语表>
= 附录 D · 术语表
<sec-appendix-glossary>
== 判定相关
<sec-glossary-verdict>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([中文], [英文], [一句话], [首见],),
  table.hline(),
  [判定], [verdict], [一次检查得出的结论，绑定在它观察到的那个版本上], [#ref(<sec-three-failures>, supplement: [章节])],
  [内容违规], [policy violation], [这次改动触碰了规则，退出码 1], [#ref(<sec-cannot-judge>, supplement: [第])],
  [基建故障], [infrastructure failure], [判不了，退出码 2], [#ref(<sec-cannot-judge>, supplement: [第])],
  [假绿], [---], [测试通过但实际没有验证任何行为], [#ref(<sec-fake-green>, supplement: [第])],
  [变异验证], [mutation verification], [拿掉修复，测试必须重新变红], [#ref(<sec-mutation>, supplement: [第])],
  [哨兵下限], [sentinel], [一条规则至少应该看到多少个事实], [#ref(<sec-sentinel>, supplement: [第])],
  [报数模式], [report-only], [测量并报告，但不拦截], [#ref(<sec-enforce-levels>, supplement: [第])],
  [债务台账], [baseline], [被审阅过的历史违规清单，#strong[只允许单调收敛]], [#ref(<sec-baseline>, supplement: [第])],
)
#strong[容易混淆的两组：]

- #strong[判定 vs 检查] ------ 判定是结论，检查是产生结论的动作
- #strong[报数模式 vs 豁免] ------ 前者#strong[仍在测量]，后者#strong[不再测量]

== 结构相关
<sec-glossary-structure>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([中文], [英文], [一句话], [首见],),
  table.hline(),
  [不变量], [invariant], [一条必须保持的事实], [#ref(<sec-arbiter>, supplement: [章节])],
  [载体], [---], [规则存放的地方，由"什么时候需要到达"决定], [#ref(<sec-five-carriers>, supplement: [第])],
  [被挣得], [earned], [一个结构层必须由真实的第二个实例证成], [#ref(<sec-earned-level>, supplement: [第])],
  [单一写者], [single writer], [一份可变状态只有一个地方能改], [#ref(<sec-shape-b>, supplement: [第])],
  [组合根], [composition root], [唯一知道自己 owner 全部依赖的地方], [#ref(<sec-role-buckets>, supplement: [第])],
  [稀疏测量], [---], [只观测本次真正变化的那个子空间], [#ref(<sec-walls-restated>, supplement: [第])],
)
#strong[容易混淆的一组：]

- #strong[不变量 vs 规则] ------ 不变量是必须保持的#strong[事实]，规则是它的#strong[可执行形态]。 一个不变量可以没有规则（靠人评审），一条规则背后一定有一个不变量。

== 控制相关
<sec-glossary-control>
#table(
  columns: (25%, 25%, 25%, 25%),
  align: (auto,auto,auto,auto,),
  table.header([中文], [英文], [一句话], [首见],),
  table.hline(),
  [回路], [loop], [测量 → 比较 → 修正 → 再测量], [#ref(<sec-control-model>, supplement: [第])],
  [前馈], [feedforward], [在扰动产生影响之前补偿掉它], [#ref(<sec-ground-and-walls>, supplement: [第])],
  [反馈], [feedback], [测量输出，发现偏差后修正], [#ref(<sec-ground-and-walls>, supplement: [第])],
  [被控对象], [plant], [你要控制的那个东西], [#ref(<sec-control-model>, supplement: [第])],
  [增益], [gain], [每单位测得的误差，施加多少修正], [#ref(<sec-two-variables>, supplement: [第])],
  [回路延迟], [loop delay], [从产生改动到判定回到手里的时间], [#ref(<sec-two-variables>, supplement: [第])],
  [串级控制], [cascade], [快内环抑制大部分扰动，慢外环处理漏过来的], [#ref(<sec-cascade>, supplement: [第])],
  [死区], [deadband], [误差在某个范围内时不动作], [#ref(<sec-deadband>, supplement: [第])],
  [抗积分饱和], [anti-windup], [防止追一个到不了的目标时修正量无界增长], [#ref(<sec-cross-session>, supplement: [第])],
  [传感器故障], [sensor fault], [测量本身坏了，而不是被测的东西坏了], [#ref(<sec-sensor-faults>, supplement: [章节])],
  [解析冗余], [analytical redundancy], [用第二个独立通道验第一个], [#ref(<sec-analytical-redundancy>, supplement: [第])],
  [机内自检], [BITE], [主动注入已知故障，看传感器响不响], [#ref(<sec-bite>, supplement: [第])],
  [观测器], [observer], [用模型加可测量，估计测不到的状态], [#ref(<sec-not-more-sensors>, supplement: [第])],
  [可观测性], [observability], [能否从输出推出内部状态], [#ref(<sec-observability>, supplement: [第])],
  [参考输入], [setpoint / reference], [输出应该是多少，#strong[必须来自回路之外]], [#ref(<sec-no-self-setpoint>, supplement: [第])],
  [稳定裕度], [stability margin], [距离失稳还剩多少余量], [#ref(<sec-margin-shrinking>, supplement: [第])],
)
#strong[容易混淆的两组：]

- #strong[前馈 vs 反馈] ------ 按#strong[有没有用到输出]来分，#strong[不按快慢分]。 一个很快的检查仍然是反馈。
- #strong[增益 vs 吞吐] ------ 增益是#strong[每单位误差]施加的修正，吞吐是单位时间的产出。 两者在这本书里高度相关，但不是同一个量。

== 这本书刻意避免的几个词
<sec-avoided-terms>
有些常用词在这本书里被刻意避开了，理由值得说明 ------ 因为#strong[词的选择会影响思考的形状]。

#table(
  columns: 3,
  align: (auto,auto,auto,),
  table.header([避开的词], [用了什么], [为什么],),
  table.hline(),
  ["AI 编码规范"], [载体、判定边界], [它暗示这是一份给人看的文档],
  ["提示词工程"], [---------], [这本书的立场是问题不在那一层],
  ["质量门禁"], [判定], ["门禁"只有通过/不通过两态],
  ["最佳实践"], [---------], [写不出失败形态的建议不该被叫做实践],
  ["AI 幻觉"], [语义失败], ["幻觉"是拟人化的，而且它暗示这是偶发的],
  ["自动化"], [判定 / 观测器], [太笼统，掩盖了"它在做什么"这个问题],
)
#strong[第三行值得展开。]

"门禁"这个词自带一个两态的模型：开或关，通过或拒绝。 而这本书的核心主张之一，就是#strong[两态是不够的] （#ref(<sec-cannot-judge>, supplement: [第])）------必须有第三态。

#strong[用"门禁"这个词思考，很难想到第三态； 用"判定"这个词，第三态是自然的（判不了也是一种判定结果）。]

而第五行同样重要：把语义失败叫做"幻觉"， 会让人以为它是一种偶发的、可以被消除的缺陷。

#strong[它不是。] 它是"从一个你无法完整指定的分布里采样" 的必然结果（#ref(<sec-codec-broken>, supplement: [第])）。而这个认识决定了修法： 不是去消除它，是#strong[在它外面闭一个带测量的回路]。

== 几个词的中英对应有争议
<sec-translation-notes>
诚实地标注几处翻译取舍：

#strong[invariant → 不变量]。数学上通常译"不变式"， 但在工程语境下"不变量"更常见，且不易和"表达式"混淆。

#strong[verdict → 判定]。也可译"裁定""结论"。选"判定"是因为 它同时是名词和动作，而这套系统里两者确实是同一件事 （一次检查产生一个判定）。

#strong[plant → 被控对象]。控制论标准译法。字面是"设备/装置"， 在这本书里指的是模型加上它的运行环境。

#strong[setpoint → 参考输入]。也可译"设定点"。 两者在书里交替使用，因为"设定点"更直观， 而"参考输入"更强调它来自回路之外（#ref(<sec-no-self-setpoint>, supplement: [第])）。

#strong[feedforward → 前馈]。这个词容易和"前置"混淆。 它的准确含义是：#strong[在测量到误差之前就施加的控制作用]， 依据是对扰动的先验知识，不是对输出的观测。

== 按主题重新索引
<sec-thematic-index>
术语按定义分了三组，这里按#strong[你在什么情况下会需要它们]再索引一遍。

=== 当你在设计一道检查时
<sec-index-designing-check>
判定 · 内容违规 · 基建故障 · 哨兵下限 · 报数模式 · 债务台账

#strong[核心问题]：这道检查坏了会表现成什么？（#ref(<sec-sensor-self-check>, supplement: [第])）

=== 当你在决定一条规则放哪时
<sec-index-placing-rule>
载体 · 前馈 · 反馈 · 不变量

#strong[核心问题]：它什么时候需要到达？（#ref(<sec-five-carriers>, supplement: [第])）

=== 当你在排查一次故障时
<sec-index-debugging>
假绿 · 单一写者 · 可观测性 · 观测器

#strong[核心问题]：七个形状里，这次是哪一个？（#ref(<sec-find-your-shapes>, supplement: [第])）

=== 当你在判断该不该继续投入时
<sec-index-investing>
增益 · 回路延迟 · 稳定裕度 · 串级控制 · 参考输入

#strong[核心问题]：现在的瓶颈在哪一侧？（#ref(<sec-when-to-stop>, supplement: [第])）

== 三个最容易被误用的词
<sec-most-misused>
#strong[一、"判定"不等于"检查"。]

一次检查可能产出三种判定之一，而#strong["判不了"也是一种判定]。 把两者混用会让人忘掉第三态的存在（#ref(<sec-two-to-three>, supplement: [第])）。

#strong[二、"覆盖"不等于"守住"。]

覆盖率说的是"跑到了"，而这本书关心的是"守住了" ------ 两者的差距就是假绿的全部藏身之处（#ref(<sec-coverage-devalued>, supplement: [第])）。

#strong[三、"自动化"不等于"有判定"。]

一个自动化的任务如果不产生任何可被消费的结论， 它只是"自动地做了一件事"，而不是"自动地判断了一件事"。

#strong[那 28 条定时任务全都是自动化的，而它们没有一条产生判定] （#ref(<sec-signing-failure>, supplement: [第])）------ 这个区分是那个四个月缺口的核心。

== 一句话记住整本书的词汇
<sec-vocabulary-summary>
如果把这份术语表压成一句话：

#quote(block: true)[
#strong[在一个你不能控制输出的系统外面， 用可信的测量（判定）画出边界（不变量）， 让规则在正确的时刻到达（载体）， 并且始终知道测量本身还活着（哨兵、冗余、自检）。]
]

#strong[四个括号，对应这本书的四个部分。]

== 保留英文的
<sec-glossary-english>
#table(
  columns: 2,
  align: (auto,auto,),
  table.header([词], [为什么不译],),
  table.hline(),
  [worktree], [它是版本控制的命令名],
  [skill / guide], [它们是这套体系里的专有角色名],
  [flake], ["偶发失败"没有它准确，而且它已是通用术语],
)



