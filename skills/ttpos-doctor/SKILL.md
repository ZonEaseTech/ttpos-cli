---
name: ttpos-doctor
description: Use this skill when the user (or an agent) needs to self-diagnose why a `ttpos` CLI setup isn't working — "为什么连不上"、"登录态是不是过期了"、"环境有没有配置对"、"agent 怎么自动判断 CLI 能不能用" — or wants to interpret `ttpos doctor` / `ttpos doctor --format json` output and turn a `fail` result into a concrete fix. Covers the six local checks (cli-version/gateway/credentials/data-dir/auth/shop-context), the optional `--network` upstream check, the skip-chain semantics between them, and exit codes. Do not use this for command-specific business errors (order/product/staff 等域的失败）——那些是各自 skill 的范畴，doctor 只覆盖"CLI 本身能不能正常工作"这层环境自查。
---

# ttpos-doctor

`ttpos doctor` 是环境自查命令：六项本地检查（cli-version/gateway/
credentials/data-dir/auth/shop-context）恒定执行，`--network` 追加第七项
upstream 深检。用途是排障入口——人第一次遇到 CLI 报错、或 agent 想在跑业务
命令前先判断"这套环境能不能用"，都应该先跑这个命令而不是逐个猜。

`data-dir` 项（新增， 复核 I-1/I-2 后校正）检查
gateway 默认数据目录（`$TTPOS_CONFIG_DIR/gateway`，否则 `~/.ttpos/gateway`）
是否可写、以及目录下已存在的 `gateway.db`/`audit.jsonl` 是否可打开（曾用
sudo 跑过 gateway、文件归 root 的场景），把只读容器/权限问题提前到自查阶段
暴露，不用等 `gateway serve` 启动时才因 `MkdirAll`/`store.Open` 失败而
exit 1。它是纯本地文件系统探测，**不参与 gateway 不可达触发的 skip
连锁**——即便 `gateway` 项是 `fail` 导致 `auth`/`upstream` 都 `skip`，
`data-dir` 仍照常给出 `ok`/`warn` 结论（顺序上排在 `credentials` 之后、
`auth` 之前）。**这一项从不产生 `fail`**：它只探测默认路径，doctor 本身
没有 `--data-dir` flag，无法判断调用方最终会不会显式传参绕开默认路径，或
根本不在本机跑 `gateway serve`（如连远端 gateway），因此默认路径不可用统一
判 `warn` 而不是 `fail`，不会让这类用户的可用环境被 doctor 判定成"环境损
坏"（exit 1）。

## Agent 用法：`--format json` 自诊断

```bash
ttpos doctor --format json
```

非 TTY（管道、agent 调用）下即使不加 `--format json`，输出布局也和 TTY
一致（只是不带 ANSI 颜色），但**结构化消费一律用 `--format json`**，不要
解析文本输出——文本的 `[✓]/[!]/[✗]/[-]` 前缀是给人看的，agent 应该读
`status` 字段。

顶层信封：

```json
{"ok": false, "checks": [{"id": "...", "status": "ok|warn|fail|skip", "label": "...", "detail": "...", "fix": "..."}], "summary": {"ok": 3, "warn": 1, "fail": 1, "skip": 1}}
```

- `ok`：顶层布尔，`true` 当且仅当所有 `checks` 里没有 `fail`（`warn`/
  `skip` 不影响它）——与退出码语义一致，agent 判断"能不能继续跑业务命
  令"时读这一个字段就够，不用自己遍历 `checks` 数组求交。
- `checks[].fix`：只在这一项确实有可操作建议时才出现（JSON 里
  `omitempty`），`ok` 状态和部分 `warn`/`fail`（如 `cli-version` 的 warn、
  `upstream` 的 fail）没有固定 fix 文案，此时字段整体缺失，不是空字符串。
- `checks[].detail`：同一份文字既喂文本渲染也喂 JSON，`fix` 为空时该项
  唯一的排障线索就在 `detail` 里（典型例子是 `upstream` 失败——上游/
  gateway 返回的原始 message 被塞进 `detail`，没有另外提炼成 `fix`）。

## fail/warn → 建议动作映射表

按 `id` + `status` 索引，`fix` 列是 doctorcmd.go 里真实写死的文案（逐字
对齐实现，不是转述）；没有固定 `fix` 字段的行说明"看 detail 自行判断"。

