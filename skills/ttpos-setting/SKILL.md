---
name: ttpos-setting
description: Use this skill when the user (or an agent) needs to read a TTPOS shop's configuration snapshot via the `ttpos` CLI — business rules, cashier secondary-screen display, payment switches, kiosk (self-order machine) config, kitchen display settings, or print copy settings. Applies to questions like "这个门店的营业设置"、"收银副屏轮播配了什么"、"支付方式开了哪些"、"自助点餐机密码是多少"、"厨显等待颜色区间"、"打印联数怎么配的". Do not use for writing/changing settings (this CLI is read-only for setting) or for门店基础信息/base——those are out of scope. `--shop` resolution (uuid/别名/商户名前缀、四级上下文兜底) is documented once in `ttpos-shared`, not repeated here.
---

# ttpos-setting

`ttpos setting get <type>` 通过本地 gateway 只读查询 TTPOS 商户的配置快
照。全部要求先完成 `ttpos auth login`（见 README「`auth
login` 三步」），未登录直接 exit 3，不发起网络请求。

## 前置条件

- gateway 已启动且可达（`TTPOS_GATEWAY_URL` 环境变量或 `--gateway`
  flag）。
- 已登录（本地凭证里有 token）。
- 目标商户的标识——uuid、本机别名、商户名全称或前缀都可以，也可以什么都
  不传，让四级上下文兜底，完整说明见
  `skills/ttpos-shared/SKILL.md`。

## `ttpos setting get <type>`

```bash
ttpos setting get business --shop <商户uuid>
ttpos setting get kiosk --shop t5609 | jq .data.call_waiter_enabled
ttpos setting get print --shop t5609
```

`<type>` 位置参数必填，仅支持 6 个白名单值：`business` `cashier`
`payment` `kiosk` `kitchen` `print`。非白名单取值（含容易误传的
`store`——上游没有对应的 GET 端点，见「已知局限」）在**登录态检查之前**
就被 CLI 拒绝，exit 2，不发起网络请求。

| flag | 必填 | 说明 |
|---|---|---|
| `--shop` | 否 | 商户标识，解析规则见 `ttpos-shared`；缺省依次尝试 `TTPOS_SHOP` 环境变量、`ttpos shop use` 设置的默认商户 |
| `--gateway` | 否 | 覆盖 gateway 地址 |

**没有 `--format` flag**：配置快照是单对象、无表格意义，同 `staff
permission-group` 先例，**恒定输出 JSON**（即使在 TTY 下），建议配合
`jq` 消费。

**权限范围**：`--shop` 解析出的 uuid 若不在当前登录账号可访问的商户列表
内，gateway 返回 `403` + `SHOP_NOT_IN_SCOPE`（exit 1）。

**原样透传**：`data` 是上游对应端点的原始 JSON，gateway 和 CLI 都不做字
段裁剪、重命名或数值中转（`business` 含 4 个 `[]uint64` 数组字段——大整
数数组，靠整段透传保精度，不建模）。

## 6 个 type（实测 keys 数与形态要点）

| type | 上游 path | 实测顶层 keys 数 | 形态要点 |
|---|---|---|---|
| `business` | `setting/business` | 53 | 布尔字段绝大多数是字符串 `"0"/"1"`，**唯一例外** `invoice_decimal_setting_editable` 是真 `bool`（已逐字段核实，非推断）；另含 4 个 `[]uint64` 大整数数组（`batch_product_uuids`/`discount_authorized_staff_ids`/`refund_authorized_staff_ids`/`change_salesperson_authorized_staff_ids`） |
| `cashier` | `setting/cashier` | 5 | handler 裁剪后**仅副屏子集**（`carousel`/`no_order_carousel_interval`/`order_display_mode`/`order_carousel`/`order_carousel_interval`），不是完整收银机配置 |
| `payment` | `setting/payment` | 5 | 混用：`is_cash`/`is_balance`/`is_other` 是字符串 `"0"/"1"`，但 `payment_strategy`/`skip_payment_enabled` 是 **int** |
| `kiosk` | `setting/kiosk` | 6 | `call_waiter_enabled` 是 **int**；含 **`advanced_password`** 敏感字段，见下方警告 |
| `kitchen` | `setting/kitchen` | 11 | 布尔字段清一色字符串 `"0"/"1"`（`is_open`/`is_come_dish`/`is_call_service`/`is_wait_color`/`is_smart_kitchen`） |
| `print` | `setting/print_setting/get` | 2 | `enable_custom_copies` 是字符串 `"0"/"1"`，`checkout_slip_copies` 是可空 `*int`（`nil` 表示未设置）——同一端点两个字段形态不同 |

## ⚠️ kiosk 敏感字段警告

**`ttpos setting get kiosk` 的 `data.advanced_password` 是自助点餐机高级
密码的明文原值，不是脱敏/哈希后的占位符。** 这是上游接口的既有行为——任
何拿到有效商户 token 的管理端客户端都会收到同样的明文，不是本 CLI 引入
的。

