---
name: ttpos-marketing
description: Looks up TTPOS marketing through the ttpos CLI - marketing activities (invite rewards, scan-for-coupon, sign-up gift, member coupon grants) and who claimed or used their coupons, coupons with remaining stock and validity plus issue and redemption records, and full-reduction (spend X save Y) activities. Use when asked 营销活动, 邀请有礼, 扫码领券, 注册有礼, 优惠券, 券还剩多少, 谁领了券, 核销了多少, 满减活动. Not for member balances or points (ttpos-member).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-marketing

先读 `ttpos-shared`。

## 能回答的问题

| 问题 | 命令 |
|---|---|
| 现在有哪些营销活动、进行到哪一步 | `ttpos marketing activities` |
| 某个活动有多少人领券、用了多少 | `ttpos marketing claims <activity_uuid>`（`--status 2` 只看已使用） |
| 有哪些优惠券、每张还剩多少、什么时候过期 | `ttpos marketing coupons` |
| 某张券的发放和核销记录 | `ttpos marketing coupon-records <coupon_uuid>`（`--type 6` 只看核销） |
| 正在进行的满减活动和规则 | `ttpos marketing full-reductions --status in_progress` |

## 读结果

- 门店没有开启会员营销时，活动相关查询会报错；没开启优惠券时，优惠券查询会报错。如实转告，不要当成没有数据。
- `marketing claims` 和 `coupon-records` 里的会员姓名打码、手机只给尾号；要看某个会员的完整信息，用 `ttpos member get <member_uuid>`。
- `coupons` 的 `count` 是剩余张数，`total_count` 是总量。
- 活动详情（含海报图）不提供。
