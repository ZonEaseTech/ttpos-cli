---
name: ttpos-order
description: Looks up TTPOS sales orders through the ttpos CLI, listing them by date range, status or 18-digit order number fetching one order's detail by 16-digit sale_bill_uuid, and exporting a period's orders to Excel files, one file per store, for one store or every store the account can access. Use when asked 导出订单, 导订单明细, 每家门店的订单表, 把上个月的订单导出来, 查订单, 最近的订单, 某天的订单, 这笔订单的详情, 按订单号查, or given an order number or sale_bill_uuid. Not for member orders (ttpos-member-order) or recharge orders (ttpos-recharge).
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
| 把某个月的订单导出成表格，每家门店一个文件 | `ttpos order export --all --month 2026-10` |

有哪些订单来源（外卖来源等）、是否启用：`ttpos order sources`。

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

## 导出订单：`ttpos order export`

用户说「导出某某商户某个月的订单」时用。只需要弄清两件事：哪个商户、哪段时间。其余不用问用户。

```bash
ttpos order export --all --month 2026-10                  # 当前账号能访问的全部门店，一家一个文件
ttpos order export --shop <商户> --month 2026-10           # 只导一家
ttpos order export --all --from 2026-10-01 --to 2026-10-15 --out ./订单
```

怎么做：

1. **认时间。**「上个月」「10 月」换成 `--month YYYY-MM`；给了起止日期用 `--from/--to`。一次最多 31 天，跨月的要求按月分几次跑。用户没说时间就问一句，不要猜。
2. **认商户。** 连锁客户用总部账号登录，`--all` 就是它名下的全部门店（先 `ttpos shop list` 看一眼有几家、是不是用户说的那个客户）。只要其中几家，就对每家各跑一次 `--shop`。当前登录的不是这个客户的账号，让用户先 `ttpos auth login` 换成客户的账号。
3. **直接跑，不用预览。** 导出只读数据，不改任何东西。门店多、订单多时要几分钟，等它跑完。
4. **报告结果。** 读输出的 `data.dir`（文件所在目录）和 `data.list`（每家店的 `status`、`orders`、`order_amount`、`payment_amount`、`file`），告诉用户：文件在哪、导了几家、共多少单，哪几家是 0 单，哪几家失败。
5. **有失败（exit 1）就原样再跑一次同一条命令。** 已导出的文件会跳过，只补失败的门店。要重新导出已有的文件加 `--force`。

表格内容：每张订单一行，列为订单ID、订单类型、商品信息、订单号、状态、支付时间（门店当地时间）、订单金额、优惠折扣、实付金额、退款金额、支付方式。包含待付款和已取消的订单，用「状态」列区分。文件名是 `门店编码_订单明细_门店uuid_起_止.xlsx`。表里不含会员手机号等联系方式。

内容默认中文；客户要英文或泰文加 `--lang en` / `--lang th`。不要自己打开表格改数字或重算合计；用户要别的列或别的格式，如实说现在只有这一种，并用 `ttpos feedback` 记下来。

退出码见 `ttpos help exit-codes`。
