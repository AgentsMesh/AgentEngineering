# 失败形状表

> 研究件，不是章节。这张表的作用是把 AIO 的 46 篇事故记录、23 条架构规则的
> `incident` 字段、20 份 ARBITER 的 `invariant`，收敛成可迁移的**形状**。
>
> 纪律：书里**不出现任何与 `Troubleshooting/` 一一对应的章节**。事故是论据，
> 不是内容单位。每个实例进书时压到 300–800 字，且必须保留事故记录里通常没有
> 的那一半 —— 当时相信的是什么、为什么那个假设合理、什么信号推翻了它。

---

## 为什么按形状组织而不是按事件

一次事故是一个点。读者的系统里没有 Loki、没有 Bazel、没有 XCTest，
所以「Loki retention 配了仍累积」对他没有任何用。

但**四个不同的层上出现同一个形状**，就成了可迁移的知识 —— 因为读者的系统里
一定有那个形状，只是穿着别的衣服。

46 篇事故 + 23 条规则收敛到 **7 个形状**。这 7 个形状就是全书的骨架。

---

## 形状 A · 探针测的不是你以为的东西

**核心**：检查通过了，但它检查的根本不是那件事。这是全书最重要的形状，
也是 Agent 场景下最危险的一个 —— 因为让一个断言通过，永远比让一个行为正确要容易。

| 层 | 实例 | 探针实际测的 | 你以为它测的 |
|---|---|---|---|
| 运维 | Grafana 直连 `/api/health` 返 200，登录返 500 | 读路径 | 服务可用 |
| 构建 | `--test_filter` 给裸方法名，0 个用例，Bazel 报 PASSED | Bazel target 存在 | 用例通过 |
| 构建 | UI XCTest 只有 `swift_library` 没有 `ios_ui_test` host | 编译成功 | 用例执行 |
| 测试 | `XCTSkipIf(true)` | 测试文件还在 | 场景被覆盖 |
| 定时任务 | `profile_auto_refresh` panic 四个月，构建全绿 | 什么都没测 | 签名健康 |

**通用形态**：探针和被测对象之间存在一条**未被验证的因果假设**。
`health=200` 假设「能读 ⇒ 能写」；`PASSED` 假设「target 跑完 ⇒ 用例跑过」。
假设不成立的那天，探针不会告诉你，因为探针本身没坏。

**书里的位置**：@sec-tests（假绿专题）· @sec-sensor-faults（传感器测错量）
**AIO 的解药**：变异验证 · `sentinel_min` · `Executed N tests` 且 N≠0

---

## 形状 B · 同一份状态有两个写者

**核心**：可变状态没有唯一 owner，于是行为取决于谁最后写。
AIO 里超过一半的路径不变量在回答这一个问题。

| 层 | 实例 | 两个写者是谁 |
|---|---|---|
| iOS 音频 | 录音后编辑器播放静默失败 | 多方各自 `setCategory/setActive`，互不知晓 |
| 构建 | k3s 首跑 bazel server 崩溃 | 同节点并发 Pod 共享一个 output base |
| 测试 | UI e2e 偶发 SIGSEGV | 无锁的共享 fake |
| 后端 | OAuth 空邮箱用户串号 | 空邮箱被当成同一身份 |
| 数据 | 服务端退款一行不进报表 | 服务端写 `Production`、客户端写 `production` |
| 计费 | 两个 entitlement 真相源 | 注入了 StoreService 却仍直读 StoreKit |

**通用形态**：写入权没有被显式收敛，于是它被**隐式地**分给了所有能写的人。
排查困难在于：每个写者单独看都是对的，各自的测试也都是绿的。

**书里的位置**：@sec-architecture（单一 writer）· @sec-arbiter（七份 ownership 不变量）
**AIO 的解药**：owner-first · `NO-SERVICE-FALLBACK` · `*-SINGLE-OWNER` 系列规则

---

## 形状 C · 修了实例，没修机制（复发）

**核心**：同一个问题第二次出现，说明该上移的是机制，不是再修一次。
**这个形状最有力的证据来自 AIO 自己：磁盘满在 46 篇里出现了五次。**

| 日期 | 表象 | 那次的根因 | 那次的修法 |
|---|---|---|---|
| 02-17 | Mainline 登录 500 | 磁盘满 → Redis AOF 损坏 | 清盘 |
| 02-18 | CI job 失败 | Docker 磁盘耗尽 | 清盘 |
| 02-20 | 全站 500 | Loki 日志插件缓存撑满 | 清盘 |
| 03-05 | monitoring-vm 满 | Loki 无 retention | **配 retention 168h** |
| 04-29 | monitoring-vm 又满 | **retention 配了，但与容量不匹配** | 调参 |
| 04-28 | AccessProxy 满 | Traefik 容器日志 | 清盘 |
| 08-02 | PostHog 满 | ZooKeeper 快照无 autopurge，880G | 清盘 |

**这是一本讲"同一个问题出现第二次就该把机制上移"的书，而它的作者在磁盘这件事上
重复了五次。** 这不是打脸，恰恰是全书最诚实、最有说服力的一节 —— 因为它说明：
**知道原则和执行原则之间隔着注意力，而注意力是有限的。**

真正的机制上移应该是「任何分区水位告警」，一次性覆盖全部七次。它到 04-29
那篇的记录里才被提出来（"没有磁盘水位告警，潜伏 5 天"）。

**书里的位置**：@sec-rule-lifecycle（规则怎么长出来）· @sec-observer（观测器）
**AIO 的解药**：演进纪律「同一个问题出现第二次，机制升到 Foundation」

