---
name: ttpos-setting
description: Reads a TTPOS merchant's configuration snapshot through the ttpos CLI for six types, covering business rules, cashier secondary screen, payment switches, kiosk, kitchen display and print copies. Use when asked 营业设置, 收银副屏轮播配了什么, 支付开关, 自助点餐机配置, 厨显等待颜色, 打印联数怎么配的. Read only. Not for the payment method list (ttpos-payment-method) or print templates (ttpos-printer).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-setting

先读 `ttpos-shared`。

## 能回答的问题

| 问题 | 命令 |
|---|---|
| 营业设置（营业时间、抹零等） | `ttpos setting get business` |
| 收银、支付、自助机、厨显、打印设置 | `ttpos setting get <类型>` |

```bash
ttpos setting get business
ttpos setting get kiosk | jq '.data.call_waiter_enabled'
```

- `<type>` 只能是 `business` `cashier` `payment` `kiosk` `kitchen` `print`。其他值 exit 2；`store` 也没有。
- 只输出 JSON，没有表格。`data` 是原始配置。
- **密码类恒为 `***`**：如 `kiosk` 的 `advanced_password`，`--reveal` 也不显示。这个字段只说明有这个键，不能用来查看或核对密码，需要时请用户到商户后台查看。

## 各 type 字段形态

同样是开关，类型不统一，按字段判断：

| type | 要点 |
|---|---|
| `business` | 开关多为字符串 `"0"/"1"`；`invoice_decimal_setting_editable` 是 bool。`batch_product_uuids` `discount_authorized_staff_ids` `refund_authorized_staff_ids` `change_salesperson_authorized_staff_ids` 是大整数 number 数组，不要转 double |
| `cashier` | 只有副屏 5 个字段：`carousel` `no_order_carousel_interval` `order_display_mode` `order_carousel` `order_carousel_interval`，不是完整收银配置。`carousel`、`order_carousel` 是数组，`order_display_mode` 是字符串枚举 |
| `payment` | `is_cash` `is_balance` `is_other` 是字符串 `"0"/"1"`；`payment_strategy` `skip_payment_enabled` 是整数 |
| `kiosk` | `call_waiter_enabled` 是整数；`advanced_password` 恒为 `***` |
| `kitchen` | `is_open` `is_come_dish` `is_call_service` `is_wait_color` `is_smart_kitchen` 是字符串 `"0"/"1"` |
| `print` | 只有 2 个字段：`enable_custom_copies` 是字符串 `"0"/"1"`；`checkout_slip_copies` 是整数或 `null`（未设置） |

`"0"` 是非空字符串，按 truthy 判断会得到错误结论，要比较值。输出里没有的字段就是拿不到，不要推断它的取值。

退出码见 `ttpos help exit-codes`。
