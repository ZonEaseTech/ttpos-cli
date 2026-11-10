---
name: ttpos-product
description: Looks up TTPOS products and categories through the ttpos CLI, plus units, sauces (加料), attribute groups, flavors (规格), single-spec products and tax classes. Use when asked 有哪些商品, 这个分类下有多少商品, 商品详情, 商品分类树, 商品单位, 加料, 属性分组, 规格, 税类, 税率. Not for recipes and cost cards (ttpos-bom), orders, desks or staff.
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-product

先读 `ttpos-shared`。查询上限：有分页的列表每页最多 100 条。

## 能回答的问题

| 问题 | 命令 |
|---|---|
| 某个商品多少钱、上没上架、在哪个分类 | `ttpos product list --keyword <名称>` |
| 有哪些分类 | `ttpos product category list` |
| 有哪些商品标签、各关联多少商品 | `ttpos product labels` |
| 某个商品在哪些时段可售（时段菜单） | `ttpos product periods`（`--channel 2` 看 Grab） |
| 谁改过时段菜单 | `ttpos product period-log` |
| 有哪些分批上菜类型 | `ttpos product batch-tags` |
| 商品的规格、加料、税类 | `ttpos product get <uuid>` |

## 命令

```bash
ttpos product list --category-uuid <分类uuid> --keyword <关键字> --page 2 --size 100
ttpos product get <uuid>
ttpos product category list
```

| 子域 | 命令 | 分页 | 过滤 |
|---|---|---|---|
| 单位 | `product unit list`、`unit get <uuid>` | 有 | 无 |
| 加料 | `product sauce list`、`sauce get <uuid>` | 有 | 无 |
| 属性分组 | `product attr-group list`、`attr-group get <uuid>` | 有 | 无 |
| 规格 | `product flavor list`、`flavor get <uuid>` | 有 | `--keyword` |
| 单规格商品 | `product single list`，没有 `get` | 有 | `--keyword` `--category` |
| 税类 | `product tax list`，没有 `get` | 无 | 无 |

注意分类过滤的参数名：`product list` 是 `--category-uuid`，`product single list` 是 `--category`。

## 读输出

- **名称**：`product list`、`product single list` 用多语言对象 `locale_name`，key 是 `zh` `zhtw` 等，没有 `zh_CN`；表格只显示一种语言，要其他语言读 JSON。unit、sauce、attr-group、flavor、tax 列表的 `name` 和分类的 `name` 是普通字符串。
- **详情**：`product get` 和四个子域 `get` 输出未建模的原始 JSON，`--format table` 也一样。字段可能与列表不同，不要假设两者一致。
- **`is_editable` 是 bool**（unit、sauce、attr-group 及 `attributes[]`），不是 `0/1`。
- **`attr-group`**：顶层 `uuid` 是字符串，`attributes[].uuid` 是 number，要分别处理。
- **`product category list`**：`data` 是树。`children` 不是数组，子分类在 `children.list`。`count` 只计顶层分类，不含子分类。没有过滤参数，只能整树取。
- **`product tax list`**：全量返回，没有 `--page`/`--size`，`count` 是条数。`rate` 是小数原值（如 `0.07`），不要说成 `0.07%`。
- **`product single list`**：没有价格字段，不是遗漏，查价格用 `product list`。

退出码见 `ttpos help exit-codes`。
