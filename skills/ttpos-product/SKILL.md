---
name: ttpos-product
description: Use this skill when the user (or an agent) needs to look up TTPOS shop products or product categories via the `ttpos` CLI — list a shop's products (with optional category/keyword filter), fetch a single product's full detail by uuid, list product categories, or query the product 细节簇 sub-domains (unit/sauce/attr-group/flavor/single/tax — 商品单位、加料、属性分组、规格、单规格商品、税类). Applies to questions like "查一下这个门店有哪些商品"、"这个分类下有多少商品"、"这个商品详情"、"商品分类树"、"这个商品有哪些单位/加料/属性分组/规格/税率". Do not use for orders, desks, staff, or member accounts — those are separate skills/out of scope. `--shop` resolution (uuid/别名/商户名前缀、四级上下文兜底) is documented once in `ttpos-shared`, not repeated here — load that skill alongside this one if the question involves how `--shop` is identified rather than what product filters do.
---

# ttpos-product

`ttpos product list` / `ttpos product get` / `ttpos product category list`
通过本地 gateway 查询 TTPOS 商户的商品与商品分类。三者都要求先完成
`ttpos auth login`（见 README「`auth login` 三步」），未登录
直接 exit 3，不发起网络请求。

## 前置条件

- 默认走进程内，无需 `ttpos gateway serve`；只有连远端时才需要 `--gateway` / `TTPOS_GATEWAY_URL` / config.json 的 `gateway_url`（优先级 `--gateway` > `TTPOS_GATEWAY_URL` > `gateway_url`，全空走进程内）。
- 已登录（本地凭证里有 token）。
- 目标商户的标识——uuid、本机别名、商户名全称或前缀都可以，也可以什么都
  不传，让四级上下文兜底。**这条解析规则是全部三域命令共用的**，完整说明
  见 `skills/ttpos-shared/SKILL.md`，本文档只讲 `product` 命令特
  有的 flag。

## `ttpos product list`

```bash
ttpos product list --shop <company_uuid|别名|商户名前缀>
ttpos product list                                          # --shop 省略，走四级上下文兜底
ttpos product list --shop <标识> --category-uuid <分类uuid> --keyword <关键字>
ttpos product list --shop <标识> --page 2 --size 50
ttpos product list --shop <标识> --format json               # 强制 JSON，即使在 TTY 下
```

| flag | 必填 | 说明 |
|---|---|---|
| `--shop` | 否 | 商户标识，解析规则见 `ttpos-shared`；缺省依次尝试 `TTPOS_SHOP` 环境变量、`ttpos shop use` 设置的默认商户，四级全空 exit 2 |
| `--category-uuid` | 否 | 按分类 uuid 过滤，直接透传给上游 |
| `--keyword` | 否 | 按商品名关键字过滤，直接透传给上游 |
| `--page` / `--size` | 否 | 不填由 gateway 兜底 |
| `--format` | 否 | `json` \| `table`，不填按 TTY 自动判断 |
| `--gateway` | 否 | 覆盖 gateway 地址 |

**权限范围**：`--shop` 解析出的 uuid 若不在当前登录账号可访问的商户列表
内，gateway 返回 `403` + `SHOP_NOT_IN_SCOPE`（exit 1）。

**多语言名：表格取一个语言，JSON 保留全部语言**——上游商品名（`locale_name`
字段）是多语言对象，真实 wire key 为 `"zh"`/`"zhtw"` 等（`main`
`LocaleResponse` 的字段名，没有 `"zh_CN"`）。TTY 表格的「名称」列只展示单
一字符串：CLI 取值优先级是 `zh_CN` → `zh` → `zhtw`（`zh_CN` 是兼容前缀，
实际数据里命中的是 `zh`），缺失/空串时按 key 字母序遍历取第一个非空字符
串，全空显示占位符。**这只是表格展示的取舍**——非 TTY / `--format json`
时，`data.list[]` 里每个商品对象的 `locale_name` 原样保留整个多语言对
象，agent 需要非中文语言版本时应读 JSON 输出，不要依赖表格列。

