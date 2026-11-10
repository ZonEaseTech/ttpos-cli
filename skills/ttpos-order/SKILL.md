---
name: ttpos-order
description: Looks up TTPOS sales orders through the ttpos CLI, listing them by date range, status or 18-digit order number and fetching one order's detail by 16-digit sale_bill_uuid. Use when asked 查订单, 最近的订单, 某天的订单, 这笔订单的详情, 按订单号查, or given an order number or sale_bill_uuid. Not for member orders (ttpos-member-order) or recharge orders (ttpos-recharge).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-order

先读 `ttpos-shared`。本版不提供 `order return-info`（可退款信息）和 `order can-close`（能否关台），被问到直接说没有，不要根据订单字段推算。

## 能回答的问题

| 问题 | 命令 |
|---|---|
| 某段时间有哪些订单 | `ttpos order list --from 2026-10-01 --to 2026-10-07` |
| 按 18 位订单号查订单 | `ttpos order list --order-no <订单号>` |
| 取消了哪些单 | `ttpos order list --status 2` |
| 这单的明细、付款、退款情况 | `ttpos order get <sale_bill_uuid>` |

## 两种 id，别混

| id | 形态 | 怎么查 |
|---|---|---|
| `sale_bill_uuid` | 16 位数字 | `ttpos order get <sale_bill_uuid>` |
| 订单号 `order_no` | 18 位数字，前 8 位是日期 | `ttpos order list --order-no <订单号>`，再取结果里的 `sale_bill_uuid` |

- 拿到 18 位订单号：`order list --order-no` → 取 `data.list[].sale_bill_uuid` → `order get`。
- 拿到 16 位数字：直接 `order get`。它不是订单号，传给 `--order-no` 查不到，不能据此说"没找到订单"。
- 把 18 位传给 `order get` 会报用法错误（exit 2），按 hint 改用 `order list --order-no`。

## `ttpos order list`

```bash
ttpos order list                                     # 最近 7 天
ttpos order list --from YYYY-MM-DD --to YYYY-MM-DD --page 2 --size 100
ttpos order list --order-no <18位订单号>              # 不带日期时按订单号里的日期查询
ttpos order list --status 2                           # 0 待付款、1 已完成、2 已取消
```

- 查询上限：每页最多 100 条，`--from/--to` 跨度最长 31 天。
- 问"多少笔订单"用 `count`，它包含待付款和已取消；只问已完成的营业情况用 `ttpos stats business`（订单数只算已完成）。
- 不传日期默认最近 7 天，不是全部历史。只传 `--from` 时 `--to` 补到现在，日期太早会超 31 天；只传 `--to` 时 `--from` 补为往前 7 天。
- `--status` 取 0 待付款、1 已完成、2 已取消；输出的 `status_text` 是中文含义，直接用。
- `sale_bill_uuid` 是字符串。表格不显示它，要取值用 JSON。
- 结果为空先读 `notice`：它会说明实际查询范围，或提示这串数字不是订单号。

## `ttpos order get <sale_bill_uuid>`

`data` 是未建模的原始订单详情，`--format table` 也输出 JSON。只报告里面实际有的字段。

`consumer_uuids`、`member_uuids` 名字像 id，实际是 `昵称(手机号)`。按 uuid 查单条，会完整显示；`order list` 里是打码的。

退出码见 `ttpos help exit-codes`。
