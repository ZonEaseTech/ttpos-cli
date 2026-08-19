---
name: ttpos-purchase
description: Use this skill when the user (or an agent) needs to look up TTPOS shop purchase (采购) data via the `ttpos` CLI — purchase orders (采购单), receipts (收货单，含按采购单聚合的进度视图), purchase limit schemes (限购方案), extra receipt source warehouses (额外收货来源仓库), or the brand purchase auto-approve switch (品牌采购自动审批开关，只读查询). Applies to questions like "这批采购单的收货进度如何"、"这个采购单还有哪些物品没收货"、"限购方案配置了哪些商品"、"品牌采购自动审批开关开了吗". **本域只读查询，不含下单、提交、审批、驳回、收货、取消、删除等写操作**——上游还有 17 个写端点，一律不接，需用户明确授权后才会规划，不要用本 CLI 尝试执行这些操作。Do not use for statistics/transfer/stock_reconciliation domains (different domains, not接入 by this skill). `--shop` resolution (uuid/别名/商户名前缀、四级上下文兜底) is documented once in `ttpos-shared`, not repeated here.
---

# ttpos-purchase

`ttpos purchase order|receipt|limit-scheme|source-warehouses|auto-approve`
通过本地 gateway 只读查询 TTPOS 商户的采购数据，共 10 个命令。全部要求
先完成 `ttpos auth login`（见 README「`auth login` 三
步」），未登录直接 exit 3，不发起网络请求。

**本域只读查询，不含下单、提交、审批、驳回、收货、取消、删除等写操
作**——上游本域另有 **17 个** `POST`/`DELETE` 写端点，按只读默认政策
一律不接，需用户明确授权后才会规划，见下文「本域只读」。

## 前置条件

- gateway 已启动且可达（`TTPOS_GATEWAY_URL` 环境变量或 `--gateway` flag）。
- 已登录（本地凭证里有 token）。
- 上游本域受 `MinVersionCheck` 中间件门禁（门槛 `2.22.0`），gateway 已
  统一上报 `Client-Version: 2.26.20` 解锁，调用方不需要关心这层——已在
  gateway 单点处理，详见 README。
- 目标商户的标识——uuid、本机别名、商户名全称或前缀都可以，也可以什么都
  不传，让四级上下文兜底，完整说明见
  `skills/ttpos-shared/SKILL.md`。

## 10 个命令

| 命令 | 关键 flag | 用途 |
|---|---|---|
| `purchase order list` | `--status`(多值可重复) `--time-type` `--from`/`--to`/`--tz` `--order-no` `--supplier` `--warehouse-erp-code` `--purchase-type`(**缺省=1，只看外部采购**) `--page`/`--size` | 列出采购单，分页壳 |
| `purchase order get <uuid>` | `--with-receipt-list` | 采购单详情（无表格，仅 JSON） |
| `purchase receipt list` | `--status`(多值可重复) `--time-type` `--from`/`--to`/`--tz` `--order-no` `--receipt-type` `--page`/`--size` | 列出收货单（**按收货单聚合**） |
| `purchase receipt new-list` | `--receipt-status`(单值 presence) `--order-no` `--erp-order-no` `--page`/`--size` | 按采购单聚合的收货进度（**按采购单聚合**，见下「聚合粒度」） |
| `purchase receipt get <uuid>` | — | 收货单详情（无表格，仅 JSON） |
| `purchase receipt pending-items` | `--purchase-order-uuid`(**必填**) `--delivery-note-no` `--supplier-erp-code` | 采购单待收货物品清单 |
| `purchase limit-scheme list` | `--scheme-status`(单值 presence) `--rule-type`(单值 presence) `--name` `--page`/`--size` | 列出限购方案 |
| `purchase limit-scheme get <uuid>` | — | 限购方案详情（无表格，仅 JSON） |
| `purchase source-warehouses` | — | 额外收货来源仓库（无分页，全量返回；无查询参数） |
| `purchase auto-approve` | — | 品牌采购自动审批开关（只读查询，无表格，仅 JSON） |

4 个 `get`（order/receipt/limit-scheme 详情 + auto-approve）**均无
`--format` flag，恒定 JSON 透传**（同 `staff permission-group`/`setting
get` 先例），不暴露死参数。4 个 list（order/receipt list + receipt
new-list + limit-scheme list）+ `receipt pending-items` + `source-
warehouses` 共 6 个"列表形状"命令支持 `--format json|table`，不填按
TTY 自动判断。

