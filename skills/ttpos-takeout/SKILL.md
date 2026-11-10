---
name: ttpos-takeout
description: Looks up TTPOS third-party delivery (Grab, LINE MAN) orders and platform connection status through the ttpos CLI - finished orders for a business day or date range, orders still in progress, one order's items and amounts, and whether a platform is enabled, bound and when the menu was last pushed. Use when asked 外卖订单, Grab 订单, LINE MAN 订单, 外卖取消单, 还有哪些外卖没送完, 外卖单详情, Grab 接好了没, 菜单推送. Not for dine-in orders (ttpos-order) or member delivery orders placed in the TTPOS member app (ttpos-member-order).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-takeout

先读 `ttpos-shared`。

## 能回答的问题

| 问题 | 命令 |
|---|---|
| 今天有哪些外卖订单 | `ttpos takeout orders` |
| 昨天、上周的外卖订单 | `ttpos takeout orders --date yesterday`（或 last-week、this-month） |
| 某个平台的订单 | `ttpos takeout orders --platform grab`（或 lineman） |
| 取消了哪些外卖单 | `ttpos takeout orders --status 60`（50 已拒单，40 已完成） |
| 按取餐号或平台单号找 | `ttpos takeout orders --search <号码>` |
| 现在还有哪些外卖单没完成 | `ttpos takeout active` |
| 一张外卖单的商品和金额 | `ttpos takeout get <uuid>` |
| Grab 有没有开、有没有绑定、菜单最近什么时候推送的 | `ttpos takeout status --platform grab` |
| Grab 促销我们出了多少钱、哪个活动花得最多 | `ttpos takeout promotion --date this-month` |
| Grab Dine Out 券核销了多少 | `ttpos takeout dine-out --date this-week`（`--code` 按券码查） |
| 推到外卖平台的菜单有哪些商品、价格、推送成功没有 | `ttpos takeout menu`（`--platform lineman`） |

## 读结果

- `takeout orders` 只列已经结束的订单（已完成、已拒单、已取消），按门店营业日计算，默认今天，最长 31 天。进行中的用 `takeout active`。
- `order_state_text` 是状态文字：待接单、已接单配餐中、待骑手接单、骑手配送中、已完成、已拒单、已取消。
- `subtotal` 是商品小计，不是门店实收。外卖营业额以 `ttpos stats business` 的「外送销售额」为准。
- 「外卖」指 Grab、LINE MAN 等第三方平台的订单；顾客在 TTPOS 会员端下的外送单是另一个业务域（`ttpos-member-order`）。

## 做不到的

外卖促销活动列表、营业时间、外卖商品上下架目前不支持，如实告诉用户，并按 `ttpos-shared` 的规则询问是否反馈需求。
