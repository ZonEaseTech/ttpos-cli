---
name: ttpos-recharge
description: Use this skill when the user (or an agent) needs to look up TTPOS shop recharge/top-up orders (会员充值订单) via the `ttpos` CLI — list a shop's recharge orders within a date range/order-no filter, fetch a single recharge order's full detail, or check its refundable-amount info, all by `uuid`. Applies to questions like "这个门店最近充值了多少笔"、"这笔充值订单能退多少钱"、"充值订单详情". Do not use for regular sales orders (`ttpos order`) or member sale orders (`ttpos member-order`) — those are separate skills. This skill is read-only: `refund-info` only queries refundable amount, it does NOT execute a refund (no refund command exists in this CLI yet — 见「已知局限」). `--shop` resolution is documented once in `ttpos-shared`, not repeated here.
---

# ttpos-recharge

`ttpos recharge list` / `ttpos recharge get` / `ttpos recharge refund-info`
通过本地 gateway 查询 TTPOS 商户的会员充值订单。三者都要求先完成
`ttpos auth login`（见 README「`auth login` 三步」），未登录
直接 exit 3，不发起网络请求。

## 前置条件

- gateway 已启动且可达（`TTPOS_GATEWAY_URL` 环境变量或 `--gateway` flag，
  解析优先级同 auth：`--gateway` > `TTPOS_GATEWAY_URL` >
  `~/.ttpos/config.json` 的 `gateway_url`）。
- 已登录（本地凭证里有 token）。
- 目标商户的标识——uuid、本机别名、商户名全称或前缀都可以，也可以什么都
  不传，让四级上下文兜底。**这条解析规则是全部域命令共用的**，完整说明见
  `skills/ttpos-shared/SKILL.md`，本文档只讲 `recharge` 命令特有
  的 flag。

## `ttpos recharge list`

```bash
ttpos recharge list --shop <company_uuid|别名|商户名前缀>
ttpos recharge list                                        # --shop 省略，走四级上下文兜底
ttpos recharge list --shop <标识> --from 2026-08-01 --to 2026-08-15
ttpos recharge list --shop <标识> --order-no <订单号> --page 1 --size 50
ttpos recharge list --shop <标识> --format json   # 强制 JSON，即使在 TTY 下
```

| flag | 必填 | 说明 |
|---|---|---|
| `--shop` | 否 | 商户标识（uuid/别名/商户名前缀），解析规则见 `ttpos-shared`；缺省依次尝试 `TTPOS_SHOP` 环境变量、`ttpos shop use` 设置的默认商户，四级全空 exit 2 |
| `--from` / `--to` | 否 | `YYYY-MM-DD`，非法格式 exit 2。**两者都不填时，gateway 兜底为「当前时间往前 7 天」**（防止无范围查询把上游/gateway 拖 OOM，同 `order list` 语义）；只填一端时 gateway 补齐另一端（只给 `--from` 则 `--to` 补当前时刻，只给 `--to` 则 `--from` 补 `--to` 往前 7 天） |
| `--order-no` | 否 | 按订单号过滤 |
| `--page` / `--size` | 否 | 不填由 gateway 兜底为 `page_no=1&page_size=20` |
| `--format` | 否 | `json` \| `table`，不填按 TTY 自动判断 |
| `--gateway` | 否 | 覆盖 gateway 地址 |

**时间过滤按创建时间**：gateway 无论是否自定义了 `--from`/`--to`，都会向
上游显式传 `enable_create_time=true`（上游 `date_type` 无窗口时默认全部
历史，不显式开时间过滤开关会全表扫描——防 OOM）。上游同时支持
`enable_payment_time`（按支付时间过滤），**但本 CLI 目前未暴露这个开
关**，只能按创建时间过滤，见「已知局限」。

**权限范围**：`--shop` 解析出的 uuid 若不在当前登录账号可访问的商户列表
内，gateway 返回 `403` + `SHOP_NOT_IN_SCOPE`（exit 1），提示先跑
`ttpos shop list` 核对范围。

**TTY 表格列**：`uuid | 订单号 | 状态 | 充值金额 | 赠送 | 支付时间 | 支付
方式`。`uuid` 已做大整数保精度处理（字符串）；`状态` 是原始整数状态码，
未做文字映射；`充值金额`/`赠送` 对应上游 `recharge_amount`/`gift_amount`；
`支付时间` 取 `payment_time`（unix 秒转本地时间显示）；`支付方式` 是上游
`payment_methods` 字符串数组，表格里用 `,` 拼接展示（如
`WeChatPay,Alipay`）。非 TTY / `--format json` 时，`data.list[]` 每项保留
实测的全部字段（含 `company_uuid`、`cashier`、`extra` 等 object），信封
另带 `count`（对应上游 `meta.total`）。

