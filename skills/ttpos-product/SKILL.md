---
name: ttpos-product
description: Looks up TTPOS products and categories through the ttpos CLI, plus units, sauces (加料), attribute groups, flavors (规格), single-spec products and tax classes. Use when asked 有哪些商品, 这个分类下有多少商品, 商品详情, 商品分类树, 商品单位, 加料, 属性分组, 规格, 税类, 税率. Also changes prices and on/off-shelf status in bulk through a preview-confirm-undo flow, assigns dishes to kitchen printer stations, and audits a menu for wrong prices and dishes without a kitchen printer. Use when asked 批量改价, 涨价, 降价, 上架, 下架, 菜单检查, 没配打印, 配打印, 打印档口, 厨房不出单, 加了新菜. Not for recipes and cost cards (ttpos-bom), orders, desks or staff.
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
| 菜单有没有配错：价格离谱、上架了没配厨房打印 | `ttpos product audit` |

## 改菜单（改价、上下架、配打印）

客户要求改价或上下架时按这四步做，不要跳步：

1. **生成改动单（不会修改）**：
   - 改价：`ttpos product change price` 加选择条件和一种改法（`--set 59`、`--add 5`、`--percent 10`，可加 `--round-to 1` 取整）。
   - 上下架：`ttpos product change status --on` 或 `--off` 加选择条件。
   - 配打印档口：`ttpos product change printer --set <档口名>` 加选择条件；多个档口用逗号分隔。档口名从 `ttpos product audit` 的 `notice` 里看。
   - 选择条件：`--uuid <a>,<b>`、`--category <分类名或 uuid>`、`--keyword <名称里的词>`、`--all`。一张改动单最多 50 个商品，超过就按分类分几次。
2. **把预览给用户核对**：逐项列出「现在 → 改成」，`warnings` 里的每条提醒都要原样告诉用户（例如前后相差 10 倍、和同分类价格差太多、一次下架很多）。有提醒时先问清楚再继续。
3. **执行**：
   - 上下架和配打印：把预览发给用户，等用户回复同意后，再运行 `ttpos change apply <编号> --yes`。生成和执行不要放在同一轮里做。唯一的例外：用户点名了一个具体商品、预览里只有这一项且没有提醒，可以直接执行。
   - 改价：你不能执行。请用户自己在终端运行 `ttpos change apply <编号>` 并输入确认码（Claude Code 里是 `! ttpos change apply <编号>`）。返回 `REVEAL_REQUIRES_TERMINAL` 就是这个原因，不要重试，也不要想办法绕过。
4. **核对并告知怎么撤回**：执行后看每项的 `result`，再告诉用户「要改回去运行 `ttpos change undo <编号>`」。

- 执行时提示「现在的值和改动单不一致」，说明有人在这之后改过，重新生成改动单。
- 总部管控的商品门店不能改，会被跳过并写在 `warnings` 里。
- **加菜后的闭环**：客户加了新菜、或让你检查菜单时，运行 `ttpos product audit`。有「没配打印」的菜，就告诉用户这些菜下单后厨房不出单，并问要分到哪个档口（把 `notice` 里的档口名列给用户选）；用户选好后用 `ttpos product change printer` 生成改动单，按上面第 2–4 步走。
- 配打印是把商品整体保存一遍，CLI 保存后会逐个核对其他字段没变。`result` 里出现「请到后台核对」，要原样告诉用户。套餐和带加料的商品暂不支持，会写在 `warnings` 里，请用户在后台配。
- `ttpos change list` 是本机的操作记录：谁、什么时候、替哪家店改了什么。

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