**TTY 表格列**：UUID | 名称 | 价格 | 状态 | 分类UUID。价格列显示
`最低价~最高价`（如 `9.90~29.90`）。`uuid`/`category_uuid` 已做大整数保精度
处理（字符串），JSON 输出里同样是字符串，不要按 number 解析。

## `ttpos product get`

```bash
ttpos product get 3745748940230657 --shop <商户uuid>
ttpos product get 3745748940230657 --shop <商户uuid> --format json
```

- 位置参数 `<uuid>` 必填，来自 `product list` 输出。
- `--shop` 同 `product list`，范围外同样 403 + `SHOP_NOT_IN_SCOPE`。
- **详情原样透传**：`data` 是上游商品详情的原始 JSON，gateway 和 CLI 都不做
  字段裁剪、重命名或数值中转，`--format table` 下也是直接打印这段原始
  JSON，不额外渲染表格。未建模的裸 JSON，字段含义需结合上游商品详情接口
  文档自行解读。

## `ttpos product category list`

```bash
ttpos product category list --shop <标识>
ttpos product category list --shop <标识> --format json
```

- 无 `--category-uuid`/`--keyword` 等过滤 flag，只接受 `--shop`/`--format`/
  `--gateway`。
- **树拍平展示**：上游返回的是树形分类结构（`children` 嵌套），TTY 表格用
  先序遍历拍平成 UUID | 名称 | 状态 三列，子分类的名称列前加缩进 +
  `└ ` 前缀标出层级，UUID 列本身足够唯一定位父子关系。非 TTY / `--format
  json` 时，`data` 保留原始树形结构（含 `children` 字段）不拍平——注意
  `children` 不是裸数组，是 `{"list":[...]}` 包一层，与顶层 `list` 同结
  构，解析时要先取 `children.list` 才能拿到子分类数组。
- 分类 `name` 在真实 wire 上是普通字符串（不是多语言对象），不经
  `localeName` 处理。`uuid`/`parent_uuid` 已递归做大整数保精度处理。
- `count` 取顶层分类数量（不含展开后的子分类总数）。

## 商品细节簇：unit / sauce / attr-group / flavor / single / tax

六个子域命令，全部挂在 `ttpos product` 下，前置条件同上（先
`ttpos auth login`，`--shop` 走同一套四级兜底，见 `ttpos-shared`）。本簇
上游共 10 个只读端点：unit/sauce/attr-group/flavor 各有 list+detail，
single/tax **只有 list**——`ttpos product single get`/`ttpos product tax
get` 不存在，不要凭其余四域"list+get 成对"的直觉去猜。

| 命令 | 表格列 | `--page`/`--size` | 其它 flag |
|---|---|---|---|
| `product unit list` / `unit get <uuid>` | uuid｜名称｜关联套餐数｜可编辑 | 有 | — |
| `product sauce list` / `sauce get <uuid>` | uuid｜名称｜价格｜关联套餐数 | 有 | — |
| `product attr-group list` / `attr-group get <uuid>` | uuid｜名称｜属性值 | 有 | — |
| `product flavor list` / `flavor get <uuid>` | uuid｜名称｜关联套餐数 | 有 | `--keyword` |
| `product single list`（无 get） | uuid｜名称 | 有 | `--keyword` `--category` |
| `product tax list`（无 get） | uuid｜名称｜税率 | **无**（上游无分页，全量返回） | — |

```bash
ttpos product unit list --shop <标识> --page 2 --size 20
ttpos product unit get 9007199254750002 --shop <标识>
ttpos product flavor list --shop <标识> --keyword 微辣
ttpos product single list --shop <标识> --keyword 汉堡 --category <分类uuid>
ttpos product tax list --shop <标识>                     # 无 --page/--size
```

**名称字段：五个纯字符串，仅 single 是多语言对象**——unit/sauce/
attr-group/flavor/tax 五个 list 的 `name` 都是纯字符串，表格直接显示原
文，不经 `localeName` helper；只有 `single` 的 item 级 `locale_name` 是多
语言对象（本簇 list 里唯一一个），名称列走既有 `localeName` helper
（`zh_CN`→`zh`→`zhtw` 链，同 `product list`）。四个 detail
（unit/sauce/attr-group/flavor 的 `get`）原样透传上游 JSON，不建模、不裁
剪字段，可能出现 list 里没有的字段（例如 detail 也可能带
`locale_name`），需自行按上游详情接口解读，不要假设 detail 和对应 list
的字段集合一致。

