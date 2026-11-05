---
name: ttpos-staff
description: Use this skill when the user (or an agent) needs to look up TTPOS shop staff accounts, roles or permission trees via the `ttpos` CLI — list a shop's staff (with optional keyword filter), fetch a single staff account's full detail by uuid, list/get roles, or dump the full permission tree. Applies to questions like "这个门店有哪些员工"、"谁是超管"、"这个员工账号详情"、"这个商户有哪些角色"、"这个角色有哪些权限". Searching staff by email/phone is not available in this version. Do not use for orders, products, desks, or member accounts — those are separate skills/out of scope. `--shop` resolution (uuid/别名/商户名前缀、四级上下文兜底) is documented once in `ttpos-shared`, not repeated here — load that skill alongside this one if the question involves how `--shop` is identified rather than what staff/role filters do.
---
> **v1 未提供** `staff search`（按邮箱/手机号查人）：上游会跨商户返回身份信息，本版本不提供该命令。不要尝试调用；需要时请人工在商户后台查看。


# ttpos-staff

`ttpos staff list` / `ttpos staff get` /
`ttpos staff role list` / `ttpos staff role get` /
`ttpos staff permission-group` 通过本地 gateway 查询 TTPOS 商户的员工账
号、角色与权限树。全部要求先完成 `ttpos auth login`（见
README「`auth login` 三步」），未登录直接 exit 3，不发起网
络请求。

## 前置条件

- 默认走进程内，无需 `ttpos gateway serve`；只有连远端时才需要 `--gateway` / `TTPOS_GATEWAY_URL` / config.json 的 `gateway_url`（优先级 `--gateway` > `TTPOS_GATEWAY_URL` > `gateway_url`，全空走进程内）。
- 已登录（本地凭证里有 token）。
- 目标商户的标识——uuid、本机别名、商户名全称或前缀都可以，也可以什么都
  不传，让四级上下文兜底。**这条解析规则是全部三域命令共用的**，完整说明
  见 `skills/ttpos-shared/SKILL.md`，本文档只讲 `staff` 命令特有
  的 flag。

## `ttpos staff list`

```bash
ttpos staff list --shop <company_uuid|别名|商户名前缀>
ttpos staff list                                        # --shop 省略，走四级上下文兜底
ttpos staff list --shop <标识> --keyword <用户名/姓名/手机关键字>
ttpos staff list --shop <标识> --page 2 --size 50
ttpos staff list --shop <标识> --format json             # 强制 JSON，即使在 TTY 下
```

| flag | 必填 | 说明 |
|---|---|---|
| `--shop` | 否 | 商户标识，解析规则见 `ttpos-shared`；缺省依次尝试 `TTPOS_SHOP` 环境变量、`ttpos shop use` 设置的默认商户，四级全空 exit 2 |
| `--keyword` | 否 | 按用户名/姓名/手机过滤，直接透传给上游 |
| `--page` / `--size` | 否 | 不填由 gateway 兜底 |
| `--format` | 否 | `json` \| `table`，不填按 TTY 自动判断 |
| `--gateway` | 否 | 覆盖 gateway 地址 |

**权限范围**：`--shop` 解析出的 uuid 若不在当前登录账号可访问的商户列表
内，gateway 返回 `403` + `SHOP_NOT_IN_SCOPE`（exit 1）。

**`is_super` 是 0/1 整数，不是 bool**：`is_super`/`is_disable` 是上游原生
数值字段（不属于 gateway 的大整数字符串化范围），wire 上就是 JSON number
`0`/`1`。TTY 表格的「超管」「禁用」两列用 `== 1` 判断显示「是/否」，`1` 显
示「是」，其余（含非法/意外值）一律显示「否」——**不是 truthy 语义**，非
`0`/`1` 的脏数据不会被误判成超管。非 TTY / `--format json` 时，
`data.list[]` 里每个员工对象的 `is_super`/`is_disable` 原样是数字，不是
`true`/`false`，agent 消费时同样要按 `== 1` 判断，不要当 bool 直接用。

**TTY 表格列**：UUID | 用户名 | 姓名 | 手机 | 超管 | 禁用。`uuid` 已做大整
数保精度处理（字符串），JSON 输出里同样是字符串，不要按 number 解析。

## `ttpos staff get`

