---
name: ttpos-printer
description: Use this skill when the user (or an agent) needs to list TTPOS shop print templates (打印模板/小票模板) via the `ttpos` CLI — which receipt templates a shop has (预结账单、结账单、税票、外卖联、收银员汇总等) and their template ids. Applies to questions like "这个门店有哪些打印模板"、"结账单模板 id 是多少". Read-only and list-only — it does not show template details or previews, and cannot edit templates or printers. Do not use for print settings (use ttpos-setting with the print type). `--shop` resolution is documented once in `ttpos-shared`.
---

# ttpos-printer

`ttpos printer template list` 通过本地 gateway 列出 TTPOS 商户的打印模板。
要求先完成 `ttpos auth login`，未登录直接 exit 3，不发起网络请求。

**只有列表，没有详情**：不提供 `printer template get`。服务端的模板详情查询
在模板缺少默认定制记录时会顺带写库创建一条，并为每个定制渲染预览图——它不
是纯读操作，本 CLI 刻意不接。打印机定制的编辑、预览、删除、启用等写操作同
样不提供。

## 前置条件

- 默认走进程内，无需 `ttpos gateway serve`；连远端时用 `--gateway` /
  `TTPOS_GATEWAY_URL` / config.json 的 `gateway_url`。
- 已登录。
- 目标商户标识，规则见 `ttpos-shared`。

## `ttpos printer template list`

```bash
ttpos printer template list --shop <标识>
ttpos printer template list --shop <标识> --format json
```

| flag | 必填 | 说明 |
|---|---|---|
| `--shop` | 否 | 商户标识，缺省走四级上下文兜底，全空 exit 2 |
| `--format` | 否 | `json` \| `table`，不填按 TTY 自动判断 |
| `--gateway` | 否 | 覆盖 gateway 地址 |

- **无分页、按分组嵌套**：`data` 形如
  `{"list":[{"locale_name":{...},"group_type":1,"list":[{"id":3,"locale_name":{...}}]}]}`。
  外层是分组（目前只有"收银小票"一组，`group_type=1`），内层才是模板。
- **`count` 是跨分组累加的模板总数**，不是分组数。
- `id` 是小整数模板号（如 `3` 预结账单、`2` 结账单、`7` 简易税票），不是大
  整数 uuid。
- `locale_name` 是多语言对象，key 为 `zh` / `en` / `th` / `ja` / `ko` / `my` /
  `tr` / `sv` / `zhtw`（`de` 可能为空串），**不是** `zh_CN`。
- 只返回商户库里存在的、且在固定展示顺序清单内的模板；顺序是固定业务顺序，
  不是创建时间。
- **TTY 表格列**：分组 | ID | 名称。名称取中文（`zh`），缺失时回落 `zhtw`，
  再回落任一非空语言。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 上游/gateway 业务错误（含 `SHOP_NOT_IN_SCOPE` 403） |
| `2` | 用法错误：多余位置参数、未知 flag、`--shop` 解析失败、`--format` 非法 |
| `3` | 未认证 |

## 输出契约

TTY 下人类可读表格，非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`。
成功写 stdout；失败信封写 stderr，按退出码判断成败。

## 已知局限

- 尚未在真实商户上完成端到端冒烟，形状按服务端定义整理。
- 不提供模板详情/预览图（原因见上），也不提供打印机定制配置查询。