---

## 形状 D · 配置声明了，但从未生效

**核心**：你写了配置，系统读了配置，配置没起作用 —— 而且没有任何东西会告诉你。

| 层 | 实例 | 声明了什么 | 实际发生了什么 |
|---|---|---|---|
| CI | k3s runner 资源配额从未生效 | 配额 | **TOML 子表吞键**，整段被忽略 |
| 运维 | Loki retention 配了仍累积 | 168h 保留 | compactor 跟不上写入速度 |
| 路由 | 停用 stage 导致 Grafana 全断 | traefik 文件路由 | 路由文件未被发现 |
| 调度 | 5 条 workflow 注册后从未运行 | 注册表 | 注册 ≠ 在跑 |

**通用形态**：声明与生效之间缺一层判定。
「注册表是唯一事实源」是对的，但**「注册了」和「在跑」是两件事**。

**书里的位置**：@sec-observer · @sec-toolchain（工具链自己没有被判定覆盖）

---

## 形状 E · 边界处的静默降级

**核心**：请求穿过一层边界之后语义变了，两侧各自都"正常"。

| 层 | 实例 | 边界 | 变了什么 |
|---|---|---|---|
| 网络 | 所有按 IP 的限流塌成一个桶 | Cloudflare edge | `X-Forwarded-For` 右端是代理不是用户 |
| 网络 | ECS SSH 不通 | 云厂商边界 | packet 根本不到主机 |
| 网络 | Analytics 全站 504 | tailscale reset | 阿里云内网 DNS 挂死 |
| 路由 | Internal 登录 404 | 反向代理 | Connect-RPC 被误路由到 Next.js |
| 埋点 | 所有依赖页面浏览的功能永不触发 | 模拟器 | 被判非生产环境，`$screen` 事件不发 |

**限流那个实例是全书最好的素材之一**：访客签发 30/h 是某个功能唯一的
Sybil 闸，它塌成一个桶之后，**功能看起来完全正常**，限流也确实在工作 ——
只是全世界共用一个配额。

**书里的位置**：@sec-where-uncertainty-lives · @sec-toolchain（工具的假象）

---

## 形状 F · 资源无界增长

**核心**：没有上界的东西，最终会用完某种东西。

| 实例 | 无界的是什么 | 撞上的墙 |
|---|---|---|
| macOS Runner fork 耗尽 | zombie + Simulator 残留 | 进程数 |
| 端口耗尽 | 30 天孤儿进程 | TIME_WAIT GC |
| 一个产品吃掉 5 台 mac mini | 自定义 ui_test bundle 名 | CI 并发 |
| Traefik OOM 被杀 | 内存 | 全站 503 |
| ZooKeeper 快照 880G | 快照 | 磁盘 |

**书里的位置**：@sec-gain-and-delay（增益无界 = 失稳）

---

## 形状 G · 本地与远端跑的不是同一件事

**核心**：本机绿是必要条件，不是充分条件。

| 差异源 | 实例 |
|---|---|
| 并发争用 | `--local_test_jobs`，模拟器争用（最常见） |
| 插桩 | CI 用 `bazel coverage`，改代码生成，翻出只在插桩下崩的问题 |
| 环境包装 | locale 包装器 |
| 版本漂移 | CI 模拟器更新，SwiftUI 展平成 UIKit 层级的方式随 OS 变 |
| 工具链 | Xcode 26.1.1 缺 Metal Toolchain |
| 手工操作 | Grafana dashboard 全丢：手动 `docker run` 漏 network + volume 错挂 |

**书里的位置**：@sec-tests（三个真实踩过的坑）· @sec-guardrails（本地与 CI 同一条命令）

---

## 形状 → 章节 覆盖矩阵

| 形状 | 主讲章节 | 呼应章节 |
|---|---|---|
| A 探针测错 | @sec-tests | @sec-sensor-faults · @sec-toolchain |
| B 两个写者 | @sec-architecture | @sec-arbiter |
| C 修实例没修机制 | @sec-rule-lifecycle | @sec-observer |
| D 声明未生效 | @sec-observer | @sec-toolchain |
| E 边界降级 | @sec-where-uncertainty-lives | @sec-toolchain |
| F 资源无界 | @sec-gain-and-delay | — |
| G 本地≠远端 | @sec-tests | @sec-guardrails |

**判定条件**：每个形状至少在两章出现，且至少有一个实例来自非 Agent 领域
（运维 / 网络 / 数据），否则这本书会退化成 "iOS + Bazel 团队专用手册"。

---

## 脱敏清单

进书前必须处理，且**脱敏是重写不是替换**：

| 原始 | 处理 | 为什么不能只替换 |
|---|---|---|
| `home-ops002` · `sg-001` · `aliyun-light-hk-001` | 「一台自建 runner」 | 要连带说明自建带来什么约束，否则读者不知道这个细节重不重要 |
| `AccessProxy` · `Mainline` · `AgentsMesh` | 按角色改写：「反向代理」「发布大脑」 | 内部代号对读者是纯噪声 |
| 内网网段 · Tailscale 拓扑 · 云账号结构 | 抽象成「跨地域的自建网络」 | 这是暴露面 |
| 具体产品名（26 个） | 保留 2–3 个有代表性的，其余泛化 | 商业敏感，且不影响论证 |
| 收入管线 · ASO 策略 · 选品逻辑 | **整体不进书** | 商业敏感，且与主题无关 |