CLI 侧选择**如实透传、不修改数据**：数据已经从上游下发，CLI 单独遮蔽只
是装饰性的、不解决问题，反而会用"CLI 输出看起来更安全"的错觉掩盖上游的
真实行为。

**因此**：`kiosk` 快照的输出**不要**粘贴到公开场合、聊天记录、issue、日
志或任何会被非授权人看到的地方；agent 消费该字段时同样要当作敏感凭据处
理（不回显在对话历史、不写入非受控文件）。

## 布尔字段三态（跨域现状，不是本命令独有）

同一个"开关"语义在不同域用不同的 JSON 类型承载，**没有仓库统一约定**，
消费方必须逐字段确认类型，不能假设：

| 域 | 主流形态 | 例外 | 参考 |
|---|---|---|---|
| `setting`（本命令） | 字符串 `"0"/"1"`（business 绝大多数字符串，kitchen 全字符串，print 的 `enable_custom_copies` 同样是字符串。cashier 裁剪后子集**无布尔字段**——`carousel`/`order_carousel` 是数组、`order_display_mode` 是字符串枚举，不是「全字符串 0/1」） | business 的 `invoice_decimal_setting_editable` 是 **bool**；`payment` 的 `payment_strategy`/`skip_payment_enabled`、`kiosk` 的 `call_waiter_enabled` 是 **int** | 本文件「6 个 type」表 |
| `product`（细节簇） | **真 Go `bool`**（`is_editable`，JSON 里是 `true`/`false`） | 无 | `skills/ttpos-product/SKILL.md`「商品细节簇」 |
| `staff`/其余大多数域 | **int** `0`/`1`（如 `is_super`/`is_disable`），**不是 truthy**，判断必须用 `== 1` | — | `skills/ttpos-staff/SKILL.md` |

**结论**：`setting` 域绝大多数布尔用字符串 `"0"/"1"`（`payment`/`kiosk`
部分字段例外用 int），仅 `invoice_decimal_setting_editable` 一个真
`bool` 例外（`business`）；判断任何"开关"字段前，先看它落在上表哪一格，
不要跨域套用同一套反序列化逻辑。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 一般错误：上游/gateway 业务错误（含 `SHOP_NOT_IN_SCOPE` 403） |
| `2` | 用法错误：位置参数数量不符（`get` 缺 `<type>`）、未知 flag、flag 值解析失败（cobra 层，统一为 exit 2 + JSON 信封）；**`<type>` 非白名单取值**（`business`/`cashier`/`payment`/`kiosk`/`kitchen`/`print` 之外，错误信息列出全部合法值；该校验在 `LoadToken` 之前，未登录也会先报这个 exit 2，不是 exit 3）、`--shop` 解析失败（详见 `ttpos-shared`） |
| `3` | 未认证：本地无 token、上游会话过期需重新 `ttpos auth login` |

## 输出契约

同仓库其余命令一致：非 TTY 下固定信封
`{"ok":bool,"data":...,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`
成功时写到 stdout；**失败**（`ok:false`）时信封改写到 **stderr**，stdout
为空，不能靠 stdout 是否为空判断成败，要看退出码。本命令**没有 TTY 表格
分支**，TTY 下同样输出这段 JSON。提示/诊断信息一律走 stderr。
`resolved_shop` 字段与 `--shop` 解析结果的关系见 `ttpos-shared`。

## 已知局限

- **只读**：6 个端点全部是 `GET` 快照，本 CLI 不提供任何 setting 写操作
  （`POST /setting/business`、`POST /setting/store` 等均未接入）。
- **`store` type 不存在**：上游只有保存门店设置的写端点，没有对应的读端
  点（实测 `GET setting/store` 返回 404），因此 `ttpos setting get store`
  不存在。
- **`kiosk.advanced_password` 明文透传**：见上方「⚠️ kiosk 敏感字段警
  告」，本 CLI 不做遮蔽。
- **`setting/cashier`/`setting/print_setting/get` 是裁剪后的子集**：上游
  内部有更完整的 `CashierResp`/`Printer` 结构，但这两个端点的 handler 只
  回填其中一部分字段（副屏 5 个、自定义打印联数 2 个），本 CLI 只能拿到
  已下发的这部分，拿不到未下发的其余字段。
- **`business` 含大整数数组**：`batch_product_uuids` 等 4 个
  `[]uint64` 字段可能含超出 JS 安全整数范围（`2^53`）的元素，靠整段
  `json.RawMessage` 透传保精度，JS/浏览器等消费方解析这些数组元素前需自
  行处理精度问题。
- **已完成真实环境端到端冒烟**：6 个 type 均已通过单元测试（fixture
  覆盖字符串/int/可空指针三种布尔形态），并在真实商户数据上冒烟通过——6
  type keys 对账全中（53/5/5/6/11/2）、`kiosk advanced_password` 确认在
  wire、非法 type exit 2、越权 403 exit 1。
- `setting` 域其余 33 个端点（`sync_task`/`data_manage`/`qrcode`/
  `reason`/`template_style` 等）未接入，CLI 目前不会查也不会显示这些
  字段。
