---
name: ttpos-printer
description: Lists TTPOS print templates (打印模板, 小票模板) and their template ids through the ttpos CLI, such as 预结账单, 结账单, 税票, 外卖联, 收银员汇总. Use when asked 有哪些打印模板, 结账单模板 id 是多少. List only, with no template details or previews. Not for print copy settings (ttpos-setting print type).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-printer

先读 `ttpos-shared`。本版只有模板列表，不提供模板详情、预览图和打印机配置，被问到直接说没有。

```bash
ttpos printer template list
```

查询上限：这条命令没有分页，全量返回。

## 读输出

```json
{"list":[{"locale_name":{"zh":"..."},"group_type":1,"list":[{"id":3,"locale_name":{"zh":"..."}}]}]}
```

- 两层嵌套：外层是分组，内层 `list` 才是模板。
- `count` 是所有分组累计的模板总数，不是分组数。
- `id` 是小整数模板号（如 `3` 预结账单、`2` 结账单、`7` 简易税票），不是 uuid。
- `locale_name` 的 key 是 `zh` `en` `th` `ja` `ko` `my` `tr` `sv` `zhtw`（`de` 可能为空串），没有 `zh_CN`。
- 顺序是固定业务顺序，不是创建时间。

退出码见 `ttpos help exit-codes`。
