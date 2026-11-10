---
name: ttpos-desk
description: Lists TTPOS desks and desk regions through the ttpos CLI. Use when asked 有多少张桌台, 桌台列表, 桌台区域, 某个区域下有几张桌, 哪些桌有人, 空桌. Also shows whether each desk is currently open (占用) or free. Not for orders, products, staff, member data or reservations.
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-desk

先读 `ttpos-shared`。

## 能回答的问题

| 问题 | 命令 |
|---|---|
| 有多少张桌、哪些桌有人 | `ttpos desk list --size 100` |
| 有哪些区域、每个区域几张桌 | `ttpos desk region list` |
| 平面图的区域、布局配了没有 | `ttpos desk map` |
| 一个区域里每张桌的位置 | `ttpos desk layout <region_uuid>`（uuid 取自 `desk map`） |

```bash
ttpos desk list --page 2 --size 100
ttpos desk region list
```

查询上限：`desk list` 每页最多 100 条。

## `ttpos desk list`

- 默认只返回第一页 20 条。`count` 是总桌台数，大于本页条数就要翻页，否则结果不全。回答"有多少张桌"直接用 `count`。
- 没有区域、状态、关键字过滤，只能翻页取全后自行筛选。
- `uuid`、`region_uuid`、`type_uuid` 是字符串。`region_name`、`type_name` 是现成名称。`is_disable` 是整数 `0/1`。
- `status_text` 是开台状态：空闲或已开台（有人）。不含预订数据。

## `ttpos desk region list`

全量返回，没有 `--page`/`--size`，`count` 是区域数。每个区域的桌数直接读 `desk_count`，不用重新统计。返回的是区域本身，不是按区域分组的桌台。

退出码见 `ttpos help exit-codes`。
