---
name: ttpos-order
description: Looks up TTPOS sales orders through the ttpos CLI, listing them by date range, status or 18-digit order number fetching one order's detail by 16-digit sale_bill_uuid, and exporting a period's dine-in orders to Excel files (one file per store plus a summary sheet, zipped) for one store or every store the account can access, as a background job polled by re-running the same command. Use when asked 导出订单, 导订单明细, 每家门店的订单表, 把上个月的订单导出来, 查订单, 最近的订单, 某天的订单, 这笔订单的详情, 按订单号查, or given an order number or sale_bill_uuid. Not for member orders (ttpos-member-order) or recharge orders (ttpos-recharge).
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

用户说「把某某客户某个月的订单导出来」「某某的几十家店 10 月的数据我都要」时用。只需要弄清两件事：哪个客户、哪段时间。其余不用问用户。

```bash
ttpos order export --all --month 2026-10                  # 当前账号能访问的全部门店
ttpos order export --shop <商户> --month 2026-10           # 只导一家
ttpos order export --all --from 2026-10-01 --to 2026-10-15
```

导出在后台进行，这条命令最多等 1 分钟就返回进度。**同一条命令反复运行就是查进度，不会重复导出**，所以整个过程就是「运行 → 看 `data.state` → 没完就再运行」。

### 步骤

1. **认时间。**「上个月」「10 月」换成 `--month YYYY-MM`；给了起止日期用 `--from/--to`。一次最多 31 天，跨月的要求按月分几次。用户没说时间就问一句，不要猜。
2. **认客户。** 运行 `ttpos shop list`，看当前账号下有几家店、是不是用户说的那个客户。连锁客户要用客户的总部账号登录，`--all` 才是它名下的全部门店。不是这个客户的账号，或者门店数和用户说的差很多，先告诉用户，让他 `ttpos auth login` 换成客户的账号，不要导错客户。只要其中几家时，对每家各用一次 `--shop`（一次只能跑一个导出，等上一个完成）。
3. **运行导出命令**，不需要预览，它只读数据。
4. **看 `data.state`：**

   | state | 意思 | 你要做的 |
   |---|---|---|
   | `running` | 还在导，`data.finished`/`data.total` 是进度 | 告诉用户进度，然后**原样再运行同一条命令**。重复到不是 `running` 为止。不要加 `--force`，不要换目录，不要同时开第二个导出 |
   | `done` | 全部导完 | 进入第 5 步 |
   | `failed`（exit 1） | 有门店没导出来 | 原样再运行一次，只会补导失败的门店。连续两次还是失败：运行 `ttpos auth status`，登录失效就让用户重新登录；登录正常就把失败的门店和 `error` 原样告诉用户，不要一直重试 |

5. **交付。** 告诉用户：
   - 压缩包的位置（`data.zip`），里面是每家门店一个表格，加一张 `汇总.xlsx`；
   - 一共几家店、多少张账单、订单金额和实付金额合计（`data.total`、`data.orders`、`data.order_amount`、`data.payment_amount`）；
   - 哪几家是 0 单（`data.list[]` 里 `orders` 为 0 的），请用户确认这些店当月是否确实没营业；
   - 这份导出只含用餐订单（桌台、点餐），不含外送、第三方外卖和充值。

### 被拒绝时（硬限制，不要绕过）

为了不影响商户正常营业，程序自己限制导出的量。遇到下面的提示，**把原因和可以再试的时间告诉用户，然后停下**。不要换目录、换参数、拆成多条 `--shop`、改用 `order list` 翻页凑数据，也不要删除 `~/.ttpos` 里的文件：

| 提示 | 意思 | 做法 |
|---|---|---|
| 本机已经有一个导出在进行 | 一台电脑同一时间只跑一个 | 等它完成（运行它那条命令可以看进度） |
| 公司里已经有 2 个导出在同时进行 | 全公司同时最多 2 个 | 过几分钟再运行同一条命令 |
| 后台响应很慢，已停止导出；某某时间之前不能再导出 | 后台正忙，程序主动停了，10 分钟内不让再开始 | 告诉用户几点之后再试；到时间后运行同一条命令会接着导 |
| 连续 3 家门店导出失败，已停止 | 多半是登录失效 | 运行 `ttpos auth status`；登录失效让用户重新登录，到时间后再运行 |
| 这台电脑 24 小时内的导出量已到上限 | 一天的总量用完了 | 告诉用户什么时候可以继续；确实不够用，用 `ttpos feedback` 说明情况 |

### 要知道的事

- 几十家店要几分钟到十几分钟，中间多次看到 `running` 是正常的。命令被中断、电脑断网、会话结束都不要紧，再运行同一条命令会接着导。
- 表格和商户后台「用餐订单 › 导出」的列一样：订单ID、订单类型、商品信息、桌号/序号、订单号、状态、支付时间、订单金额、服务费、优惠折扣、会员折扣、实付金额、退款金额、会员、支付方式、用餐方式、收银员。包含待付款和已取消的订单，用「状态」列区分。后台一次最多导 1000 条，这里没有这个限制。
- 「会员」一列的姓名和手机号是打码的。客户需要完整的会员信息，请用户到商户后台查看。
- 文件名是 `门店编码_订单明细_门店uuid_起_止.xlsx`。内容默认中文，客户要英文或泰文加 `--lang en` / `--lang th`（表头仍是中文）。
- 文件缺省放在电脑的「下载」文件夹（没有这个文件夹时放当前目录），以输出的 `data.zip`、`data.dir` 为准。
- 按开台时间筛选，日期按各门店当地时间。后台导出时如果选的是支付时间，月初月末跨天的订单会有几单出入，用户问起就这样解释。
- 已经导出过的不会重导。数据有变化、需要重新导出时才加 `--force`。
- 不要自己打开表格改数字、重算合计或合并文件。用户要别的列或别的格式，如实说现在只有这一种，并用 `ttpos feedback` 记下来。

退出码见 `ttpos help exit-codes`。