## `--status` / `--receipt-status` / `--scheme-status`：语义不同，故意不同名

本域同时存在两种过滤语义，容易混用，三个 flag 故意不同名以避免误用：

| flag | 语义 | 值形态 | 所属命令 |
|---|---|---|---|
| `--status` | **多值**过滤，可重复传入 | `[]int`，转发为重复 query key `status_in=1&status_in=2...` | `order list`、`receipt list` |
| `--receipt-status` | **单值 presence** 过滤 | `*int`，**不传=不过滤，显式传值（含 `0`）会转发**——上游 `ReceiptStatus` 本身是 `*int`，"未传"与"显式传 0"是两种不同语义 | `receipt new-list` |
| `--scheme-status` | **单值 presence** 过滤 | `*int`，同上不传/显式传 0 语义 | `limit-scheme list`（同域另有语义相同的 `--rule-type`，也是单值 presence） |

`order list`/`receipt list` 的 `--status` 是"筛选落在这些状态之一"的
多值过滤；`receipt new-list`/`limit-scheme list` 的单值 flag 是"要不要
按这一个状态值过滤"的存在性判断——两者不可互换，命令行为完全不同。

## 形状四态逐端点（本域一次出现四种）

| 端点 | 命令 | 形状 | count 语义 |
|---|---|---|---|
| `purchase/order/list` | `order list` | 分页壳 `{list, meta:{total}}` | `meta.total` |
| `purchase/order/detail` | `order get` | 单对象无壳，RawMessage 透传 | 无 count |
| `purchase/receipt/list` | `receipt list` | 分页壳 `{list, purchase_order_list, meta:{total}}`（**并列两个数组**，均做大整数字符串化） | `meta.total`（与并列的 `purchase_order_list` 条数无关） |
| `purchase/receipt/new_list` | `receipt new-list` | 分页壳 `{list, meta:{total}}` | `meta.total` |
| `purchase/receipt/detail` | `receipt get` | 单对象无壳，RawMessage 透传 | 无 count |
| `purchase/receipt/pending_items` | `receipt pending-items` | **`{items:[...]}`——键名是 `items`，不是 `list`** | `len(items)`（既有 `stringifyBigInts`/`listLen` 假设 `list` 键，套用会得 count=0，gateway 已用专门的 `stringifyBigIntsItemsKey` 处理） |
| `purchase/limit/scheme/list` | `limit-scheme list` | 分页壳 `{list, meta:{total}}` | `meta.total`（**陷阱**：上游自有 `PageNo`/`PageSize`、无 binding、无默认值，repository `Paginate` 对 0 无兜底——漏传即 `LIMIT 0` 静默空结果；gateway 已显式兜底 `page_no=1`/`page_size=20`，CLI 层不重复兜底） |
| `purchase/limit/scheme/detail` | `limit-scheme get` | 单对象无壳，RawMessage 透传（`Uuid` 无 `binding:"required"`，缺参原样转发） | 无 count |
| `purchase/extra_receipt/source_warehouses` | `source-warehouses` | **`{list:[...]}`——纯数组无壳，连 `meta` 都没有**（复用"list 但无 total"范式，同 `product tax list`） | `len(list)` |
| `purchase/setting/brand_purchase_auto_approve` | `auto-approve` | **`{brand_purchase_auto_approve:<int>}`——单裸字段**，RawMessage 透传不做类型改写 | 无 count |

即本域同时出现**分页壳 / 单对象无壳 / items 键（非 list）/ 纯数
组无壳 / 单裸字段**共四种形状（比此前各域最多三态更多），消费方不能默
认套用"count 一定在 `meta.total`"或"数组一定叫 `list`"的假设，需逐端点
核对上表。

## `receipt list` vs `receipt new-list`：聚合粒度不同，非重复端点

- `receipt list`：**按收货单聚合**，一张收货单一行；`--time-type`
  **只有 `receipt` 一个真实生效的取值**（默认，也是本域唯一合法值）——
  已核实上游实现：2.7.0+ 的 receipt 列表（本 CLI 恒发 `Client-Version`
  头，必定命中该分支）**只按收货时间过滤，完全不消费创建时间**；认创建时
  间的是更早的旧实现，本 CLI 永远走不到。
  显式传 `--time-type create` 会 **exit 2** 并给出解释，不会静默放行一个
  不生效的过滤。