```bash
ttpos staff get 3745748940230657 --shop <商户uuid>
ttpos staff get 3745748940230657 --shop <商户uuid> --format json
```

- 位置参数 `<uuid>` 必填，来自 `staff list` 输出。
- `--shop` 同 `staff list`，范围外同样 403 + `SHOP_NOT_IN_SCOPE`。
- **详情原样透传**：`data` 是上游员工详情的原始 JSON，gateway 和 CLI 都不
  做字段裁剪、重命名或数值中转，`--format table` 下也是直接打印这段原始
  JSON，不额外渲染表格。未建模的裸 JSON（含 `is_super` 等字段的原始取
  值），字段含义需结合上游员工详情接口文档自行解读。

## `ttpos staff role list`

```bash
ttpos staff role list --shop <商户uuid>
ttpos staff role list --shop <商户uuid> --page 1 --size 5
ttpos staff role list --shop <商户uuid> --format json
```

列出商户角色。**有分页**（同 `staff list`/`order list` 范式），不填
`--page`/`--size` 由 gateway 兜底。

- **TTY 表格列**：UUID | 名称 | 创建时间。`uuid` 经 `stringifyBigInts` 字
  符串化（口径同全局 uuid），`create_time` 是 unix 秒转本地时间展示。
- 非 TTY / `--format json` 时，`data.list[]` 每项含 `uuid`（字符串）/
  `name`/`create_time`，信封 `count` 取上游 `meta.total`。

## `ttpos staff role get`

```bash
ttpos staff role get <uuid> --shop <商户uuid>
```

- 位置参数 `<uuid>` 必填，来自 `staff role list` 输出。
- **原样透传**：实测 keys 为
  `uuid,access_uuids,name,staff_count,staff_uuids,selected_leaf_count,total_leaf_count`。
  `staff_uuids`/`access_uuids` 是数值**数组**，元素可能是超出 JS 安全整数
  范围的大整数——gateway 的字符串化机制只处理对象字段，不处理数组元素，
  所以本命令走整段 `json.RawMessage` 透传保精度，不做任何字段建模或裁剪。

## `ttpos staff permission-group`

```bash
ttpos staff permission-group --shop <商户uuid>
```

输出完整权限树，**仅 JSON 输出，无 `--format`/表格模式**（树形数据表格
无意义）。实测节点结构 `{id,uuid,name,path,parent_id,is_route,is_menu,
is_show,children:[...]}` 递归嵌套，`uuid` 为大整数（实测样本
`2856266502144000`），整段 `json.RawMessage` 透传保精度。数据量较大，建
议配合 `jq` 消费。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 一般错误：上游/gateway 业务错误（含 `SHOP_NOT_IN_SCOPE` 403） |
| `2` | 用法错误：位置参数数量不符（`staff get`/`role get` 缺 `<uuid>`）、未知 flag、flag 值解析失败（cobra 层，统一为 exit 2 + JSON 信封）；`--shop` 解析失败（详见 `ttpos-shared`）、`--format` 取值非法 |
| `3` | 未认证：本地无 token、上游会话过期需重新 `ttpos auth login`。`get`/`role get` 缺位置参数走 cobra 层，在 `LoadToken` 之前拦下，未登录 + 缺位置参数是 exit 2，不是 3 |

## 输出契约

同仓库其余命令一致：TTY 下人类可读（表格/原始 JSON），非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`
成功时写到 stdout；**失败**（`ok:false`）时信封改写到 **stderr**，stdout
为空，不能靠 stdout 是否为空判断成败，要看退出码。提示/诊断信息一律走
stderr。`resolved_shop` 字段与 `--shop` 解析结果的关系见 `ttpos-shared`。

## 已知局限

- `staff get`/`staff role get`/`staff permission-group`
  输出均为未建模的原始 JSON，字段需自行对照上游文档解读。
- `is_super`/`is_disable` 是原生 0/1 整数字段，agent/脚本消费 JSON 时若按
  bool 反序列化会出错或吞掉数据，必须按 `== 1` 判断。
- `staff/supervisor_candidates` 未接入：该端点要求调用方 `company_uuid`
  归属总部（上游注释原文"仅总部 company 调用方有权访问"），测试租户是
  独立商户，无法真实验证。
- 只覆盖员工账号本身的基础信息、角色列表与权限树，不含登录日志等周边
  数据（`staff_operation_log` 未接入）。
