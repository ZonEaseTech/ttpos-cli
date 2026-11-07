---
name: ttpos-payment-method
description: Looks up TTPOS payment methods (支付方式) through the ttpos CLI, listing those a merchant has configured, showing one method's fee, per-terminal visibility and logo or QR code, and listing system defaults with whether each can still be added. Use when asked 开了哪些支付方式, 手续费多少, 收银机上显示哪些支付方式, 还能添加哪些默认支付方式. Not for payment switches in merchant settings (ttpos-setting) or an order's payments (ttpos-order).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-payment-method

先读 `ttpos-shared`。本版不提供 LianLianPay 支付配置查询，被问到直接说没有。

```bash
ttpos payment-method list --page 2 --size 100
ttpos payment-method get <uuid>
ttpos payment-method default
```

查询上限：`list` 每页最多 100 条。

## `list`

- `count` 是总数，大于本页条数就要翻页。
- 列表已被过滤，不是全部记录：外卖平台（Grab、LINE MAN）和免单类恒不出现；未开通会员时没有余额支付；未配置 LianLianPay 时没有 LianLianPay。所以列表里没有，不代表商户没配。
- 字段：`uuid`（字符串）、`name`（普通字符串）、`source`（`0` 系统，`1` 手动，`2` LianLianPay，`3` Kbank）、`status`（`0` 禁用，`1` 启用，`2` 草稿）、`sort`、`logo_file`。

## `get <uuid>`

- 只输出 JSON。`data` 多一层壳：`{"payment_method":{...}}`。
- `uuid`、`logo_file_uuid`、`qrcode_file_uuid` 是 number 且超过 2^53，与 `list` 的字符串 `uuid` 类型不同，不要转 double。
- `fee_percent` 已是百分数，`2.5` 就是 2.5%，不要再乘 100。
- `is_show_cashier` `is_show_assistant` `is_show_kiosk` `is_show_member_recharge` `is_show_tablet` `is_show_mobile`（各终端结账是否显示）和 `is_takeaway`（是否计入外卖统计）都是整数 `0/1`。
- `name` 和 `payment_name` 是两个字段，值可能不同。
- `logo_file`、`qrcode_file` 可能是空串。
- uuid 不存在时 exit 1。

## `default`

系统内置清单，没有分页，`count` 是条数。

`can_add` 是原生 bool：Kbank 类已添加过时为 `false`，其余恒为 `true`。**`true` 不代表商户没添加过**，判断是否已开通看 `list`。

退出码见 `ttpos help exit-codes`。