- `receipt new-list`：**按采购单聚合**收货进度，一个采购单对应一行，
  即使它已被拆成多个收货单收货；**只显示总部审核通过的采购单**（服务
  端行为，非 CLI 过滤）；无 `--time-type`/`--from`/`--to`（上游该端点
  请求 DTO 逐字段核对后确认无对应时间字段，不是遗漏）。

两者不是重复端点，取舍看你需要"收货单维度"还是"采购单维度"的视图。

## `--tz` 语义与局限

上游按绝对 Unix 秒比较 `--from`/`--to` 转换出的时间窗，**日界（一天的
起止边界）由 CLI 选定的时区决定**。优先级：**`--tz` flag > `TTPOS_TZ`
环境变量 > CLI 本机时区**。`--tz` 需为合法 IANA 时区名（如
`Asia/Shanghai`、`Asia/Bangkok`、`UTC`），非法值 exit 2。

**局限（如实记录，非已解决问题）**：本仓库当前的 wire 拿不到商户真实
时区——`statistics/company_list` 只有 3 个字段、没有 company detail 只
读端点、`setting` 已接的 6 个 type 与 `auth status` 均未暴露时区字段。
因此**不做商户时区自动解析**，`--tz` 完全靠调用方显式指定；不传时按
CLI 本机时区兜底，**若与商户实际时区不一致，日界处（如"今天"的开始/
结束）的过滤结果会有偏差**。跨时区排障、agent 自动化场景建议**显式传
`--tz`**，不要依赖默认兜底。该局限要等上游暴露商户时区字段（或提供
商户详情只读端点）才能解除。

### `--time-type` 映射（order 4 态、receipt 实际只有 1 态真实生效）

`order list` 与 `receipt list` 各自独立一张映射表，**不能互换**：

| `order list --time-type` | 上游 start/end 字段 | 含义 |
|---|---|---|
| `create`（默认/未识别值兜底） | `create_time_start`/`create_time_end` | 下单创建时间 |
| `order` | `order_time_start`/`order_time_end` | 订购时间 |
| `arrival` | `expect_arrival_time_start`/`expect_arrival_time_end` | 预计到货时间 |
| `receive` | `receive_time_start`/`receive_time_end` | 收货时间 |

| `receipt list --time-type` | 上游 start/end 字段 | 含义 |
|---|---|---|
| `receipt`（默认，也是**唯一合法值**） | `receipt_time_start`/`receipt_time_end` | 收货时间 |
| `create`（后**显式拒绝，exit 2**） | 不生效——上游 2.7.0+ 实现不消费 | ~~创建时间~~ |

`receipt list` 曾经允许传 `create` 且当作默认值，但上游 2.7.0+ 的
union 查询实现（见上「`receipt list` vs `receipt new-list`」段的 C1
说明）完全不消费 `create_time_start`/`end`——过滤参数发了但什么也不
过滤，用户会误以为按创建时间筛过了。修复后默认值改为 `receipt`（唯一
真实生效的取值），显式传 `create` 直接 exit 2 并给出解释，不再静默
放行。

`--time-type` 非法值（不在各自枚举内）exit 2，Hint 里列出合法值。
`receipt new-list`/`limit-scheme list` 无 `--time-type`（上游无对应时
间字段，见上「聚合粒度」段）。

## `--purchase-type` 缺省只看外部采购，无"全部"取值（`order list` 的 `--purchase-type` 不传时，上游恒执行
服务端取值等价于 `purchase_type = (传入值==2 ? 2 : 1)`
（已核实：**无前置判断、没有"全部"这个取值**）。也就是说：

- 不传 `--purchase-type` → 只返回外部采购单（`purchase_type=1`）；
- 内部采购单（品牌采购，`purchase_type=2`）**永远不会**出现在缺省结果
  里，必须显式传 `--purchase-type 2` 才能看到；
- `total=0` 不代表该商户没有采购单，可能只是外部采购确实为空、内部采购
  未查询。

## `brand_purchase_auto_approve` 是 int 0/1（本域唯一非 bool 布尔）

`purchase auto-approve` 响应体 `{"brand_purchase_auto_approve":<0|1>}`
是 **Go int**，不是 JSON boolean——本域摘录到的 10 个 GET 端点里**唯一
一处非 bool 布尔语义字段**，其余布尔字段（如 `HasNested`/
`Configured`/`Headquarter` 一类）均为原生 `true`/`false`，未发现
`string` "0"/"1" 形态。**这一结论只覆盖本域已枚举的字段，不外推到其它
域**（`setting` 域已证明同仓库不同域存在 bool 三态混用）。