| id | status | 触发条件 | fix（若有） |
|---|---|---|---|
| `cli-version` | warn | `shared.Version` 仍是未注入的 `dev`（开发构建） | （无，说明性告警，不阻断） |
| `cli-version` | ok/warn | 恒定行为（非独立触发条件） | `detail` 现附带 `(上游上报 Client-Version=2.26.20)`——这是 gateway 调用上游时统一上报的固定版本头（`internal/shared.UpstreamClientVersion`），用于放行 purchase/statistics/transfer/stock_reconciliation 四个受版本门禁的域，与 `shared.Version`（CLI 自身构建版本）是两个不同概念，不参与 ok/warn 判定，仅供排障核对当前实际上报值 |
| `gateway` | fail | `--gateway`/`TTPOS_GATEWAY_URL`/config.json 均未配置 gateway 地址 | 设置 --gateway，或 TTPOS_GATEWAY_URL 环境变量，或在 ~/.ttpos/config.json 配置 gateway_url |
| `gateway` | fail | 已配置地址但连不上/响应解析失败 | 检查 gateway 进程，或设置 TTPOS_GATEWAY_URL；运行 ttpos gateway serve 启动本地 gateway |
| `gateway` | warn | 可达，但 `/healthz` 返回的 version 与 CLI 的 `shared.Version` 不一致 | （无，提示升级其中一侧使版本对齐，非阻断） |
| `credentials` | warn | 凭证走文件回退（非 keychain）且文件权限不是 `0600` | `chmod 600 <凭证文件路径>` |
| `credentials` | fail | `LoadToken` 本身报错（非"未找到"） | （无固定文案，看 detail 里的具体错误） |
| `data-dir` | ok | 默认数据目录已存在且实测可写（真实创建+删除临时文件，不看权限位），且 `gateway.db`/`audit.jsonl`（若已存在）都能正常打开 | （无） |
| `data-dir` | ok | 默认数据目录尚不存在，但最近的已存在祖先目录可写（`MkdirAll` 会从那里逐级创建） | （无，`detail` 注明"将在首次启动时创建"） |
| `data-dir` | warn | `HOME` 取不到且未设 `TTPOS_CONFIG_DIR`，无法确定默认路径（不算环境损坏——用户本就可以每次显式传 `--data-dir`） | 请显式指定 --data-dir |
| `data-dir` | warn | 目录（或其可创建的最近祖先目录）不可写 / 目录路径已被占用但不是目录 / `gateway.db`/`audit.jsonl` 已存在但打不开（如曾用 sudo 跑过 gateway，文件归 root） | 用 --data-dir 指向可写目录，或检查文件属主/权限（本项只探测默认路径，不影响显式传 --data-dir 或连远端 gateway 的用户，可忽略） |
| `auth` | skip | 前序 `gateway` 检查已是 `fail` | 不是可操作建议——先解决 gateway 那一项，auth 自然会重新执行 |
| `auth` | fail | 本地无 token / 请求 `/v1/me` 失败 / token 已过期或被拒 | **运行 ttpos auth login** |
| `shop-context` | warn | 三级（`TTPOS_SHOP` 环境变量/项目配置/全局配置）都未配置默认商户（可选项） | `ttpos shop use <名称|uuid>` |
| `shop-context` | fail | 全局或项目 `config.json` 文件本身解析失败（损坏） | 检查/修复 `<配置文件路径>`（detail 里带具体路径） |
| `upstream`（仅 `--network`） | skip | 前序 `gateway` 是 `fail`，或 `auth` 不是 `ok` | 先解决排在它前面的 `gateway`/`auth` 那一项 |
| `upstream`（仅 `--network`） | fail | 经 gateway 调用 `GET /v1/shops` 失败，或 gateway 转发的上游返回错误 | （无固定文案，`detail` 直接透出上游/gateway 的原始 message，按内容判断） |

`credentials` 无 token 时是 `ok`（"未登录（登录态见 auth 检查）"），不是
`warn`/`fail`——它只报"有没有能读到的凭证"，登录态本身的判定完全交给
`auth` 一项，避免同一件事在两处各报一半、agent 要拼两条结果才能确认。

## skip 连锁规则

`skip` 是第四态：既不是"没问题"（ok）也不是"有问题"（warn/fail），而是
"因为前序检查已经失败，继续跑这一项只会得到误导性结论，所以跳过"。两条链：

```
gateway == fail
  │
  ├─→ auth       = skip("跳过(gateway 不可达)")
  └─→ upstream   = skip("跳过(gateway 不可达)")   （仅 --network 才存在这一项）

auth != ok（含 fail 和被上面链路 skip 的情况）
  └─→ upstream   = skip("跳过(未登录)")           （仅 --network）
```