## `ttpos recharge get`

```bash
ttpos recharge get 3719796340295681 --shop <商户uuid>
ttpos recharge get 3719796340295681 --shop <商户uuid> --format json
```

- 位置参数 `<uuid>` 必填，来自 `recharge list` 输出（JSON 模式下的 `uuid`
  字段）。
- `--shop` 同 `list`：uuid/别名/商户名前缀都可以、也可以省略走四级上下文
  兜底，范围外同样 403 + `SHOP_NOT_IN_SCOPE`。
- **详情原样透传**：`data` 是上游充值订单详情的原始 JSON，gateway 和 CLI
  都不做字段裁剪、重命名或数值中转（不经 `map[string]any`/`float64`），
  `--format table` 下也是直接打印这段原始 JSON，不额外渲染表格。实测顶层
  字段含 `uuid`/`order_no`/`member`/`status`/`cashier`/`recharge_amount`/
  `amount`/`charge_due`/`payment_time`/`create_time`/`gift_amount`/
  `gift_point`/`payment_methods`/`operation_log`/`extra`。

## `ttpos recharge refund-info`

```bash
ttpos recharge refund-info 3719796340295681 --shop <商户uuid>
```

- 用法与 `get` 完全一致（同一个位置参数、同一组 flag），只是打到上游的
  `recharge_order/refund` 端点。**这是只读查询，不执行退款**：探测已坐实
  上游 handler 是 `GetRechargeOrderRefundInfo`（GET 语义），返回该笔充值
  订单的可退款信息原文（实测含 `refundable_amount`/`recharge_amount`/
  `gift_amount`/`gift_point`/`recharge_member_info`/`payment_records`），
  同样原样透传、不建模。执行退款不在本 CLI 能力范围内（见「已知局限」）。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 一般错误：上游/gateway 业务错误（含 `SHOP_NOT_IN_SCOPE` 403） |
| `2` | 用法错误：位置参数数量不符（`get`/`refund-info` 缺 `<uuid>`）、未知 flag、flag 值解析失败（cobra 层，统一为 exit 2 + JSON 信封）；`--shop` 解析失败（四级上下文全空、标识无效、0 命中、多命中歧义——详见 `ttpos-shared`）、`--from`/`--to` 非 `YYYY-MM-DD`、`--format` 取值非法 |
| `3` | 未认证：本地无 token、上游会话过期需重新 `ttpos auth login`，或 `--shop` 解析需要拉商户列表但未登录 |

## 输出契约

同仓库其余命令一致：TTY 下人类可读（表格/原始 JSON），非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`
成功时写到 stdout；**失败**（`ok:false`）时信封改写到 **stderr**，stdout
为空，不能靠 stdout 是否为空判断成败，要看退出码。提示/诊断信息一律走
stderr。`--format json|table` 可显式覆盖自动判断。`resolved_shop` 字段与
`--shop` 解析结果的关系见 `ttpos-shared`。

## 已知局限

- **`refund-info` 只查询不退款**：命令名容易让人误以为会执行退款操作，
  实际只是只读查询可退款金额等信息。真正的退款写操作（资金变动，最高
  风险）尚未接入本 CLI，需要 dry-run + 二次确认 + 审计设计后单独立项。
- `recharge list` 表格里的状态列是原始整数状态码，未映射为可读文字。
- `recharge get`/`refund-info` 输出未建模的原始 JSON，字段需自行对照上游
  文档解读。
- **`--from`/`--to` 都不填时默认查最近 7 天**，不是全量历史；需要更早数
  据必须显式传 `--from`。
- **只支持按创建时间过滤窗口**：上游 `recharge_order/list` 同时支持
  `enable_create_time`（创建时间）与 `enable_payment_time`（支付时间）两
  个独立开关，本 CLI/gateway 目前只使用前者，没有暴露"按支付时间过滤"的
  选项。**查不到预期单据先放宽 `--from`**——`--from`/`--to` 过滤的是创建
  时间，不是支付时间（表格里显示的「支付时间」列取的是 `payment_time`，
  跟过滤窗口不是同一个时间字段，两者可能差好几天）。
- 只覆盖充值订单本身，不含会员账户余额、积分等其他会员域数据。
