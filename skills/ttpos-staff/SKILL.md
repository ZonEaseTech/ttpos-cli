---
name: ttpos-staff
description: Use this skill when the user (or an agent) needs to look up TTPOS shop staff accounts, roles or permission trees via the `ttpos` CLI — list a shop's staff (with optional keyword filter), fetch a single staff account's full detail by uuid, search a single staff by email/phone, list/get roles, or dump the full permission tree. Applies to questions like "这个门店有哪些员工"、"谁是超管"、"这个员工账号详情"、"这个邮箱对应哪个员工"、"这个商户有哪些角色"、"这个角色有哪些权限". Do not use for orders, products, desks, or member accounts — those are separate skills/out of scope. `--shop` resolution (uuid/别名/商户名前缀、四级上下文兜底) is documented once in `ttpos-shared`, not repeated here — load that skill alongside this one if the question involves how `--shop` is identified rather than what staff/role filters do.
---

# ttpos-staff

`ttpos staff list` / `ttpos staff get` / `ttpos staff search` /
`ttpos staff role list` / `ttpos staff role get` /
`ttpos staff permission-group` 通过本地 gateway 查询 TTPOS 商户的员工账
号、角色与权限树。全部要求先完成 `ttpos auth login`（见
README「`auth login` 三步」），未登录直接 exit 3，不发起网
络请求。

## 前置条件

- gateway 已启动且可达（`TTPOS_GATEWAY_URL` 环境变量或 `--gateway` flag）。
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

## `ttpos staff search`

```bash
ttpos staff search --shop <商户uuid> --field email --keyword dev
ttpos staff search --shop <商户uuid> --field phone --keyword 138xxxx
```

按 email 或 phone 搜索单个员工，返回**单对象，不是列表**（区别于
`staff list`）。

| flag | 必填 | 说明 |
|---|---|---|
| `--shop` | 否 | 同上，解析规则见 `ttpos-shared` |
| `--field` | 是 | 仅支持 `email`\|`phone`，其它取值客户端直接判定用法错误（exit 2，不发起网络请求） |
| `--keyword` | 是 | 搜索关键字；`--field`/`--keyword` 任一缺省同样 exit 2 |
| `--format` | 否 | `json`\|`table` |

- **`--keyword` 是精确匹配，不是模糊/前缀匹配**：端到端冒烟实测，
  `--keyword` 必须是**完整**邮箱或手机号才能命中（如 `dev` 这种部分词不
  会命中完整邮箱 `dev@xxx.com` 对应的员工），不要按"包含匹配"预期传参。
- **原样透传**：`data` 是上游返回的原始 JSON，实测形状为
  `{uuid,email,phone,real_name,company_list}`，`--format table` 下也直接
  打印这段 JSON，不额外渲染表格。
- **`uuid` 是 JSON number，不是字符串**（修正：此前文档误
  记为字符串）——上游 `SearchStaffResp.Uuid` 是 `uint64`，本命令对应的 gateway handler
  （`handleStaffSearch`）只做原样透传、不经 `stringifyBigInts` 字符串化，
  wire 上就是标准 gin JSON 编码的数值。冒烟实测完整邮箱命中示例：
  `uuid` 为数字 `8786685202432000`（无引号）。**>2^53（JS/float64 安全整
  数上限）的 uuid 在 JS/浏览器等消费方会有精度损失**，这是该字段未字符
  串化的已知局限，需要精确值的消费方应改走上游/其它已字符串化的接口。
- **无匹配时不是错误，是 `uuid=0` 的空对象**：端到端冒烟实测，关键字未
  命中任何员工时，上游/gateway/CLI 全链路都不报错（exit 0），`data` 是
  一个 `uuid` 为数字 `0`、其余字段为空值的对象——上游 DTO 注释原文是
  "员工UUID，大于0表示找到员工"，调用方/agent 必须显式检查 `uuid == 0`（数字比较，不是字符
  串 `"0"`）来判断"未命中"，不能只凭 exit code 或"是否报错"判断。
- **`company_list` 结构按 DTO 补全**（M2）：上游
  `SearchStaffCompanyInfo` 定义为
  `{company_uuid uint64, company_name string, roles []{uuid uint64, name string}, is_super int}`
  ——同 `uuid` 字段，`company_uuid`/`roles[].uuid` 也是原生 JSON number，
  未经字符串化，同样有 >2^53 精度风险；该结构来自 DTO 源码，未经真实数
  据核实每个字段在生产环境的实际取值。

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
| `2` | 用法错误：位置参数数量不符（`staff get`/`role get` 缺 `<uuid>`）、未知 flag、flag 值解析失败（cobra 层，统一为 exit 2 + JSON 信封）；`--shop` 解析失败（详见 `ttpos-shared`）、`--format` 取值非法、`staff search` 的 `--field`/`--keyword` 缺省或 `--field` 非 `email`/`phone` |
| `3` | 未认证：本地无 token、上游会话过期需重新 `ttpos auth login`；**未登录 + `staff search` 的 `--field`/`--keyword` 域参数非法同时命中时是 exit 3（AUTH 优先）**——该校验放在 `AfterAuth` 钩子（`LoadToken` 成功之后）。`get`/`role get` 缺位置参数走 cobra 层，在 `LoadToken` 之前拦下，未登录 + 缺位置参数是 exit 2，不是 3 |

## 输出契约

同仓库其余命令一致：TTY 下人类可读（表格/原始 JSON），非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`
成功时写到 stdout；**失败**（`ok:false`）时信封改写到 **stderr**，stdout
为空，不能靠 stdout 是否为空判断成败，要看退出码。提示/诊断信息一律走
stderr。`resolved_shop` 字段与 `--shop` 解析结果的关系见 `ttpos-shared`。

## 已知局限

- `staff get`/`staff search`/`staff role get`/`staff permission-group`
  输出均为未建模的原始 JSON，字段需自行对照上游文档解读。
- `is_super`/`is_disable` 是原生 0/1 整数字段，agent/脚本消费 JSON 时若按
  bool 反序列化会出错或吞掉数据，必须按 `== 1` 判断。
- `staff search` 返回的 `company_list` 结构按上游
  DTO 定义补全（见「`ttpos staff search`」一节），未经真实数据逐字段核实。
- `staff search` 的 `uuid`（及 `company_list[].company_uuid`/`roles[].uuid`）
  是原生 JSON number，未经 gateway 字符串化，`>2^53` 的值在 JS 消费方有
  精度损失风险（修正：此前误记为字符串）。
- `staff search` 的 `--keyword` 是精确匹配（须完整邮箱/手机号，部分词不
  命中），且无匹配时返回 `uuid=0`（数字）的空对象而非错误——调用方需自
  行判空（`uuid == 0`，数字比较），不能凭 exit code 判断是否命中。
- `staff/supervisor_candidates` 未接入：该端点要求调用方 `company_uuid`
  归属总部（上游注释原文"仅总部 company 调用方有权访问"），测试租户是
  独立商户，无法真实验证。
- 只覆盖员工账号本身的基础信息、角色列表与权限树，不含登录日志等周边
  数据（`staff_operation_log` 未接入）。
