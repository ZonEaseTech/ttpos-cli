---
name: ttpos-shop
description: Answers TTPOS shop-level questions through the ttpos CLI - which shops the account can access, setting the default shop, and which shops' licenses are about to expire or already expired (from the cloud platform). Use when asked 有哪些店, 能查哪些门店, 设默认门店, 门店到期, 快到期的店, 哪些店过期了, 授权还剩几天, 续费. Not for a shop's settings (ttpos-setting) or revenue (ttpos-stats).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-shop

先读 `ttpos-shared`（`--shop` 解析、默认商户和别名规则都在那里）。

## 能回答的问题

| 问题 | 命令 |
|---|---|
| 我能查哪些门店 | `ttpos shop list` |
| 之后都查这家店 | `ttpos shop use <标识>` |
| 哪些门店 30 天内到期或已过期 | `ttpos shop expiry` |
| 60 天内到期的 | `ttpos shop expiry --within 60` |
| 我负责的门店里哪些快到期 | `ttpos shop expiry --mine` |

## 门店到期

- 到期时间只有云平台能查，需要云平台账号，和商户账号是两套。没登录时 exit 3，请人运行 `ttpos auth login --cloud`（同样由人在浏览器完成，登录有效 10 小时）。
- 默认查云平台全部门店；`--mine` 只保留当前商户账号能访问的门店，需要两个账号都已登录。
- `days_left` 是剩余天数，负数表示已过期多少天；`expire_date` 是到期日；`status_text` 是门店在云平台是否启用。永不过期的门店不出现在结果里。
- 结果按到期时间从早到晚排。汇报时分"已过期"和"即将到期"两组。

退出码见 `ttpos help exit-codes`。
