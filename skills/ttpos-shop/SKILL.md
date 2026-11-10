---
name: ttpos-shop
description: Answers TTPOS shop-level questions through the ttpos CLI - which shops the account can access, setting the default shop, and which shops' licenses are about to expire or already expired (from the cloud platform). Also shows a shop's basic info (address, phone, tax number, store code, time zone) and its bound call-board screens. Use when asked 门店地址, 门店电话, 税号, 门店编号, 有哪些店, 能查哪些门店, 设默认门店, 门店到期, 快到期的店, 哪些店过期了, 授权还剩几天, 续费, 叫号屏, 取餐屏. Not for a shop's settings (ttpos-setting) or revenue (ttpos-stats).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-shop

先读 `ttpos-shared`（`--shop` 解析、默认商户和别名规则都在那里）。

## 能回答的问题

门店地址、电话、税号、门店编号、时区：`ttpos shop info`（默认门店，`--shop` 指定其他门店）。


| 问题 | 命令 |
|---|---|
| 我能查哪些门店 | `ttpos shop list` |
| 之后都查这家店 | `ttpos shop use <标识>` |
| 哪些门店 30 天内到期或已过期 | `ttpos shop expiry` |
| 60 天内到期的 | `ttpos shop expiry --within 60` |
| 我负责的门店里哪些快到期 | `ttpos shop expiry --mine` |
| 叫号屏、取餐屏绑定了哪些设备 | `ttpos shop devices` |

## 门店到期

- 到期时间只有云平台能查，只需要云平台账号，不需要商户账号。直接运行 `ttpos shop expiry`；没登录或过期时 exit 3，请人运行 `ttpos auth login --cloud`（由人在浏览器完成，有效 10 小时）。
- 默认查云平台全部门店；`--mine` 只保留当前商户账号能访问的门店，需要两个账号都已登录。
- `days_left` 是剩余天数，负数表示已过期多少天；`expire_date` 是到期日；`status_text` 是门店在云平台是否启用。永不过期的门店不出现在结果里。
- 结果按到期时间从早到晚排。汇报时分"已过期"和"即将到期"两组。

退出码见 `ttpos help exit-codes`。
