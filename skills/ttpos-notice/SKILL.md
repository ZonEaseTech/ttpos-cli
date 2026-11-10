---
name: ttpos-notice
description: Reads the TTPOS back-office notifications of the logged-in account through the ttpos CLI - unread counts, recent notices about orders, inventory, delivery, operations, marketing and system events, and pending approval reminders. Read only; viewing never marks a notice as read. Use when asked 未读通知, 有什么通知, 系统通知, 待审批, 审批提醒. Not for staff operation logs (ttpos-staff).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-notice

先读 `ttpos-shared`。

## 能回答的问题

| 问题 | 命令 |
|---|---|
| 有多少条未读通知 | `ttpos notice unread` |
| 最近收到了哪些通知 | `ttpos notice list` |
| 有哪些待审批的提醒 | `ttpos notice list --section approval` |

## 读结果

- 通知只属于当前登录的账号，换账号看到的不一样。
- 查看不会标为已读；`read_time` 为空表示未读。
- 翻页：把返回的 `next_cursor` 传给 `--cursor`，`has_more` 为 false 时到底。
- 不能在 CLI 里把通知标为已读或处理审批，请到 TTPOS 后台操作。
