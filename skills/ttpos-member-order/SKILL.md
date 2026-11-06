---
name: ttpos-member-order
description: Looks up TTPOS member orders (会员订单, 会员消费单) through the ttpos CLI, listing them by date range, status or order number and fetching one order's detail by member_sale_order_uuid. Use when asked 查会员订单, 今天的会员订单, 这笔会员订单的详情. Not for regular sales orders (ttpos-order) or recharge orders (ttpos-recharge).
---

# ttpos-member-order

先读 `ttpos-shared`。本版不提供 `member-order return-info`，被问到可退信息直接说没有。

## `ttpos member-order list`

```bash
ttpos member-order list                                       # 只查今天
ttpos member-order list --from YYYY-MM-DD --to YYYY-MM-DD --time-type 2
ttpos member-order list --status completed --from YYYY-MM-DD --to YYYY-MM-DD
ttpos member-order list --order-no <订单号> --from YYYY-MM-DD --to YYYY-MM-DD
```

- 查询上限：每页最多 100 条，`--from/--to` 跨度最长 31 天。
- **不传日期只查今天**，不是最近 7 天，也不是全部历史。"没查到"先看 `notice` 和时间范围。
- `--order-no` 不会放宽时间范围，查今天以前的订单要同时传日期。
- 只传 `--from` 时 `--to` 补到现在，日期太早会超 31 天；只传 `--to` 时 `--from` 补为往前 7 天。
- `--status` 取值：`unpaid` `unaccept` `accept` `undelivery` `delivery` `completed` `cancel`。
- `--time-type`：`1` 下单时间，`2` 支付时间，只在传了日期时有意义。
- 不能按会员筛选，也不含会员资料、等级、积分。

读输出：`data.list[].member_sale_order_uuid` 是字符串。表格的状态取 `status_group`（不是数字 `status`），金额取 `pay_amount`，时间取 `pay_time`。其余字段以实际输出为准。

## `ttpos member-order get <member_sale_order_uuid>`

uuid 取自 `list` 的 `member_sale_order_uuid`，不是订单号。`data` 是未建模的原始详情，`--format table` 也输出 JSON。

退出码见 `ttpos help exit-codes`。
