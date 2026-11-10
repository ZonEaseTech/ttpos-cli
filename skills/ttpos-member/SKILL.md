---
name: ttpos-member
description: Looks up TTPOS members through the ttpos CLI - searching by phone number, member number, nickname or card number, reading a member's balance, gift balance, points, level and lifetime spending, and listing their consumption, recharge and points history. Use when asked 查会员, 会员余额, 余额还有多少, 积分, 会员等级, 会员消费记录, 充值记录, 这个手机号是不是会员. Not for member delivery orders (ttpos-member-order) or recharge orders with refundable amounts (ttpos-recharge).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-member

先读 `ttpos-shared`。账号所在门店没开会员功能或账号没有会员权限时，命令会返回上游错误，照实告诉用户。

## 能回答的问题

| 问题 | 命令 |
|---|---|
| 按手机号、会员号、昵称、会员卡号找会员 | `ttpos member list --keyword <手机号或会员号>` |
| 会员余额、积分、等级、累计消费 | 先 `member list` 找到 uuid，再 `ttpos member get <member_uuid>` |
| 会员的消费记录 | `ttpos member flow <member_uuid> --type 1` |
| 会员的充值记录 | `ttpos member flow <member_uuid> --type 2` |
| 有哪些会员等级 | `ttpos member levels` |

## 全体会员的统计与流水

| 问题 | 命令 |
|---|---|
| 所有会员一共还有多少储值余额 | `ttpos member overview` |
| 充值最多、消费最多的会员 | `ttpos member recharge-rank`、`ttpos member consume-rank --by 2` |
| 一段时间内谁的积分、余额有变动 | `ttpos member points` / `ttpos member balances --from ... --to ...`（`--keyword` 指定会员，`--scene` 指定场景） |
| 有哪些会员卡、谁持有、什么时候到期 | `ttpos member card-types`、`ttpos member cards --status 1` |

这些是列表，手机号和昵称打码；要看某个会员的完整信息，用 `member get <member_uuid>`。门店没开启会员功能或账号没有对应权限时会报错，如实转告。

## 要点

- `--keyword` 是模糊匹配，可能命中多个会员；多个时列出候选，让用户确认是哪一位，不要替他选。
- `member list` 的结果手机号、昵称打码；`member get` 按 uuid 查单条，完整显示。打码后的值不能再拿去搜。
- 余额分两部分：`balance` 本金，`gift_balance` 赠送；两者都含冻结部分。用户问"余额"时两项都报。
- `member flow` 的 `type`：1 消费、2 充值、3 积分、4 其他；`amount` 是这笔单据金额，`balance_delta` 是余额变动。可加 `--from/--to` 限定日期。
- 会员 uuid 是字符串，按字符串传。

退出码见 `ttpos help exit-codes`。