**`is_editable` 是真 bool，不是 int 0/1**——本簇的反向陷阱：仓库其它域常
见的"布尔用 int 0/1 表示"惯例在这里不成立，`is_editable`（`unit`/
`sauce`/`attr-group` 的 list 与 detail 均有，`attr-group` 嵌套
`attributes[]` 每项也有）都是原生 JSON `true`/`false`；`unit list` 表格
「可编辑」列按真 bool 渲染"是"/"否"，`sauce`/`attr-group` 的表格列子集
没有展示这一字段，不代表 `--format json` 的原始输出里没有——list 的
JSON 经顶层大整数字符串化（`bigIntFields`），字段全量保留；detail 为逐
字节透传，agent 解析 JSON 输出时同样按 bool 处理，不要按 int 判断。

**`attr-group` 嵌套 `uuid` 类型不一致（如实记录，非 bug）**——
`attr-group list` 顶层 item 的 `uuid` 已做大整数字符串化（同全仓一致），
但其 `attributes[]` 数组内每个元素的 `uuid` **保持原始 JSON number**，
不深字符串化（gateway 的 `stringifyBigInts` 只处理顶层 list item，不递
归嵌套数组）。当前量级 <2^53 不丢精度，但两个 `uuid` 类型不同——顶层是
string，`attributes[].uuid` 是 number——JSON 反序列化按同一类型处理会直
接失败或截断，agent/前端解析时要分别处理。`attr-group get` detail 全透
传，嵌套 `attributes[].uuid` 同样是 number。

**`tax` 无分页，全量返回**——`GET /v1/shop/product-taxes` 上游响应只有
`{"list": [...]}`，没有 `meta` 字段，`product tax list` 因此不注册
`--page`/`--size` flag（传参会被 cobra 拒为未知 flag，exit 2 + USAGE 信封，
统一后与其余用法错误同码），`count` 取
`len(list)`——与其余五个 list（`count` 取 `meta.total`）的语义不同，读
`count` 时不要假设它总是"上游已知的分页总条数"。`rate` 是浮点数直显（如
`0.07`），不做百分比换算。

**`single` 表格无价格列**——`product single list` 只有 uuid/名称两列，
上游 `ProductSingleListItemResp` 没有价格相关字段（`price`/
`min_price`/`max_price` 均不存在），不是遗漏。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 一般错误：上游/gateway 业务错误（含 `SHOP_NOT_IN_SCOPE` 403） |
| `2` | 用法错误：位置参数数量不符（`get`/`unit get`/`sauce get`/`attr-group get`/`flavor get` 缺 `<uuid>`）、未知 flag、flag 值解析失败（cobra 层，统一为 exit 2 + JSON 信封）；`--shop` 解析失败（详见 `ttpos-shared`）、`--format` 取值非法 |
| `3` | 未认证：本地无 token、上游会话过期需重新 `ttpos auth login` |

## 输出契约

同仓库其余命令一致：TTY 下人类可读（表格/原始 JSON），非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`
成功时写到 stdout；**失败**（`ok:false`）时信封改写到 **stderr**，stdout
为空，不能靠 stdout 是否为空判断成败，要看退出码。提示/诊断信息一律走
stderr。`resolved_shop` 字段与 `--shop` 解析结果的关系见 `ttpos-shared`。

## 已知局限

- `product get` 输出未建模的原始 JSON，字段需自行对照上游文档解读。
- `product category list` 无过滤 flag（`--category-uuid`/`--keyword` 只用
  于 `product list`），只能整树拉取。
- 多语言名表格列是展示取舍，不代表数据里只有一种语言——需要其他语言版本
  必须读 JSON 输出。
- `product single`/`product tax` 没有 `get` 子命令——上游本簇没有对应的
  详情端点，不是 CLI 遗漏。
- `attr-group list`/`attr-group get` 的嵌套 `attributes[].uuid` 是 JSON
  number，与顶层 `uuid`（string）类型不一致，解析时需分别处理，详见上文
  「商品细节簇」小节。