非总部账号调用会返回**业务错误**（上游 service 层判断"仅总部可操
作"，走既有 `CodeUpstreamError`/BadGateway 路径），**不是 HTTP 403**，
消费方需按 message 判断而非按 HTTP 状态码判断。

本域另无严格意义的"金额"字段（无 currency amount），只有数量/换算率类
字段（`Num`/`ArrivalNum`/`PurchaseNum`/`ConversionRate` 等），全部是
Go `float64`（非 `decimal.Decimal`、非 `string`）；`shopspring/decimal`
只在写端点内部计算用，不影响本域只读响应的序列化形态。

## Wire 命名注意

- `order/list`：swagger 注释写 query 参数 `page`，**实绑字段是
  `page_no`**（`PurchaseOrderListReq` 内嵌 `dto.PageReq`）——CLI/
  gateway 都照 DTO 不照 swagger 文案。
- `receipt/list`：同一 DTO 文件里存在一个**同名死代码 struct**
  `PurchaseReceiptListReq`（无任何引用），排查契约时勿抄错到这个死结
  构体上。
- `limit/scheme/list`：见上「形状四态」表的 `LIMIT 0` 陷阱——比其余域
  更危险，本仓库其它分页端点上游多少还有默认值兜底，这个端点完全没
  有，漏传即静默空结果不报错。

## 本域只读：17 个写端点未接（需用户明确授权）

上游本域另有 **17 个** `POST`/`DELETE` 写端点，覆盖下单/提交/审批/驳
回/收货/取消/删除，一律不接（只读默认政策）：

| 端点 | 动作 |
|---|---|
| `POST purchase/order/create` | 下单（创建采购单） |
| `POST purchase/order/update` | 更新采购单 |
| `DELETE purchase/order/delete` | 删除采购单 |
| `POST purchase/order/approve` | 审批采购单 |
| `POST purchase/order/review_reject` | 复核驳回（#234 级联取消） |
| `POST purchase/order/submit` | 提交采购单 |
| `POST purchase/receipt/create` | 创建收货单（收货） |
| `POST purchase/receipt/update` | 更新收货单 |
| `POST purchase/order/item/units/update` | 更新采购单物品单位 |
| `DELETE purchase/receipt/cancel` | 取消收货单 |
| `POST purchase/extra_receipt/save` | 保存额外收货草稿 |
| `POST purchase/extra_receipt/submit` | 提交额外收货 |
| `DELETE purchase/receipt/file` | 删除收货单附件 |
| `POST purchase/setting/brand_purchase_auto_approve` | 设置品牌采购自动审批开关（**与已接的同名 GET 只读查询同路径不同 HTTP 方法**） |
| `POST purchase/limit/scheme/create` | 创建限购方案 |
| `POST purchase/limit/scheme/update` | 更新限购方案 |
| `DELETE purchase/limit/scheme/delete` | 删除限购方案 |

**不含**同文件里的 `POST /file/upload_document`——那是通用文件上传端
点（非 purchase 域专属命名，也被其它域复用），不计入这 17 条清单。以
上写端点**在用户明确授权之前不会规划接入**：需要先设计确认机制 +
`--dry-run` + 幂等键防重试重复下单 + 审计留痕 + agent 自动化护栏，是
独立的一份计划，。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 一般错误：上游/gateway 业务错误（含 `SHOP_NOT_IN_SCOPE` 403；`auto-approve` 非总部账号的业务错误也走这条路径，不是 HTTP 403） |
| `2` | 用法错误：位置参数数量不符（`order get`/`receipt get`/`limit-scheme get` 缺 `<uuid>`）、未知 flag、flag 值解析失败（cobra 层，统一为 exit 2 + JSON 信封）；`receipt pending-items` **缺 `--purchase-order-uuid`**；`--time-type` 非法值（Hint 列出允许值）或 `receipt list --time-type create`（本域只有 receipt 真实生效，显式传 create 专门拒绝，见上文 C1）；`--tz` 非法 IANA 时区名；`--shop` 解析失败；`--format` 取值非法 |
| `3` | 未认证：本地无 token、上游会话过期需重新 `ttpos auth login`；**未登录 + `receipt pending-items` 缺 `--purchase-order-uuid` 同时命中时，exit 3（AUTH）优先于 exit 2（USAGE）**——必填校验放在 `AfterAuth` 钩子，同 `bom product get`/`staff search` 先例。同样只对 `AfterAuth` 里的域校验成立；`order/receipt/limit-scheme get` 缺位置参数走 cobra 层，在 `LoadToken` 之前拦下，"未登录 + 缺位置参数"是 exit 2，不是 3 |

