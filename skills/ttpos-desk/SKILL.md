---
name: ttpos-desk
description: Lists TTPOS desks and desk regions through the ttpos CLI. Use when asked 有多少张桌台, 桌台列表, 桌台区域, 某个区域下有几张桌. Not for orders, products, staff or member data, and it does not show live occupancy or reservations.
---

# ttpos-desk

先读 `ttpos-shared`。

```bash
ttpos desk list --page 2 --size 100
ttpos desk region list
```

查询上限：`desk list` 每页最多 100 条。

## `ttpos desk list`

- 默认只返回第一页 20 条。`count` 是总桌台数，大于本页条数就要翻页，否则结果不全。回答"有多少张桌"直接用 `count`。
- 没有区域、状态、关键字过滤，只能翻页取全后自行筛选。
- `uuid`、`region_uuid`、`type_uuid` 是字符串。`region_name`、`type_name` 是现成名称。`is_disable` 是整数 `0/1`。
- 不含占用、预订等实时业务数据。

## `ttpos desk region list`

全量返回，没有 `--page`/`--size`，`count` 是区域数。每个区域的桌数直接读 `desk_count`，不用重新统计。返回的是区域本身，不是按区域分组的桌台。

退出码见 `ttpos help exit-codes`。
