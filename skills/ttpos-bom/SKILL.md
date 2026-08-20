---
name: ttpos-bom
description: Use this skill when the user (or an agent) needs to look up TTPOS shop product_bom (配方/BOM/成本卡) data via the `ttpos` CLI — recipe modules (配方模块), product/combo/sauce BOM configuration status filtered by `--tab` (商品/套餐/加料 BOM 配置状态，`bom product list --tab 0|1|2` 分类返回，默认单品), combo aggregate BOM (套餐 BOM 聚合), single/sauce BOM detail (`bom product get --owner-type 2|3`), the company-level order BOM singleton (订单 BOM), or a spec-product cost card (规格商品成本卡). Applies to questions like "这个配方模块包含哪些行"、"这个商品配了 BOM 吗"、"这个套餐配置了哪些单品"、"这个加料的 BOM 是什么"、"订单 BOM 长什么样"、"这个成本卡的材料清单". Do not use for BOM export/导入模板下载 (not接入，见「不接」小节) or for product list/detail itself (that is `ttpos-product`). `--shop` resolution (uuid/别名/商户名前缀、四级上下文兜底) is documented once in `ttpos-shared`, not repeated here.
---

# ttpos-bom

`ttpos bom module|product|combo|order|card` 通过本地 gateway 只读查询
TTPOS 商户的配方/BOM(物料清单)数据，共 7 个命令。全部要求先完成
`ttpos auth login`（见 README「`auth login` 三步」），未登录
直接 exit 3，不发起网络请求。顶层挂 `bom` 命令组（不挂 `product` 下——避
免 `ttpos product bom card get` 4 级嵌套）。

## 前置条件

- 默认走进程内，无需 `ttpos gateway serve`；只有连远端时才需要 `--gateway` / `TTPOS_GATEWAY_URL` / config.json 的 `gateway_url`（优先级 `--gateway` > `TTPOS_GATEWAY_URL` > `gateway_url`，全空走进程内）。
- 已登录（本地凭证里有 token）。
- 目标商户的标识——uuid、本机别名、商户名全称或前缀都可以，也可以什么都
  不传，让四级上下文兜底，完整说明见
  `skills/ttpos-shared/SKILL.md`。

## 7 个命令

```bash
ttpos bom module list --shop <标识>                    # 无分页,全量返回
ttpos bom module list --shop <标识> --keyword <关键字>
ttpos bom module get <uuid> --shop <标识>

ttpos bom product list --shop <标识>                   # 有分页,顶层 total,默认 --tab 0(单品)
ttpos bom product list --shop <标识> --keyword <关键字> --page 2 --size 20
ttpos bom product list --shop <标识> --tab 1           # 套餐
ttpos bom product list --shop <标识> --tab 2           # 加料
ttpos bom product get --owner-type 2 --owner-uuid <uuid> --shop <标识>  # 两参均必填

ttpos bom combo get <uuid> --shop <标识>

ttpos bom order get --shop <标识>                      # 无参,公司级单例

ttpos bom card get <uuid> --shop <标识>
```

5 个 `get`（module/product/combo/order/card）**均无 `--format` flag，恒定
JSON 透传**（同 `staff permission-group`/`setting get` 先例），详情结构含
多层嵌套大整数，不建模。2 个 `list`（module/product）支持 `--format
json|table`，不填按 TTY 自动判断。

## 分页三态（本域同时出现全部三种，逐端点核对，不可混用）

| 端点 | 分页 | count 来源 | 备注 |
|---|---|---|---|
| `bom module list` | **无**（上游只有 `keyword`，不内嵌 `dto.PageReq`） | `len(list)` | 全量返回，不接受 `--page`/`--size` |
| `bom product list` | **有**（上游 `Page`/`PageSize` 自有字段，不内嵌 `dto.PageReq`） | 上游 **顶层 `total`**（非 `meta.total`）；gateway 层已把顶层 total 标准化进信封 `count`，CLI 只消费 `envelope.Count` | 对外 `--page`/`--size` 翻译为 query `page_no`/`page_size`（与全仓其余分页端点一致，见「Wire 命名注意」） |
| `bom module get` / `bom product get` / `bom combo get` / `bom order get` / `bom card get`（5 个 detail） | 不适用 | **无 count**（信封不带 `count` 字段） | 单对象透传 |