`gateway` 只是 `warn`（版本不一致，但仍可达）时不触发连锁——`auth`/
`upstream` 照常发请求，`skip` 的阈值只看 `gateway.Status == fail`，不看
`warn`。反过来，`upstream` 要求 `auth.Status == ok` 才发请求：`auth` 只
要不是 `ok`（无论是 `fail` 还是被 `gateway` 连锁 `skip` 掉），`upstream`
都会 `skip`，不会自己再判一次"有没有 token"。

**`data-dir` 不参与上面任何一条链**：它是纯本地文件系统探测（不摸
gateway/网络），即便 `gateway` 是 `fail` 导致 `auth`/`upstream` 都 `skip`，
`data-dir` 仍会照常给出 `ok`/`warn` 结论，从不出现 `skip` 状态，也从不
产生 `fail`（见上方 `data-dir` 行的说明）。

## `--gateway` flag 与网络超时

```bash
ttpos doctor --gateway http://127.0.0.1:8090
```

`doctor` 有自己的 `--gateway` flag，优先级同其它命令：`--gateway` >
`TTPOS_GATEWAY_URL` 环境变量 > `~/.ttpos/config.json` 的 `gateway_url`。
解析出的这一份地址贯穿本次运行的全部网络检查——`gateway` 项探测的
`/healthz`、`auth` 项调用的 `/v1/me`、`--network` 才会出现的 `upstream`
项调用的 `/v1/shops`，三处共用同一个已解析地址，不是只影响 `gateway`
这一项。

网络超时按检查项分别设置，不是全局统一一个值：`gateway` 探测
`/healthz` 用 **2s** 超时；`auth`/`upstream` 各用 **5s**（doctor 内部收
紧的短超时 client，不是 `ttpos auth`/其它业务命令默认的 10s——doctor 一
次运行最多同时经历 gateway+auth+upstream 三次网络往返，沿用 10s 会让
`--network` 最坏情况下单次 `doctor` 等到 20 秒以上，对一个"自查"命令来
说太久）。因此加 `--network` 时最坏总耗时约 **12s**（2s + 5s + 5s，只有
三项全部各自超时才会叠到这个数，正常可达情况下远快于此）。

## `--network` 语义

```bash
ttpos doctor                # 默认：只跑六项本地检查，不发任何真实上游请求
ttpos doctor --network      # 追加第七项 upstream：经 gateway GET /v1/shops
```

- 不加 `--network` 时 `checks` 数组里压根不会出现 `upstream` 这一项（不
  是"跳过"，是"根本没跑"）——本地六项检查全部只碰凭证文件、数据目录、
  本地配置、gateway 的 `/healthz`（2s 超时），**不需要能连到 TTPOS 上游**
  就能给出结论。
- 加了 `--network` 且 `gateway`/`auth` 都健康时，才会真的经 gateway 转发
  一次 `GET /v1/shops`，`ok` 时 `detail` 是"可访问 N 家商户"这类计数，用
  于确认"不仅本地凭证有效，上游也认这个 token、能拿到数据"。

## 退出码

`ttpos doctor` 自己的退出码只有三种（**不是**其它业务命令常见的
`0/1/2/3` 四态——doctor 没有独立的 `AUTH_REQUIRED`(3) 语义，"未登录"体
现为 `auth` 项的 `fail`，仍然归到退出码 `1`）：

| 退出码 | 触发条件 |
|---|---|
| `0` | 所有 `checks` 都没有 `fail`（允许存在 `warn`/`skip`） |
| `1` | 至少一项 `fail`（`ok` 字段同步为 `false`） |
| `2` | 用法错误：`--format` 传了 `text`/`json` 以外的取值，或未知 flag/flag 值解析失败（cobra 层，全域统一）——`doctor` 无位置参数，不涉及缺参场景 |

agent 编排时可以直接把 `ttpos doctor --format json` 当前置探针：退出码
非 0 或顶层 `ok` 为 `false` 时，先按上面的映射表处理对应 `fail` 项，再
决定要不要继续跑后续业务命令。

## 已知局限

- **不检测 main 侧的模块版本门禁（`MinVersionCheck`）**：gateway 统一
  上报固定 `Client-Version` 头解锁 purchase/statistics/transfer/
  stock_reconciliation 四域（见 `cli-version` 检查项的 `detail`），但该
  门槛值随商户 saas 库配置可变，`doctor` 目前不主动探测"当前上报值是否
  仍高于四域各自的实际门槛"——这需要额外对每个域发一次探测请求，成本
  与"本地环境自查"这个定位不符。若未来要加，
  。
