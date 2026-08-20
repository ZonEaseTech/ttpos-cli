---
name: ttpos-member-order
description: Use this skill when the user (or an agent) needs to look up TTPOS shop member orders (会员订单/会员消费单) via the `ttpos` CLI — list a shop's member orders within a date range/status/order-no filter, fetch a single member order's full detail, or check its return info, all by `member_sale_order_uuid`. Applies to questions like "查一下今天的会员订单"、"这笔会员订单的退货信息"、"这个会员账号今天下了几单". Do not use for regular sales orders (`ttpos order`) or recharge/top-up orders (`ttpos recharge`) — those are separate skills. `--shop` resolution (uuid/别名/商户名前缀、四级上下文兜底) is documented once in `ttpos-shared`, not repeated here.
---

# ttpos-member-order

`ttpos member-order list` / `ttpos member-order get` / `ttpos member-order
return-info` 通过本地 gateway 查询 TTPOS 商户的会员订单。三者都要求先完成
`ttpos auth login`（见 README「`auth login` 三步」），未登录
直接 exit 3，不发起网络请求。

## 前置条件

- 默认走进程内，无需 `ttpos gateway serve`；只有连远端时才需要 `--gateway` /
  `TTPOS_GATEWAY_URL` / config.json 的 `gateway_url`（优先级同 auth：
  `--gateway` > `TTPOS_GATEWAY_URL` > `gateway_url`，全空走进程内）。
- 已登录（本地凭证里有 token）。
- 目标商户的标识——uuid、本机别名、商户名全称或前缀都可以，也可以什么都
  不传，让四级上下文兜底。**这条解析规则是全部域命令共用的**，完整说明见
  `skills/ttpos-shared/SKILL.md`，本文档只讲 `member-order` 命令
  特有的 flag。

## `ttpos member-order list`

```bash
ttpos member-order list --shop <company_uuid|别名|商户名前缀>
ttpos member-order list                                        # --shop 省略，走四级上下文兜底
ttpos member-order list --shop <标识> --from 2026-08-01 --to 2026-08-15
ttpos member-order list --shop <标识> --status completed --order-no <订单号>
ttpos member-order list --shop <标识> --time-type 2 --page 1 --size 50
ttpos member-order list --shop <标识> --format json   # 强制 JSON，即使在 TTY 下
```

| flag | 必填 | 说明 |
|---|---|---|
| `--shop` | 否 | 商户标识（uuid/别名/商户名前缀），解析规则见 `ttpos-shared`；缺省依次尝试 `TTPOS_SHOP` 环境变量、`ttpos shop use` 设置的默认商户，四级全空 exit 2 |
| `--from` / `--to` | 否 | `YYYY-MM-DD`，非法格式 exit 2。**两者都不填时，上游默认只查「今天」**（见下「⚠️ 默认窗口」），不是 7 天或全量；只填一端时 gateway 会补齐另一端（只给 `--from` 则 `--to` 补今天此刻，只给 `--to` 则 `--from` 补 `--to` 往前 7 天） |
| `--status` | 否 | 直接透传给上游过滤，取值为字符串：`unpaid`/`unaccept`/`accept`/`undelivery`/`delivery`/`completed`/`cancel`，空字符串表示不过滤（全部状态） |
| `--order-no` | 否 | 按订单号过滤 |
| `--time-type` | 否 | `1` 按下单时间、`2` 按支付时间；只在自定义了 `--from`/`--to` 窗口时才有意义，不填时不传该参数（CLI/gateway/upstream 全链路对 `<=0` 都跳过 `time_type` query） |
| `--page` / `--size` | 否 | 不填由 gateway 兜底为 `page_no=1&page_size=20` |
| `--format` | 否 | `json` \| `table`，不填按 TTY 自动判断 |
| `--gateway` | 否 | 覆盖 gateway 地址 |

### ⚠️ 默认窗口：只查「今天」，不是 7 天

这是本域和 `order`/`recharge` 最大的语义差异，**必须留意**：`--from`/
`--to` 都不填时，gateway 不会像 `order list`/`recharge list` 那样兜底成
「最近 7 天」，而是**完全不传时间参数**（不传 `date_range`）。上游
`member_order/list` 接口的 `date_range` 字段没有 default 值，Go 零值 `0`
恰好对应上游枚举里的「今天」——这是源码坐实的一个隐藏行为（不是 CLI/
gateway 主动设计的默认值，而是继承自上游的零值陷阱）。查更早数据必须显式
传 `--from`（或 `--from`+`--to`），gateway 收到任一端非空后会补齐窗口并显式
传 `date_range=-1`（自定义窗口时的惯例写法，语义清晰）。