冒烟实测坐实：`product list` 顶层 `total=52`（对账值，与 fixture `total ≠
len(list)` 分辨力设计一致，取数走顶层不走 `meta` 已验证正确）；`module
list` 在测试租户 <商户uuid> 上返回零数据（`count=0`），验证了
`count=len(list)` 语义，但未验证过非零 list 场景的计数正确性。

## Wire 命名注意

`bom product list` 对外 `--page`/`--size` 拼成 query `page_no`/
`page_size`（与全仓其余 12 个分页端点命名一致），**但上游
`ProductBomListReq` 自己的字段名是 `page`/`page_size`（反惯例，不内嵌
`dto.PageReq`）**——这层翻译只发生在 gateway 的 upstream 客户端
（`BomProductList` 收 `page_no`/`page_size` 语义的 int，对上游发
`"page"`/`"page_size"`），gateway 对外和 CLI 都不感知这个反惯例命名。
`bom combo get <uuid>` 同理有一处内部命名陷阱：wire 上游 query 参数名是
`combo_uuid`（不是 `uuid`），这一层翻译同样封装在 upstream 客户端里，
CLI 侧只需传位置参数 `<uuid>`，与用户交互无关，仅供排查 wire 报文时参
考。

## `bom product list --tab`：分类过滤，final-review 修复（此前静默只出单品）

`--tab` 对齐上游的 `tab` 参数（`uint8`，已逐字核实上游注释：**`0`-单品
`1`-套餐 `2`-加料**）。字段无 `binding` 标签也无显式 default，零值 `0` 与不传对
上游语义等价，故 CLI/gateway/upstream 三层均只在 `tab>0` 时才拼 query，
默认（不传 `--tab`）行为不变。**final-review 修复前**：CLI/gateway 均
未透传 `tab`，任何 `bom product list` 调用（不管用户想查什么）都会静默
命中上游 `Tab` 零值默认分支，只返回单品结果——查加料/套餐的调用方拿到
的是"合法但完全无关"的空/单品数据，不报错也无提示，是本域最高优先级
的 final-review 修复项。要查询套餐/加料，必须显式传 `--tab 1`/`--tab
2`；要查具体某条记录的行级 BOM，用 `bom product get`（单品/加料）或
`bom combo get`（套餐聚合）。

## bool 字段：本域已枚举的 9 处全是原生 Go bool（**仅限本域，不外推**）

`RecipeModule.HasNested`/`IsEditable`、`RecipeLine.Headquarter`、
`ProductBomListItem.Configured`/`Headquarter`、
`ProductBomDetail.Headquarter`、`ComboBomItem.Configured`、
`ComboBomDetail.AllConfigured`、`ProductBomCardDetailResp.IsEditable`——
以上是本域 **7 个**响应结构体（`RecipeModule`/`RecipeLine`/
`ProductBomListItem`/`ProductBomDetail`/`ComboBomItem`/`ComboBomDetail`/
`ProductBomCardDetailResp`）涉及的**全部** 9 处布尔语义字段（逐字段核对
过上游契约），JSON 序列化均为原生 `true`/`false`，未发现 `int` 0/1
或 `string` "0"/"1" 形态。

**这个结论只覆盖上述枚举过的 9 处，不能外推到其他域**——
仓库内 `setting` 域已证明同仓库不同域存在三种布尔形态混用（见
`skills/ttpos-setting/SKILL.md`「布尔字段三态」），`staff` 域
`is_super`/`is_disable` 是 int 且非 truthy。消费本域以外的字段前必须逐
字段重新确认类型，不能套用本域结论。

## `bom order get`：owner_type/owner_uuid 恒零值，不可当数据消费

