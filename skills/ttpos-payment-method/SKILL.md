---
name: ttpos-payment-method
description: Use this skill when the user (or an agent) needs to look up TTPOS shop payment methods (支付方式) via the `ttpos` CLI — list the payment methods a shop has configured, view one payment method's detail (手续费、各终端是否显示、Logo/二维码), or list the system default payment methods and whether each can still be added. Applies to questions like "这个门店开了哪些支付方式"、"某个支付方式手续费多少"、"收银机上显示哪些支付方式"、"还能添加哪些默认支付方式". Read-only — it cannot create, edit, sort, enable or disable payment methods, and it never exposes LianLianPay credentials. Do not use for payment-related shop settings (use ttpos-setting) or order payments (use ttpos-order). `--shop` resolution is documented once in `ttpos-shared`.
---

# ttpos-payment-method

`ttpos payment-method list` / `get` / `default` 通过本地 gateway 查询 TTPOS
商户的支付方式。都要求先完成 `ttpos auth login`，未登录直接 exit 3，不发
起网络请求。

**只读**：不能新增、编辑、排序、启停支付方式，也不能上传 Logo/二维码。
**不提供 LianLianPay 支付配置查询**——该配置含商户密钥，本 CLI 刻意不接。

## 前置条件

- 默认走进程内，无需 `ttpos gateway serve`；连远端时用 `--gateway` /
  `TTPOS_GATEWAY_URL` / config.json 的 `gateway_url`（优先级依次递减，全空
  走进程内）。
- 已登录（本地凭证里有 token）。
- 目标商户标识——uuid、本机别名、商户名全称或前缀，或不传走四级上下文兜底，
  规则见 `ttpos-shared`。

## `ttpos payment-method list`

```bash
ttpos payment-method list --shop <标识>
ttpos payment-method list --shop <标识> --page 2 --size 50
ttpos payment-method list --shop <标识> --format json
```

| flag | 必填 | 说明 |
|---|---|---|
| `--shop` | 否 | 商户标识，缺省走四级上下文兜底，全空 exit 2 |
| `--page` | 否 | 页码，缺省 `1` |
| `--size` | 否 | 每页数量，缺省 `20`，上游上限 `1100` |
| `--format` | 否 | `json` \| `table`，不填按 TTY 自动判断 |
| `--gateway` | 否 | 覆盖 gateway 地址 |

- **有分页**：信封 `count` 是上游 `meta.total`（总数），不是本页条数；
  `count` 大于本页 `list` 长度说明还有下一页。
- 每项字段：`uuid`（大整数，**已字符串化**）、`name`（普通字符串，不是多
  语言对象）、`source`（`0` 系统 / `1` 手动 / `2` LianLianPay / `3` Kbank）、
  `status`（`0` 禁用 / `1` 启用 / `2` 草稿）、`sort`、`logo_file`（Logo URL）。
- **上游已隐式过滤**，列表不是全部记录：外卖平台（Grab、LINE MAN）与免单类
  系统支付方式恒不出现；商户未开通会员时不含余额支付；LianLianPay 未配置时不
  含 LianLianPay 支付方式。`total` 是过滤后的总数。
- **TTY 表格列**：UUID | 名称 | 来源 | 状态 | 排序（来源/状态显示原始数值）。

## `ttpos payment-method get <uuid>`

```bash
ttpos payment-method get <uuid> --shop <标识>
```

- `uuid` 取自 `list` 的 JSON 输出；缺省 exit 2。**仅 JSON**（TTY 下也不出表
  格），无 `--format`。
- `data` 带一层壳：`{"payment_method":{...}}`，不是裸对象。
- **大整数不字符串化**：`uuid`、`logo_file_uuid`、`qrcode_file_uuid` 在
  JSON 里是 number（原文保精度），超过 2^53，**不要按 double 解析**（JS 的
  `JSON.parse` 会丢精度），按字符串或 int64 读。与 `list` 里字符串化的
  `uuid` 类型不同。
- 主要字段：`code`、`name`（显示名）、`payment_name`、`source`、`status`、
  `sort`、`logo_file`/`qrcode_file`（URL，可为空串）、`fee_percent`（手续费，
  **已是 0-100 的百分数**，如 `2.5` 表示 2.5%）、`is_show_cashier` /
  `is_show_assistant` / `is_show_kiosk` / `is_show_member_recharge` /
  `is_show_tablet` / `is_show_mobile`（各终端结账是否显示，int `0`/`1`）、
  `is_takeaway`（是否计入外卖统计，int `0`/`1`）。
- 注意 `list` 的 `name` 对应详情里的 `name`，而详情的 `payment_name` 是另一
  个字段，两者可能不同。
- uuid 不存在时上游返回业务错误，exit 1。

## `ttpos payment-method default`

```bash
ttpos payment-method default --shop <标识>
```

- 系统内置的默认支付方式清单（用于"快速添加"），**无分页**，`count` 是条数。
- 每项：`code`（int）、`name`、`payment_name`、`url`（完整图片 URL）、
  `img`（相对路径）、`sort`、`source`、`can_add`（**原生 bool**，不是 `0`/`1`）。
- `can_add`：Kbank 类支付方式在商户已添加过时为 `false`；其余默认支付方式
  恒为 `true`（不代表商户没添加过）。
- **TTY 表格列**：CODE | 名称 | 来源 | 可添加。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 上游/gateway 业务错误（含 uuid 不存在、`SHOP_NOT_IN_SCOPE` 403） |
| `2` | 用法错误：缺/多位置参数、未知 flag、flag 值非法、`--shop` 解析失败、`--format` 非法 |
| `3` | 未认证：本地无 token 或上游会话过期 |

## 输出契约

TTY 下人类可读表格（`get` 除外），非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`。
成功写 stdout；失败信封写 stderr、stdout 为空，按退出码判断成败。

## 已知局限

- 尚未在真实商户上完成端到端冒烟，字段形状按服务端定义整理；非空场景、翻页
  边界未实测。
- 只读；写操作（新增、编辑、排序、启停）不提供。
- 不提供 LianLianPay 支付配置查询。