**优先级更正**（复核：此前文档把这个关系写反了）：上游
`GetTimeFilterParams` 的真实优先级是"自定义窗口参数覆盖 `date_range`"，不
是"`date_range` 覆盖自定义窗口"——`query_start_date`/`query_end_date`
字符串参数（gateway 实际使用的形式）优先级最高，无条件覆盖 `date_range`
和时间戳两者；传 `date_range=-1` 只是让语义更清晰的显式选择，不是自定义
窗口生效的必要条件。窗口按商户时区解析：gateway 传的是朴素
`query_start_date`/`query_end_date` 字符串（不是 Unix 时间戳），由上游按
商户时区转换，避免了早期实现里"按 UTC 折算"导致的日界偏差。

**权限范围**：`--shop` 解析出的 uuid 若不在当前登录账号可访问的商户列表
内，gateway 返回 `403` + `SHOP_NOT_IN_SCOPE`（exit 1），提示先跑
`ttpos shop list` 核对范围。

**TTY 表格列**：`member_sale_order_uuid | 订单号 | 状态 | 金额 | 时间`。
`member_sale_order_uuid` 已做大整数保精度处理（字符串），`状态` 显示的是
`status_group` 分组字符串（如 `completed`，不是原始 `status` 数字状态
码），未做文字映射；`金额` 取 `pay_amount`（实付金额）；`时间` 取的是
`pay_time`（支付时间，unix 秒转本地时间显示）。非 TTY / `--format json`
时，`data.list[]` 每项字段以上游 `MemberOrderManage` 结构为准
（见下「已知局限」），信封另带 `count`（对应
上游 `meta.total`）。

## `ttpos member-order get`

```bash
ttpos member-order get 9007199254740993 --shop <商户uuid>
ttpos member-order get 9007199254740993 --shop <商户uuid> --format json
```

- 位置参数 `<member_sale_order_uuid>` 必填，来自 `member-order list` 输出
  （JSON 模式下的 `member_sale_order_uuid` 字段）。
- `--shop` 同 `list`：uuid/别名/商户名前缀都可以、也可以省略走四级上下文
  兜底，范围外同样 403 + `SHOP_NOT_IN_SCOPE`。
- **详情原样透传**：`data` 是上游订单详情的原始 JSON，gateway 和 CLI 都不
  做字段裁剪、重命名或数值中转（不经 `map[string]any`/`float64`），
  `--format table` 下也是直接打印这段原始 JSON，不额外渲染表格。

## `ttpos member-order return-info`

```bash
ttpos member-order return-info 9007199254740993 --shop <商户uuid>
```

- 用法与 `get` 完全一致（同一个位置参数、同一组 flag），只是打到上游的
  `member_order/return_info` 端点，返回该笔会员订单的退货信息原文，同样
  原样透传、不建模。**只读查询**，不执行任何退货操作。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 一般错误：上游/gateway 业务错误（含 `SHOP_NOT_IN_SCOPE` 403） |
| `2` | 用法错误：位置参数数量不符（`get`/`return-info` 缺 `<uuid>`）、未知 flag、flag 值解析失败（cobra 层，统一为 exit 2 + JSON 信封）；`--shop` 解析失败（四级上下文全空、标识无效、0 命中、多命中歧义——详见 `ttpos-shared`）、`--from`/`--to` 非 `YYYY-MM-DD`、`--format` 取值非法 |
| `3` | 未认证：本地无 token、上游会话过期需重新 `ttpos auth login`，或 `--shop` 解析需要拉商户列表但未登录 |

## 输出契约

同仓库其余命令一致：TTY 下人类可读（表格/原始 JSON），非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`
成功时写到 stdout；**失败**（`ok:false`）时信封改写到 **stderr**，stdout
为空，不能靠 stdout 是否为空判断成败，要看退出码。提示/诊断信息一律走
stderr。`--format json|table` 可显式覆盖自动判断。`resolved_shop` 字段与
`--shop` 解析结果的关系见 `ttpos-shared`。

## 已知局限

- **`member-order list` 默认只查今天**，不是全量历史也不是最近 7 天——和
  `order`/`recharge` 两域的默认窗口语义不同，务必看清上面「⚠️ 默认窗口」
  一节再解读"没查到数据"的结果。
- **item 字段未经真实数据验证**：探测时使用的测试商户（`<商户uuid>`）
  没有会员订单数据，`list`/`get`/`return-info` 的字段形状（含 detail/
  return-info 的完整结构）均以上游 DTO 定义
  为准，**未拿真实响应核对过**。首个有会员订单数据的商户接入时需要人
  工复核一次字段是否与 DTO 一致，如有出入以实测为准并回来更新本文档。
- `--status` 过滤值和 `member-order list` 表格里的状态列都是原始字符串状
  态码，未映射为可读文字。
- `member-order get`/`return-info` 输出未建模的原始 JSON，字段需自行对照
  上游文档或 DTO 源码解读。
- 只覆盖会员订单本身，不含会员账户资料、会员等级、积分等其他会员域数据。