`bom order get` 无参、公司级单例（一个商户只有一张"订单 BOM"）。响应体
复用与 `bom product get` 相同的 `ProductBomDetail` 结构，含
`owner_type`/`owner_uuid` 字段，但**服务层（`GetOrderBomDetail`）从未给
这两个字段赋值**——它们在这条路径下恒为零值（`0`），不代表任何业务语
义。**冒烟实测坐实**：测试租户 <商户uuid> 上 `owner_type=0`、
`owner_uuid=0`，与上游契约一致（该端点只填充
`shared_lines`/`dine_in_lines`/`takeaway_lines`/
`LeafPreview`）完全一致。调用方（含 agent）**不要**把这两个字段当作真
实 owner 定位信息使用；真正有效的数据在
`shared_lines`/`dine_in_lines`/`takeaway_lines`/`leaf_preview` 四个数组
字段里。

## `bom card get`：三层嵌套 uuid 数组保持 JSON number，顶层不递归字符串化

`card/detail` 响应 `Materials[]` 数组每项含三层嵌套大整数：
`Materials[].Material.Uuid`（材料 uuid）、`Materials[].Unit.Uuid`/
`FromUnitUuid`（成本单位）、`Materials[].UnitList[].Uuid`/`FromUnitUuid`
（单位列表，数组套数组）。这些嵌套字段**全部保持原始 JSON number**，
不做大整数字符串化——`bom card get`（同其余 4 个 detail）走
`json.RawMessage` 原样透传，gateway 的 `stringifyBigInts` 机制只处理
**顶层 list item** 字段（本域仅 `module list`/`product list` 两个
list 端点的顶层 uuid 会被字符串化），detail 类响应不经过这层处理，与
`product attr-group get` 的嵌套 `attributes[].uuid` 既有 ruling 一致。
JSON/JS 消费方解析这些嵌套 uuid 前需自行处理精度（当前量级未验证是否
超过 `2^53`，按大整数场景保守处理）。

## `card/template` vs `card/template/download`：命名相近、形态相反，均未接入

本域上游共 10 个 `GET` 端点，本 CLI 只接了其中 7 个只读端点，另外 3 个
不接：

| 端点 | 形态 | 为什么不接 |
|---|---|---|
| `/product_bom/card/export` | **异步任务触发**（需鉴权），响应 `data=nil`，真正文件由独立 worker 生成 | 需"触发→轮询导出记录→下载"三步且触发会写入导出记录，越出只读边界，同 `product/package/composition/export` 先例 |
| `/product_bom/card/template` | **异步任务触发**（需鉴权），响应同样 `data=nil` | 同上——**名字上看起来像"拿模板"，实际和 `card/export` 是同一种异步任务模式**，这是本条目要特别提醒的命名陷阱：不要因为叫 `template` 就以为是文件下载 |
| `/product_bom/card/template/download` | **同步文件流**，直接返回 `.xlsx` 二进制（`Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` + `Content-Disposition: attachment`），且是本域 10 个端点中**唯一公开免鉴权**的一个（`publicApi` 分组，无 `middleware.Auth`） | CLI 目前所有命令走统一的 JSON 信封输出契约，没有二进制文件下载形态（需要 `--output` 落盘 + 二进制透传，是独立设计，当前信封模型不支持）；且该端点免鉴权，经 gateway 代理反而绕不开鉴权收益，无接入增益 |

即：`card/template`（异步、需鉴权、返回空）与 `card/template/download`
（同步、免鉴权、返回文件）是**两个名字相近但完全不同**的端点——前者
容易被误当作"下载模板"的入口，实际它只是创建了一条导出任务记录，真正
的文件流在后一个端点。均未接入本 CLI。

## 安全观察：`card/template/download` 免鉴权但不含租户数据（已核实，属预期设计）

