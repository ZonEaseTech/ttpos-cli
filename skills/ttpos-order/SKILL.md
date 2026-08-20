---
name: ttpos-order
description: Use this skill when the user (or an agent) needs to look up TTPOS shop orders via the `ttpos` CLI — list a shop's orders within a date range/status/order-no filter, fetch a single order's full detail by `sale_bill_uuid`, query an order's refund/return context (`return-info`), or check whether an order/desk can be closed (`can-close`). Applies to questions like "查一下这个门店最近的订单"、"这笔订单的详情"、"这笔订单能退多少钱"、"这桌能不能关台". Do not use for member accounts, recharge/top-up orders, or report/aggregation queries — those are out of scope for this slice. `--shop` resolution (uuid/别名/商户名前缀、四级上下文兜底) is documented once in `ttpos-shared`, not repeated here — load that skill alongside this one if the question involves how `--shop` is identified rather than what order filters do.
---

# ttpos-order

`ttpos order list` / `ttpos order get` / `ttpos order return-info` /
`ttpos order can-close` 通过本地 gateway 查询 TTPOS 商户的销售订单。全部
要求先完成 `ttpos auth login`（见 README「`auth login` 三
步」），未登录直接 exit 3，不发起网络请求。

## 前置条件

- 默认走进程内，无需 `ttpos gateway serve`；只有连远端时才需要 `--gateway` /
  `TTPOS_GATEWAY_URL` / config.json 的 `gateway_url`（优先级同 auth：
  `--gateway` > `TTPOS_GATEWAY_URL` > `gateway_url`，全空走进程内）。
- 已登录（本地凭证里有 token）。
- 目标商户的标识——uuid、本机别名、商户名全称或前缀都可以，也可以什么都
  不传，让四级上下文兜底。**这条解析规则是 `order`/`shop use` 共用的**，
  完整说明见 `skills/ttpos-shared/SKILL.md`，本文档只讲
  `order` 命令特有的 flag。

## `ttpos order list`

```bash
ttpos order list --shop <company_uuid|别名|商户名前缀>
ttpos order list                                        # --shop 省略，走四级上下文兜底
ttpos order list --shop <标识> --from 2026-01-01 --to 2026-08-15
ttpos order list --shop <标识> --status <上游状态码> --order-no <订单号>
ttpos order list --shop <标识> --page 2 --size 50
ttpos order list --shop <标识> --format json   # 强制 JSON，即使在 TTY 下
```

| flag | 必填 | 说明 |
|---|---|---|
| `--shop` | 否 | 商户标识（uuid/别名/商户名前缀），解析规则见 `ttpos-shared`；缺省依次尝试 `TTPOS_SHOP` 环境变量、`ttpos shop use` 设置的默认商户，四级全空 exit 2 |
| `--from` / `--to` | 否 | `YYYY-MM-DD`，非法格式 exit 2。两者都不填时，gateway 兜底为「当前时间往前 7 天」（防止无范围查询把上游/gateway 拖 OOM）；只填一个也按字面值传给上游，不做另一侧的自动补全 |
| `--status` | 否 | 直接透传给上游过滤，**不做状态码到文字的映射**，取值含义需查上游/业务文档 |
| `--order-no` | 否 | 按订单号过滤 |
| `--page` / `--size` | 否 | 不填由 gateway 兜底为 `page_no=1&page_size=20` |
| `--format` | 否 | `json` \| `table`，不填按 TTY 自动判断 |
| `--gateway` | 否 | 覆盖 gateway 地址 |

**权限范围**：`--shop` 解析出的 uuid 若不在当前登录账号可访问的商户列表
内，gateway 返回 `403` + `SHOP_NOT_IN_SCOPE`（exit 1），提示先跑
`ttpos shop list` 核对范围。

**TTY 表格列**：订单号 | 流水 | 时间 | 金额 | 实付 | 状态 | 支付方式。
`状态` 列是原始整数状态码，未映射为文字。非 TTY / `--format json`
时，`data.list[]` 里每个订单对象含 `sale_bill_uuid`（**字符串**，已做大整数
保精度处理，不要按 number 解析）等字段，信封另带 `count`（对应上游
`meta.total`）。

