---
name: ttpos-stats
description: Answers TTPOS business-performance questions through the ttpos CLI - a shop's revenue, received amount, order count and average order value for a day or date range, revenue comparison across the account's shops, top-selling dishes, income by payment method, and staff commission. Use when asked 营业额, 今天卖了多少, 实收, 客单价, 本月营业额, 各店对比, 哪家店卖得好, 热销, 卖得最好的菜, 支付方式收入, 现金收了多少, 员工业绩, 提成. Not for listing individual orders (ttpos-order).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-stats

先读 `ttpos-shared`。

## 能回答的问题

| 问题 | 命令 |
|---|---|
| 今天营业额、实收、订单数、客单价 | `ttpos stats business` |
| 昨天、本周、本月的营业额 | `ttpos stats business --date yesterday`（或 this-week、this-month、last-month） |
| 指定日期范围的营业额 | `ttpos stats business --from 2026-10-01 --to 2026-10-31` |
| 名下各门店营业额对比、哪家店卖得最好 | `ttpos stats shops --date yesterday` |
| 卖得最好的菜 | `ttpos stats products --date this-week`（`--by 2` 按销售额） |
| 各支付方式收了多少 | `ttpos stats payments --date yesterday` |
| 员工业绩、提成 | `ttpos stats commission --date this-month` |

## 时间

- 不传时间就是今天；统计不能查全部历史。
- `--date` 取 today、yesterday、this-week、last-week、this-month、last-month；或用 `--from/--to YYYY-MM-DD`，最长 31 天，超过 exit 2，请分段查询后自己相加。
- 按门店的营业日算：跨 0 点营业的店，凌晨的单算前一天，所以和按自然日数订单的结果可能不同。

## 读结果

- `stats business` 的字段：`total_sales` 营业额，`total_received_price` 实收，`total_order_num` 订单数，`avg_order_price` 平均每单金额，`total_people_num` 用餐人数，`total_refund_money` 退款，`total_cancel_order_num` 取消单数，`total_discount_money` 优惠，`payment_method_incomes` 各支付方式收入。
- `total_order_num` 只算已完成的单。用户问"一共有多少笔订单"（含待付款、已取消）时用 `ttpos order list` 的 `count`；两个数不一样时都说清楚口径。
- "客单价"在门店报表里有时指人均。用户问客单价时说明这里是"平均每单金额"；人均需要 `total_people_num`，为 0 表示没有登记人数，不要自己用订单数代替。
- `stats shops` 逐店查询账号能访问的全部门店，门店多时要等一会儿。某家店失败时 `error` 有原因，其他店照常返回；汇报时把失败的店单独说明，不要当成 0。
- `stats products` 只返回前 10；`stats commission` 账号没有提成权限时只返回自己。

退出码见 `ttpos help exit-codes`。