`card/template/download` 虽然公开免鉴权，但**核实结论是它不含租户数
据**：已核实其模板构造过程**不接收任何租户上下文**（无
`company_uuid`、无数据库句柄），内部
只调用 `renderBomChannelWorkbook(f, nil, nil, nil, nil, nil,
bomScopeFromParam(scope), lang)`（5 个数据入参全传 `nil`），不访问
`s.dbm`（`ImportService.dbm` 字段在本方法体内完全未被引用），仅按
`scope` 渲染空表头 + 渠道下拉列表。函数与路由注册处的注释「模板无公司
数据，与代码列契约始终一致」「内存即时生成、流式返回，不入队/不上传
谷歌桶/不轮询」与代码实际行为一致。**结论：公开模板不含租户数据，属预
期设计，不构成越权泄露**。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 一般错误：上游/gateway 业务错误（含 `SHOP_NOT_IN_SCOPE` 403，**冒烟已验证** exit 1） |
| `2` | 用法错误：位置参数数量不符（`module get`/`combo get`/`card get` 缺 `<uuid>`）、未知 flag、flag 值解析失败（cobra 层，统一为 exit 2 + JSON 信封）；`bom product get` **缺 `--owner-type` 或 `--owner-uuid`**（两参均必填，**冒烟已验证**缺参 exit 2）、`--shop` 解析失败、`--format` 取值非法 |
| `3` | 未认证：本地无 token、上游会话过期需重新 `ttpos auth login`；**未登录 + `bom product get` 缺两参同时命中时，exit 3（AUTH）优先于 exit 2（USAGE）**——两参校验放在 `AfterAuth` 钩子（`LoadToken` 成功之后），与 `staff search` 同形态，**冒烟已验证**这条叠加顺序。注意这条"AUTH 优先"只对 `AfterAuth` 钩子里的域校验成立；`module/combo/card get` 缺位置参数走 cobra 层，在 `LoadToken` 之前就拦下，"未登录 + 缺位置参数"反而是 exit 2（两级校验顺序见 `ttpos-shared`/README「退出码」） |

## 输出契约

同仓库其余命令一致：非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`
成功时写到 stdout；**失败**（`ok:false`）时信封改写到 **stderr**，stdout
为空，不能靠 stdout 是否为空判断成败，要看退出码。提示/诊断信息一律走
stderr。`resolved_shop` 字段与 `--shop` 解析结果的关系见 `ttpos-shared`。2 个 `list` 命令 TTY 下有表格：
`module list` 列 `uuid|名称|主行数`（"主行数" = `material_count+module_count`，
即本模块主行物料数+主行模块引用数，**摘录无字面字段叫"主行数"，是基于字
段语义的推断**——已排除 `ref_count`（"被引用数(去重上层)"，回答的是
"多少上层结构引用本模块"而非"本模块自身有多少行"）与
`alternative_count`（备选行，是主行的替代选项，非独立顶层行）两个候
选，但因测试租户零数据未能冒烟证实此列语义，需后续有数据时复核；名称
列走 `locale_name`+既有 `localeName` helper 解析，不是 `name`——`name`
是未解析的 locale JSON 原文冗余字段，见「多语言字段」注记）；
`product list` 列 `owner_uuid|名称(locale)|配置状态`，支持 `--tab
0|1|2` 按分类过滤（0-单品(默认)/1-套餐/2-加料，逐字照上游
`ProductBomListReq.Tab` 字段注释，见下方「Wire 命名注意」）。

## 已知局限

- **`module list`"主行数"列语义未经真实数据冒烟证实**：测试租户
  <商户uuid> 上该端点零数据，`material_count+module_count` 的取
  法是基于摘录字段语义的推断（详见上文表格与「输出契约」段），非摘录
  字面字段，后续接入有数据的商户时需人工复核一次。
- **不接 3 个端点**：`card/export`/`card/template`（异步任务触发，需鉴
  权）、`card/template/download`（同步文件流，免鉴权，CLI 无文件下载
  形态），详见上文「`card/template` vs `card/template/download`」小节
  。
- **`--owner-type` 未做取值枚举校验**：`bom product get` 只校验
  `--owner-type`/`--owner-uuid` 非空必填（两参均必填），不校验
  `--owner-type` 是否落在合法枚举 `2`(商品规格)/`3`(加料)/`4`(套餐组
  项)内，非法值会原样转发给上游由其返回业务错误（exit 1），不是 CLI
  层的用法错误（exit 2）。
- **`combo get`/`card get` 均为透传不建模**：`combo get` 的
  `Items[]` 数组内每项含两个不同语义的大整数（`product_uuid`/
  `owner_uuid`），`card get` 三层嵌套 uuid 详见上文专门小节，字段含义
  需自行对照上游契约。
- `--shop` 的完整解析规则见 `skills/ttpos-shared/SKILL.md`，
  不在本文档重复。