## `ttpos order get`

```bash
ttpos order get 3745748940230657 --shop <商户uuid>
ttpos order get 3745748940230657 --shop <商户uuid> --format json
```

- 位置参数 `<sale_bill_uuid>` 必填，来自 `order list` 输出（JSON 模式下的
  `sale_bill_uuid` 字段，或表格模式下需要额外拿 JSON 才能取到——表格不显示
  该字段）。
- `--shop` 同 `order list`：uuid/别名/商户名前缀都可以、也可以省略走四级
  上下文兜底（见 `ttpos-shared`），范围外同样 403 + `SHOP_NOT_IN_SCOPE`。
- **详情原样透传**：`data` 是上游订单详情的原始 JSON，gateway 和 CLI 都不做
  字段裁剪、重命名或数值中转（不经 `map[string]any`/`float64`），`--format
  table` 下也是直接打印这段原始 JSON，不额外渲染表格。这样做是为了不重蹈
  `is_super` 曾经因先经 float64 中转丢精度的教训——但代价是拿到的是未建模
  的裸 JSON，字段含义需要结合上游订单详情接口文档自行解读。

## `ttpos order return-info`

```bash
ttpos order return-info 3745748940230657 --sale-order <sale_order_uuid> --shop <商户uuid>
ttpos order return-info 3745748940230657 --sale-order <sale_order_uuid> --shop <商户uuid> --format json
```

只读查询订单可退款上下文（可退金额、支付记录、可退商品等），**不执行退
款**——同上游路径的 `POST order/return` 是退款写操作，本命令只接 GET，命
令名特意用 `return-info` 避免与"执行退款"混淆。

- 位置参数 `<sale_bill_uuid>` 必填。
- **`--sale-order <sale_order_uuid>` 必填**——上游按子单（`sale_order_uuid`）
  取退款上下文（上游请求体是 `{sale_bill_uuid, sale_order_uuid}` 两个字
  段，服务端按后者取子单；缺失或为 0 时恒返回"找不到销售订单"）。缺省该
  flag 客户端直接判定用法错误（exit 2，不发起网络请求）。**参数来源**：从
  `ttpos order get <sale_bill_uuid>` 输出的 `data.detail` 子单列表里取
  `sale_order_uuid`。
- `--shop` 同 `order list`/`order get`。
- **原样透传**：`data` 是上游订单退款信息的原始 JSON，不做字段裁剪、重命
  名或数值中转，`--format table` 下也是直接打印这段原始 JSON。
- **该单没有可退款上下文时，上游以业务错误（非 0 的 `code`）表达，不是
  空数据**——CLI 把这类响应当错误处理（exit 1，`message` 透出上游原文），
  不会返回一个"空的" `return-info` 对象。

## `ttpos order can-close`

```bash
ttpos order can-close 3745748940230657 --shop <商户uuid>
ttpos order can-close --desk <desk_uuid> --shop <商户uuid>
```

查询某笔订单/某个桌台当前是否可以关台（关闭订单）。

- `<sale_bill_uuid>`（位置参数，可选）与 `--desk <desk_uuid>` **二选
  一**：都不传是用法错误（exit 2，不发起网络请求）；都传时两者原样一起
  转发给上游，CLI 不做取舍——**真实 handler 按 `--desk` 优先**
  （服务端先判 `desk_uuid` 再判 `sale_bill_uuid`；上游字段注释里
  "`sale_bill_uuid` 权重最大"的说法是旧的，与实际行为不符，不要依赖），**建议不要同时传两者**，避免歧义。
