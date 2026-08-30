# 代码地图

> **一手材料是代码。** 事故记录是作者事后的叙述 —— 已经被解释过、被挑选过；
> markdown 文档是主张。**代码是这套系统真正做了什么的唯一证据。**
>
> 这份地图给每一章指定它要读的源码。写每一章之前先读代码，
> 再回来对照 `shapes.md` 里的形状 —— 不是反过来。

---

## 已经挖到的、值得单独成节的代码

### 1. 五行代码承载整本书的论点

`DevOps/Tooling/Guardrails/runner/src/orchestrator/render.rs:18`

```rust
pub fn exit_code(&self) -> i32 {
    match self {
        Self::Completed { lanes, .. } if lanes.has_infrastructure_failure() => 2,
        Self::Completed { lanes, .. } if lanes.has_policy_violation() => 1,
        Self::Completed { .. } => 0,
        Self::BaselineGrowth(_) => 1,
        Self::InfrastructureFailure(_) => 2,
    }
}
```

**匹配臂的顺序就是论点本身**：基建故障排在策略违规**前面**。
一次运行如果同时有内容违规和基建故障，报的是 2 不是 1。

理由在控制论里是一句话：**如果测量不可信，那么同一次运行里得出的策略结论
也不可信。** 传感器故障压过对象故障。

→ 主讲 @sec-three-failures，呼应 @sec-sensor-faults

### 2. 类型系统不让你丢掉这个区分

`runner/src/core/outcome.rs`

```rust
pub enum LaneOutcome {
    Passed,
    PolicyViolation(String),
    InfrastructureFailure(String),
}
```

三态枚举，不是 bool。**让非法状态无法表示。**

同一个文件里还有两条用断言守住的不变量：

```rust
assert_ne!(lane, LaneId::Architecture,
           "architecture outcomes must retain their rich result");
assert!(self.lanes.iter().all(|c| c.lane != result.lane),
        "guardrail lane outcomes must be unique");
```

第一条：架构 lane 的判定**不许被降级**成普通结论（丰富的结果不能在传递中丢失）。
第二条：**一个 lane 只能有一个判定** —— 单一 writer 用在了判定本身上。

→ 主讲 @sec-three-failures

### 3. 禁止 fallback 不是正则，是带绑定跟踪的语义分析

`architecture/engine/src/service_fallback_contract/analyzer/projection.rs`（186 行）

天真的实现是「grep 一下 `??`」。真实的实现有五层过滤，**每一层都对应一次误报**：

| 过滤 | 它放行的正确写法 |
|---|---|
| `optional_accessors` 集合 | 只对**已知是可选**的 accessor 生效，来源是服务图 |
| `shadowed` 集合 | 局部变量遮蔽了同名 accessor 的情况 |
| `statement_boundary_regex` | `??` 其实在下一条语句里 |
| `is_explicit_unavailable_rhs` | `?? .unavailable` 是显式声明不可用，合法 |
| `binding_regex` + 动态构造的 fallback 正则 | `let x = accessor()` 之后再 `x ?? y` —— **跟着值穿过一次局部绑定** |

**这是 lint 和 checker 的分界线。** 最后一条尤其说明问题：
它不是在匹配文本，是在追踪一个值的来源。

→ 主讲 @sec-guardrails，是「forbid 拿真实数据调出来」最硬的证据

### 4. 哨兵不是一条规则的装饰，是内建在规则模型里的

`architecture/engine/src/{ui_test_host_contract,service_lookup_ownership,commented_code}.rs`

```rust
let sentinel_min = rule.minimum_facts().get();
// ...
"Bazel service graph production target sentinel failed: {count} < {minimum}"
```

注意 `rule.minimum_facts()` —— **哨兵是规则类型的一个字段，不是某几条规则的特例**。
每一条规则都必须声明「我至少应该看到多少个事实」，看不到就判自己坏了。

→ 主讲 @sec-sensor-faults（传感器量程校验）

### 5. 配置的 raw → validated → conversion 三段

`architecture/engine/src/config/{raw,validated,conversion}/`

解析和校验被分成两个类型层：`raw` 是从 TOML 直接反序列化出来的，
`validated` 是通过校验之后的。**一个函数拿到 `validated` 类型，
就不需要再检查它合不合法** —— 合法性由类型携带。

这条和形状 D（配置声明了但没生效）直接对立：
那次「TOML 子表吞键导致配额从未生效」的事故，在这种类型分层下不会发生，
因为 raw→validated 的转换会拒绝一个没有配额的配置。

→ 主讲 @sec-guardrails，呼应 @sec-shape-d

---

## 按章分配的必读代码

| 章 | 必读源码 | 要提取什么 |
|---|---|---|
| @sec-codebase | `Modules/*/` 的实际目录形态、各产品的 `BUILD.bazel` | 「被挣得」原则的三个真实判例：双平台产品 / 多进程产品 / 单一产品 |
| @sec-architecture | `DevOps/BuildSystem/CrossPlatform/API/Compiler/src/{lexer,ir,lib}.rs`<br>`Foundation/iOS/Runtime/Libraries/Kernel/Sources/MicroKernel.swift` | 编译管线的分段；微内核的三态机与「装配在锁外执行」 |
| @sec-carriers | `agents/validate_skills.py`、skill 的投射机制、`AGENTS.md` 符号链接 | 载体的**发现机制**是代码，不是约定 |
| @sec-toolchain | `Foundation/iOS/DeveloperExperience/Libraries/{SynapseKit,Automation}`<br>`Backends/Mainline` 的 `workflow.Registry` | 20 个工具的能力边界；profile 的幂等契约；注册表如何驱动变更检测 |
| @sec-tests | `Foundation/iOS/Runtime/Libraries/Kernel/Tests/*.swift`<br>`DevOps/BuildSystem/iOS/Product/ios_ui_test.bzl` | 断言密度的真实分布；wrapper 如何强制 bundle 命名 |
| @sec-guardrails | `runner/src/{core,orchestrator,lanes}/`<br>`architecture/engine/src/*_contract*.rs` | 上面第 2、3、4、5 条 |
| @sec-arbiter | `arbiters/src/`、`forbid_pattern/go_projection.rs` | 路径匹配与 forbid 的实际实现；词边界怎么处理 |
| @sec-gain-and-delay | `DevOps/CI/Engine/impact-analyzer/`（12,861 行） | **稀疏测量的真实实现**：反向依赖查询 → 分片 → 批次规划 |
| @sec-sensor-faults | 同 @sec-guardrails，加 `aio_api_generated_sync_test` | 四种传感器故障管理的代码形态 |
| @sec-observer | `Backends/Mainline` 的 `processes` 表与 workflow 注册 | 「注册了」与「在跑」在代码里是两个不同的东西 |

---

## 读代码的纪律

1. **先读类型，再读逻辑。** 这个仓库的判断力大量体现在类型划分上
   （三态枚举、raw/validated 分层、`minimum_facts` 作为规则字段）。
2. **每个过滤条件背后都有一次误报。** 看到一个看起来多余的 `if`，
   先假设它是被真实数据逼出来的，去 git log 里找那次改动。
3. **测试目录和实现目录同级并存**（`x/` 与 `x_tests/`）——
   读实现之前先读它的测试，测试会告诉你这段代码真正的契约是什么。
4. **不许把源码大段贴进书。** 进书的代码片段控制在 15 行以内，
   且必须是能独立读懂的那一段。长的用文字描述结构。
5. **代码里的英文注释要翻译，不要照抄。** 但翻译时保留它的信息密度 ——
   那些注释大多写明了「为什么」，而那正是最值钱的部分。
