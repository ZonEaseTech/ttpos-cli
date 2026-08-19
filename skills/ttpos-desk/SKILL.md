---
name: ttpos-desk
description: Use this skill when the user (or an agent) needs to look up TTPOS shop desks (餐桌/桌台) or desk regions via the `ttpos` CLI — list a shop's desks or its desk regions. Applies to questions like "这个门店有多少张桌台"、"桌台区域列表"、"某个区域下有几张桌". Do not use for orders, products, staff, or member accounts — those are separate skills/out of scope. `--shop` resolution (uuid/别名/商户名前缀、四级上下文兜底) is documented once in `ttpos-shared`, not repeated here — load that skill alongside this one if the question involves how `--shop` is identified rather than what desk commands return.
---

# ttpos-desk

`ttpos desk list` / `ttpos desk region list` 通过本地 gateway 查询 TTPOS
商户的桌台与桌台区域。两者都要求先完成 `ttpos auth login`（见
README「`auth login` 三步」），未登录直接 exit 3，不发起网
络请求。

## 前置条件

- gateway 已启动且可达（`TTPOS_GATEWAY_URL` 环境变量或 `--gateway` flag）。
- 已登录（本地凭证里有 token）。
- 目标商户的标识——uuid、本机别名、商户名全称或前缀都可以，也可以什么都
  不传，让四级上下文兜底。**这条解析规则是全部三域命令共用的**，完整说明
  见 `skills/ttpos-shared/SKILL.md`，本文档只讲 `desk` 命令特有
  的 flag。

## `ttpos desk list`

```bash
ttpos desk list --shop <company_uuid|别名|商户名前缀>
ttpos desk list                                    # --shop 省略，走四级上下文兜底
ttpos desk list --shop <标识> --format json         # 强制 JSON，即使在 TTY 下
```

| flag | 必填 | 说明 |
|---|---|---|
| `--shop` | 否 | 商户标识，解析规则见 `ttpos-shared`；缺省依次尝试 `TTPOS_SHOP` 环境变量、`ttpos shop use` 设置的默认商户，四级全空 exit 2 |
| `--page` | 否 | 页码，缺省由 gateway 兜底为 `1` |
| `--size` | 否 | 每页数量，缺省由 gateway 兜底为 `20` |
| `--format` | 否 | `json` \| `table`，不填按 TTY 自动判断 |
| `--gateway` | 否 | 覆盖 gateway 地址 |

**无 `--keyword`/`--category-uuid` 类过滤 flag**，只接受
`--shop`/`--page`/`--size`/`--format`/`--gateway`。

**有分页，默认每页 20 条**：上游 `desk/list` 实为分页接口（`page_no`/
`page_size`，缺省 `1`/`20`），响应顶层带 `total`。不传 `--page`/`--size`
时只拿到第一页；商户桌台数超过 20 时，**必须翻页才能拿全**（`--page 2`
拿下一页，以此类推）。信封 `count` 取的是上游顶层 `total`（总数），不是
本次返回的 `list` 长度——两者数量不一致是正常现象，`count` 大于当前页
`list` 长度就说明还有下一页。

**权限范围**：`--shop` 解析出的 uuid 若不在当前登录账号可访问的商户列表
内，gateway 返回 `403` + `SHOP_NOT_IN_SCOPE`（exit 1）。

**TTY 表格列**：UUID | 桌号 | 区域 | 类型 | 状态 | 禁用。`区域`/`类型` 列
直接用上游返回的 `region_name`/`type_name` 现成字符串，CLI 不做二次拼接
或查表；`禁用`列取 `is_disable`，`1` 显示「是」、`0` 显示「否」。
`uuid`/`region_uuid`/`type_uuid` 已做大整数保精度处理（字符串），JSON 输
出里同样是字符串，不要按 number 解析。

## `ttpos desk region list`

```bash
ttpos desk region list --shop <标识>
ttpos desk region list --shop <标识> --format json
```

- flag 与 `desk list` 完全一致（`--shop`/`--format`/`--gateway`），同样**无
  分页、无过滤**，端点是独立的 `/v1/shop/desk-regions`，返回的是区域列表
  本身，不是按区域分组的桌台。
- **TTY 表格列**：UUID | 名称 | 桌数。`桌数`（`desk_count`）是上游返回的
  现成统计字段，CLI 不重新计算。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 一般错误：上游/gateway 业务错误（含 `SHOP_NOT_IN_SCOPE` 403） |
| `2` | 用法错误：未知 flag、flag 值解析失败（cobra 层，统一为 exit 2 + JSON 信封）；`--shop` 解析失败（详见 `ttpos-shared`）、`--format` 取值非法（本域命令均无位置参数） |
| `3` | 未认证：本地无 token、上游会话过期需重新 `ttpos auth login` |

## 输出契约

同仓库其余命令一致：TTY 下人类可读表格，非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`
成功时写到 stdout；**失败**（`ok:false`）时信封改写到 **stderr**，stdout
为空，不能靠 stdout 是否为空判断成败，要看退出码。提示/诊断信息一律走
stderr。`resolved_shop` 字段与 `--shop` 解析结果的关系见 `ttpos-shared`。

## 已知局限

- **`desk list` 有分页，`desk region list` 无分页**：`desk list` 默认每页
  20 条，商户桌台数超过 20 必须用 `--page`/`--size` 翻页才能拿全，不翻页
  会静默只拿到第一页；`desk region list` 是真的全量返回，没有 `--page`/
  `--size`。
- **无过滤 flag**：不能按区域、状态、关键字过滤桌台，只能翻页拿全后自行
  在客户端筛选。
- `desk list` 的 `count` 取上游顶层 `total`（总数）；`desk region list` 的
  `count` 是响应里 `list` 数组的长度（该域上游不返回 `total`）。
- 只覆盖桌台与桌台区域本身，不含桌台当前占用/预订状态等实时业务数据。