- `--shop` 同上。
- **原样透传**，同 `return-info`。**"能不能关台"这个判断本身以上游返回的
  错误码/成功码表达**：订单当前不可关台时，上游返回业务错误（非 0
  `code`，如"该订单部分已支付，无法……"），CLI 视为错误（exit 1，
  `message` 透出上游原文）；只有可以关台时上游才会以成功响应（`code=0`）
  返回可关闭上下文——**该成功路径下 `data` 的具体字段结构尚未在真实环境
  验证过**，只能确认"存在即可关闭"这条语义，不要假设或转述任何具体字段
  名。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 一般错误：上游/gateway 业务错误（含 `SHOP_NOT_IN_SCOPE` 403；`return-info`/`can-close` 的"不可退款"/"不可关台"均属此类） |
| `2` | 用法错误：位置参数数量不符（`order get`/`return-info` 缺 `<sale_bill_uuid>`）、`can-close` 超过 1 个位置参数、未知 flag、flag 值解析失败（cobra 层，统一为 exit 2 + JSON 信封）；`--shop` 解析失败（四级上下文全空、标识无效、0 命中、多命中歧义——详见 `ttpos-shared`）、`--from`/`--to` 非 `YYYY-MM-DD`、`--format` 取值非法、`can-close` 的 `sale_bill_uuid`/`--desk` 都未传、`return-info` 缺 `--sale-order` |
| `3` | 未认证：本地无 token、上游会话过期需重新 `ttpos auth login`，或 `--shop` 解析需要拉商户列表但未登录 |

`can-close` 的二选一校验、`return-info` 的 `--sale-order` 必填校验都放在
`AfterAuth` 钩子（`LoadToken` 成功之后），因此**未登录 + 这两项域参数非法
同时命中时是 exit 3（AUTH 优先）**；而 `get`/`return-info` 缺位置参数
`<sale_bill_uuid>` 走 cobra 层，在 `LoadToken` 之前就拦下，**未登录 + 缺
位置参数是 exit 2**，不是 3。两级校验顺序说明见 README「退出码」。

## 输出契约

同仓库其余命令一致：TTY 下人类可读（表格/原始 JSON），非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`
成功时写到 stdout；**失败**（`ok:false`）时信封改写到 **stderr**，stdout
为空，不能靠 stdout 是否为空判断成败，要看退出码。提示/诊断信息一律走
stderr。`--format json|table` 可显式覆盖自动判断。`resolved_shop` 字段与
`--shop` 解析结果的关系见 `ttpos-shared`。

## 已知局限

- `--status` 过滤值和 `order list` 表格里的状态列都是原始状态码，未映射为
  可读文字。
- `order get` 输出未建模的原始 JSON，字段需自行对照上游文档解读。
- 会员账户订单、充值/储值订单未接入，只覆盖销售订单（`sale_bill`）。
- `--from`/`--to` 都不填时默认查最近 7 天，不是全量历史；需要更早数据必须
  显式传 `--from`。
- `order return-info`/`order can-close` 输出未建模的原始 JSON，字段需自行
  对照上游文档解读；`code=0` 时的成功响应结构未经真实数据核实。
- **`order can-close` 在测试租户上目前只验证过业务错误路径**（不可关
  台），成功路径（`code=0`）未经真实数据核实。
- **修正**：`order return-info` 此前记录的"已验证业务错误路径（无退款上
  下文）"实为漏传必填参 `sale_order_uuid` 导致的恒定失败（见本文件
  `return-info` 一节），并非真实的"无退款上下文"业务场景——已补齐
  `--sale-order` 必填参数（已修复），但端到端的真实成功/错误路径仍待
  下次冒烟验证，之前的冒烟记录不能作为已验证证据。
- **ERP 商户 + 收银端不在线时，`return-info` 会被上游直接拒绝**：服务端
  在进入实际查询前先判「已开通 ERP 且当前员工收银端离线」，命中就返回业务
  错误"当前不可进行退款"——这是该只读接口的系
  统性限制，不代表订单本身没有退款上下文；ERP 商户排查退款问题前先确认
  收银端在线状态。
- `order/export` 未接入：2026-08-16 实测该端点返回
  `{list,meta:{page_no,page_size,total}}`，与已接的 `order list` 同构，非
  文件下载，导出需求已由 `order list --format json` 覆盖。
