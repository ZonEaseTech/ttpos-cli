---
name: ttpos-bom
description: Looks up TTPOS recipes, BOM configuration and cost cards (配方, BOM, 成本卡) through the ttpos CLI, covering recipe modules, BOM status of products, combos and sauces, combo BOM summaries, the merchant-wide order BOM and spec-product cost cards. Use when asked 配方模块包含哪些行, 这个商品配了 BOM 吗, 这个套餐配置了哪些单品, 这个加料的 BOM, 订单 BOM, 成本卡的材料清单. Not for product lists and details (ttpos-product).
---

# ttpos-bom

先读 `ttpos-shared`。本版不提供 BOM 导出和导入模板下载，被问到直接说没有。

## 选哪条命令

| 想查 | 命令 |
|---|---|
| 配方模块列表（全量，无分页） | `ttpos bom module list --keyword <关键字>` |
| 配方模块详情 | `ttpos bom module get <uuid>` |
| 单品是否配了 BOM | `ttpos bom product list` |
| 套餐、加料是否配了 BOM | `ttpos bom product list --tab 1`（套餐）、`--tab 2`（加料） |
| 单品、加料、套餐组项的行级 BOM | `ttpos bom product get --owner-type 2\|3\|4 --owner-uuid <uuid>` |
| 套餐 BOM 汇总 | `ttpos bom combo get <uuid>` |
| 订单 BOM（整个商户一份） | `ttpos bom order get` |
| 规格商品成本卡 | `ttpos bom card get <uuid>` |

查询上限：`bom product list` 每页最多 100 条。

## 参数陷阱

- **`bom product list` 不传 `--tab` 只返回单品。** 查套餐、加料时不传不会报错，只会得到无关结果。
- `bom module list` 没有 `--page`/`--size`。
- `bom product get` 的 `--owner-type`（`2` 规格，`3` 加料，`4` 套餐组项）和 `--owner-uuid` 都必填，缺了 exit 2。取值不合法时由服务端报错，是 exit 1。
- 五个 `get` 只输出 JSON。

## 读输出

- 本域的布尔字段都是原生 `true/false`：`has_nested` `is_editable` `headquarter` `configured` `all_configured`。这只适用于本域。
- `bom module list` 的名称读 `locale_name`，`name` 是未解析的原文。表格「主行数」= `material_count` + `module_count`，不含 `alternative_count`（备选行）和 `ref_count`（被多少上层引用）。
- `bom product list` 的记录 id 是 `owner_uuid`，是否配置看 `configured`。
- `bom order get`：**`owner_type`、`owner_uuid` 恒为 0，没有业务含义，不要使用。** 有效数据在 `shared_lines` `dine_in_lines` `takeaway_lines` `leaf_preview`。
- `bom combo get`：`items[]` 每项同时有 `product_uuid` 和 `owner_uuid`，含义不同，不要混用。
- `bom card get`：`materials[]` 里 material、unit、unit_list 的 uuid 都是 number，不要转 double。

退出码见 `ttpos help exit-codes`。