## 输出契约

同仓库其余命令一致：非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`
成功时写到 stdout；**失败**（`ok:false`）时信封改写到 **stderr**，stdout
为空，不能靠 stdout 是否为空判断成败，要看退出码。提示/诊断信息一律走
stderr。`resolved_shop` 字段与 `--shop` 解析结果的关系见 `ttpos-shared`。

## 已知局限

- **零数据，非空场景未验**：测试租户 <商户uuid> 采购数据为空。
  10 个命令均只验证过"能通+形状+退出码"这个层面（如 `order list` 带
  `Client-Version` 头 `code=0 total=0` 已实测）；分页壳的 `meta.total`
  是否与真实非空列表条数一致、`receipt/list` 并列的
  `purchase_order_list` 是否符合预期、`limit-scheme list` 兜底 1/20
  后是否返回真实数据等，均未在有数据的商户上复核，接入有数据的商户
  时需人工复核一次。
- **`--tz` 无法自动解析商户真实时区**：见上文「`--tz` 语义与局限」，
  当前 wire 无法拿到商户时区字段，不传 `--tz` 时按 CLI 本机时区兜底，
  与商户实际时区不一致会在日界处产生偏差，建议显式传。
- **17 个写端点未接**：见上文「本域只读」，需用户明确授权后才规划。
- **`limit-scheme get` 的 `uuid` 无必填校验**：上游 `Uuid` 无
  `binding:"required"`（同域其余 detail 都有），CLI/gateway 均不做额
  外校验，缺参原样转发交由上游返回业务错误。
- **`order get`/`receipt get`/`limit-scheme get`/`auto-approve` 均透传
  不建模**：字段含义需自行对照上游契约。
- **`order list`/`order get` 虽是 GET，但会触发上游懒回填写库（final
  review I1，用户已裁定：保留既有实现值 + 如实文档化，不改行为）**：
  `order list` 与 `order get` 在 `Client-Version >= 2.26.0`
  （本 CLI 恒发 `2.26.20`，必定命中此门槛）
  且命中条件（内部采购单 + `erp_sale_order_no` 为空 + 尚未标记已回查）
  时，会外呼 ERPNext 反查销售订单号，并对**总部库与子店库两侧**
  执行 `UPDATE`。**这不是本 CLI 自行写库**：该行为是上游对所有
  `>= 2.26.0` 客户端的既定设计（#589 历史内部采购单懒回填 SO），本身
  幂等（回填成功后不会重复回填，ERPNext 确无关联 SO 也会标记
  `erp_sale_order_no_checked=1` 避免重复查询），失败不阻断列表。命中
  条件较窄（仅内部采购单且此前从未回填成功过），但**本域"只读查询"
  的表述不是绝对承诺**——遇到写库敏感场景（如审计要求"GET 一定零副
  作用"）需额外注意这两个命令。
- **`source-warehouses` 空列表条件（修正，2026-08-17
  已核实上游实现）**：条件是 `headquarter_uuid==0`——**无总
  部归属的独立商户（散户）**返回空列表，**子店恰恰能拿到数据**（子店
  本地仓库表已通过 `syncToSubShop` 同步 HQ 仓库，
  `headquarter_uuid!=0`）。此前"非总部子店会静默返回空列表"的说法把
  主体和条件都写反了，排障时如果按旧说法去查会指向反方向，需注意。
- **`receipt pending-items` 顶层字符串化不递归嵌套数组**：`items[]`
  每项顶层的 `unit_uuid`/`base_unit_uuid` 已字符串化（大整数保精
  度），但同一 item 内 `units[]`（元素字段 `unit_uuid`）/`unit_list[]`（元素字段 **`uuid`**，非 `unit_uuid`）的
  `unit_uuid` **仍是 JSON number**（`stringifyBigInts` 只处理顶层，不
  递归嵌套数组，同域其它端点也是这个纪律）——JS/TS 消费方处理
  `pending-items` 响应时，顶层 `unit_uuid` 可以当字符串比较，
  `units[].unit_uuid`/`unit_list[].uuid` 仍需按 number 处理，
  `>2^53` 的值在 JS 里有精度损失风险。
- `--shop` 的完整解析规则见 `skills/ttpos-shared/SKILL.md`，
  不在本文档重复。
