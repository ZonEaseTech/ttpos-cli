---
name: ttpos-recharge
description: 'Looks up TTPOS member recharge orders (会员充值订单) through the ttpos CLI, listing them by date range or order number, fetching one order by uuid, and reading its refundable amount without executing a refund. Use when asked 最近充值了多少笔, 充值订单详情, 这笔充值能退多少钱. Not for regular sales orders (ttpos-order) or member orders (ttpos-member-order).'
---

# ttpos-recharge

先读 `ttpos-shared`。

## `ttpos recharge list`

```bash
ttpos recharge list                                     # 最近 7 天
ttpos recharge list --from YYYY-MM-DD --to YYYY-MM-DD --page 2 --size 100
ttpos recharge list --order-no <订单号> --from YYYY-MM-DD --to YYYY-MM-DD
```

- 查询上限：每页最多 100 条，`--from/--to` 跨度最长 31 天。
- 不传日期默认最近 7 天。`--order-no` 不会放宽时间范围，更早的订单要同时传日期；"没查到"先看 `notice`。
- 只传 `--from` 时 `--to` 补到现在，日期太早会超 31 天；只传 `--to` 时 `--from` 补为往前 7 天。
- **日期按创建时间过滤**，不能按支付时间过滤。输出的 `payment_time` 可能与创建时间差好几天，查不到预期单据就放宽 `--from`。
- `status` 是原始整数状态码，没有文字映射，不要猜含义。
- 每项取 `uuid`（字符串）给 `get` 和 `refund-info` 用；金额看 `recharge_amount`、`gift_amount`；`payment_methods` 是字符串数组。

## `ttpos recharge get <uuid>`

`data` 是未建模的原始详情，`--format table` 也输出 JSON。常见字段：`uuid` `order_no` `member` `status` `cashier` `recharge_amount` `amount` `charge_due` `payment_time` `create_time` `gift_amount` `gift_point` `payment_methods` `operation_log` `extra`。

## `ttpos recharge refund-info <uuid>`

**只查询，不会退款**；本 CLI 没有退款命令。返回 `refundable_amount` `recharge_amount` `gift_amount` `gift_point` `recharge_member_info` `payment_records`。

- `<uuid>` 是 `recharge list` 的 `uuid`。不能传订单号，也不能传销售订单的 id。
- 只覆盖充值订单。销售订单、会员订单的可退金额本版不提供，不要拿这条命令代替。

退出码见 `ttpos help exit-codes`。
