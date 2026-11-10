---
name: ttpos-tax
description: Reads Thai VAT tax-invoice reports through the ttpos CLI - the store's issued tax invoices for a date range (simple, full, voided, credit notes) and the PP.30 output-VAT summary. Use when asked 税票, 开了哪些税票, 作废税票, 红冲, 销项税, PP.30, VAT 报告. Requires the account to have the sales VAT report permission. Not for order lists (ttpos-order).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-tax

先读 `ttpos-shared`。

## 能回答的问题

| 问题 | 命令 |
|---|---|
| 今天开了哪些税票 | `ttpos tax report` |
| 某段时间的税票、作废的、红冲的 | `ttpos tax report --from 2026-10-01 --to 2026-10-31 --category voided`（或 simple、full、credit_note） |
| 按税票号找 | `ttpos tax report --keyword <税票号>` |
| 一个月的 PP.30 销项税汇总 | `ttpos tax pp30 --from 2026-10-01 --to 2026-10-31` |

## 读结果

- 时间按门店时区，不传默认今天，最长 31 天；按开具时间筛。
- 账号没有「销售税报告」权限时会报无权限，如实转告。
- `tax report` 分页返回时 `reconcile` 汇总为 0，要汇总数用 `tax pp30`。
- 税票的买方信息、开票和作废操作不提供。
