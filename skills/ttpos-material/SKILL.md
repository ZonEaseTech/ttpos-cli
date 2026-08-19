---
name: ttpos-material
description: Use this skill when the user (or an agent) needs to look up TTPOS shop material (物品/库存) data via the `ttpos` CLI — materials with stock (物品含库存)、material categories (物品分类)、material types (物品类型)、material units (物品单位换算)、material category visibility configs (物品分类可见性配置，含子店角色列表). Applies to questions like "这个物品还有多少库存"、"这个分类下有多少物品"、"总部设置了哪些可见性规则"、"物品单位换算率是多少". **本域只读查询，不含新增/编辑/删除物品、分类、类型、单位、可见性配置、批量导入等写操作**——上游还有 20 个写端点，一律不接，需用户明确授权后才会规划，不要用本 CLI 尝试执行这些操作。Do not use for purchase/bom/product domains (different domains, not接入 by this skill; product_bom/recipe 端点属 bom 域已接). `--shop` resolution (uuid/别名/商户名前缀、四级上下文兜底) is documented once in `ttpos-shared`, not repeated here.
---

# ttpos-material

`ttpos material list|get|stock|category|type|unit|visibility`
通过本地 gateway 只读查询 TTPOS 商户的物品/库存数据，共 11 个命令。全部
要求先完成 `ttpos auth login`（见 README「`auth login`
三步」），未登录直接 exit 3，不发起网络请求。

**本域只读查询，不含新增/编辑/删除物品、分类、类型、单位、可见性配
置、批量导入等写操作**——上游本域另有 **20 个** `POST`/`DELETE` 写端
点，按只读默认政策一律不接，需用户明确授权后才会规划，见下文「本域只
读」。

## 前置条件

- gateway 已启动且可达（`TTPOS_GATEWAY_URL` 环境变量或 `--gateway` flag）。
- 已登录（本地凭证里有 token）。
- 全域 grep `ctx.Version(` 零命中——**无版本分叉**，不像 `purchase` 域
  受 `MinVersionCheck` 门槛限制，不需要关心 `Client-Version` 头。
- 目标商户的标识——uuid、本机别名、商户名全称或前缀都可以，也可以什么都
  不传，让四级上下文兜底，完整说明见
  `skills/ttpos-shared/SKILL.md`。

## 11 个命令

| 命令 | 关键 flag | 用途 |
|---|---|---|
| `material list` | `--keyword` `--status` `--category-uuids`(多值可重复) `--material-uuids`(多值可重复) `--warehouse-erp-code` `--purchase-type` `--supplier-erp-code` `--out-warehouse-erp-code` `--scene` `--page`/`--size` | 列出物品(含库存)，分页壳 |
| `material get <uuid>` | — | 物品详情(无表格，仅 JSON) |
| `material stock <uuid>` | — | 物品库存详情(无表格，仅 JSON) |
| `material category list` | — | 列出物品分类(无分页,全量返回) |
| `material category get <uuid>` | — | 物品分类详情(无表格，仅 JSON) |
| `material type list` | — | 列出物品类型(无分页,全量返回) |
| `material type get <uuid>` | `--page`/`--size` `--keyword` | 物品类型详情(**第五形态混合结构，无表格，仅 JSON**) |
| `material unit list` | `--uuid` | 列出物品单位(无分页,全量返回；**`--uuid` 传/不传语义不同**，见下) |
| `material visibility list` | — | 列出物品分类可见性配置(无分页,全量返回；⚠️ 权限缺口，见下) |
| `material visibility get <uuid>` | — | 物品分类可见性配置详情(无表格，仅 JSON；同上权限缺口) |
| `material visibility sub-shop-roles` | — | 子店角色列表(**仅总部商户可用**，无表格，仅 JSON) |

6 个 `get`/`stock`/`sub-shop-roles`（`material get`、`material stock`、
`material category get`、`material type get`、`material visibility
get`、`material visibility sub-shop-roles`）**均无 `--format` flag，恒
定 JSON 透传**（同 `staff permission-group`/`purchase order get` 先
例），不暴露死参数。`material list`/`material category list`/
`material type list`/`material unit list`/`material visibility list`
共 5 个 list 支持 `--format json|table`，不填按 TTY 自动判断。

## 响应五形态逐端点(count 语义,不可统一假设)

| 端点 | 命令 | 形状 | count 来源 |
|---|---|---|---|
| `material/list` | `list` | 分页壳 `{list, meta:{total}}` | `meta.total`——⚠️ **过滤前的数，见下「隐式过滤」** |
| `material/detail` | `get` | 单对象无壳，RawMessage 透传 | 无 count |
| `material/stock/detail` | `stock` | 单对象无壳，RawMessage 透传 | 无 count |
| `material/category/list` | `category list` | `{list}` 无 total | `len(list)` |
| `material/category/detail` | `category get` | 单对象无壳，RawMessage 透传 | 无 count |
| `material/type/list` | `type list` | `{list}` 无 total | `len(list)`；⚠️ 该 GET 触发写库，见下 |
| `material/type/detail` | `type get` | **第五形态：`{type,list,total}` 混合**——detail 却带分页 list | **顶层 `total`**(不是 `len(list)`) |
| `material/unit/list` | `unit list` | `{list}` 无 total | `len(list)` |
| `material_category_visibility/list` | `visibility list` | `{list}` 无 total | `len(list)`；⚠️ 权限缺口，见下 |
| `material_category_visibility/detail` | `visibility get` | 单对象无壳，RawMessage 透传 | 无 count；⚠️ 权限缺口，见下 |
| `material_category_visibility/sub_shop_roles` | `visibility sub-shop-roles` | **`{shops}`——键名是 `shops`，不是 `list`/`items`** | `len(shops)` |

即本域同时出现**分页壳 / 单对象无壳 / 无 total 的 `{list}` / 第五形
态 `{type,list,total}` 混合 / 裸数组键名 `shops`**共五种形状，消费方不
能默认套用"count 一定在 `meta.total`"或"数组一定叫 `list`"的假设，需
逐端点核对上表（`material_category_visibility/sub_shop_roles` 是本域
唯一非 `list`/`items` 键名的裸数组端点）。

## 布尔三形态表(逐字段区分,禁止统一化)

本域（material 只读部分）实测坐实**三种**布尔形态，分布在不同字段，
不是同一字段的不同版本：

| 形态 | 字段 |
|---|---|
| Go bool | `Material.{Headquarter,AllowNegativeStock,IsSafetyStockEditable,IsNegativeStockEditable}`、`MaterialDetailResp.{AllowNegativeStock,IsEditable,IsNegativeStockEditable,HasBatchNo}`、`MaterialCategory.{IsRelated,IsEditable}`、`MaterialType.{IsSystem,Reserved,IsEditable,FromHeadquarter}` |
| int 0/1(非 Go bool) | `Material.{Status,AllowSubstoreVisible}`、`MaterialDetailResp.{Status,AllowSubstoreVisible}`、`VisibilityListItem.IsAllRoles`、`VisibilityDetailResp.IsAllRoles` |
| **string "yes"/"no"**(既非 bool 也非 "0"/"1") | 仅 `MaterialQuotaConfig.IsAllowPurchase`(嵌在 `Material.quota_config.is_allow_purchase`)，值域是字符串 `"yes"`/`"no"`(或空字符串 `""` 初始态) |

**本域未发现 "0"/"1" 字符串形态的布尔字段**——与 `purchase` 域的发现
不同（`purchase` 域也无此形态，但 `setting` 域另证明同仓库不同域存在
这种混用），**不得从其它域类推**。上表全称命题（"本域只有这三种形
态"）已逐字段核对过，仅覆盖本域已枚举的字段，不外推到未接入的写端点
字段。

## ⚠️ 隐式过滤四项(本域最重要的用户可见风险)

1. **`material/list` 无条件叠加可见性过滤**：按当前登录员工的角色匹配
   `material_category_visibility` 配置表，与请求参数无关；命中时**在
   内存里**对**已分页**取出的数据做跳过处理，不可见分类的物品不会出现
   在结果里。
2. **`material/list` 限购引擎的隐藏过滤**：当 `--purchase-type 2` 且
   限购引擎命中时，不在允许集合内的物品同样在内存里被跳过。**`--scene
   extra_receipt`（额外收货）会跳过这条限购过滤**（已逐字核实上游字段
   注释），即关掉本条过滤的开关；调用方需要看到被
   限购隐藏的物品时可用它绕过，但这也意味着结果集会包含正常查询看不
   到的物品，使用前需确认场景语义。
3. **`material/type/detail` 的"未分类"归并**：查询系统保留的"未分类"
   类型时，物料列表与计数会自动并入 `type_uuid=0` 的历史物料——按
   `uuid` 精确过滤的调用方会漏算这部分。
4. **`material_category_visibility/list` 与 `/detail` 的实际可见范围
   与文档不符**：接口文档写"仅总店可用"，实际任意已认证员工（不论总店
   /子店）均可拉到完整可见性配置列表/详情。见下文专门小节。

**1+2 的后果(必须显著记录)**：`material list` 响应体的 `meta.total`
是**过滤前**的总数（在服务端 DB 层 `COUNT` 时计算，早于上述两项内存
过滤），**实际返回条数可能更少，翻页时每页条数也可能不等**。**不要用
`total` 判断数据完整性，更不能用它做客户端分页总数计算**。测试租户物
品数据为空，尚未验证非空场景下 `total` 与实际返回条数的差异幅度，
接入有数据的商户时需人工复核一次。

## ⚠️ 副作用(GET 却写库/外呼——"本域只读"不作绝对承诺)

1. **`material list` 与 `material type list` 无条件触发
   `EnsureSystemMaterialTypes`**：条件满足时（该店内置类型种子表为空）
   会 `INSERT` 4 条内置类型种子记录。**即一个 GET 请求在特定条件下会写
   库**——幂等写入（INSERT-IF-MISSING），非本 CLI 引入的副作用，是上游既
   定行为，CLI 层如实透传、不拦截。失败被上游吞掉，不阻断列表返回。
2. **`material get` 外呼 BMP `ListBatches`**：满足「公司已开 ERP +
   物品编码非空」时会发起一次 BMP gRPC 读接口调用查批次信息，失败降级
   为 `has_batch_no=false`，只读不写库，但引入外部依赖延迟/失败面。
3. **`material visibility sub-shop-roles` 跨库并发读**：对 saas 主库
   查子店列表后，对每个子店库并发查角色表，延迟随子店数量增长；单个子
   店查询失败仅记日志跳过，不中止整体请求，返回结果可能不含全部子店。

照 `purchase` 域的写法："本域只读"不作绝对承诺——遇到审计要求
"GET 一定零副作用"的场景需额外注意上述三处。

## `material unit list` 的 `--uuid` 传/不传语义不同

不传（等价于 `uuid=0`）走"查全部单位"分支，`conversion_rate` **恒为硬
编码 1**，不是真实换算率；传入具体物品 `uuid`（`uuid≠0`）走"查该物品
真实单位换算表"分支，`conversion_rate` 才是真实值。两条路径复用同一
响应结构（`MaterialUnit`），字段名完全一样，仅数值含义不同——不能假设
`conversion_rate` 总是真实换算率——不传 `--uuid` 时它是占位值。

## `material visibility sub-shop-roles` 仅总部可用

实测普通商户调用会得到上游业务错误
`-2 Only the head office can query sub-store role`（非 HTTP 403，是
service 层业务错误，走既有 `CodeUpstreamError`/BadGateway 路径），CLI
层不做特殊拦截，原样走既有 upstream 错误码映射（exit1）。这是本域三
个 `visibility` 端点里**唯一正确实现"仅总店"权限判断**的一个——对比
`visibility list`/`visibility get` 的权限缺口（见上「隐式过滤 4」）。

## ⚠️ `visibility list`/`visibility get` 的实际可见范围与文档不符

上游接口文档把这两个端点标为"仅总店可用"，**但实际行为不是**：任何已
认证员工（不论总店还是子店）都能读到完整的可见性配置列表与详情，也就
是"哪些角色能看哪些物品分类"这类本应总店专属的配置。同域的
`sub-shop-roles` 才是唯一真正做了总店判断的端点（越权调用会得到
`-2 Only the head office can query sub-store role`）。

**对调用方的影响**：不要依据"这个接口只有总店能调"来推断调用方身份，
也不要把它的返回值当作"当前账号是总店"的证据——两者都不成立。子店账号
拿到的数据与总店一致。

**ttpos-cli 的处置**：如实透传，不在 CLI 侧做补偿性拦截——数据已经从上
游下发，CLI 单独遮蔽只是装饰性修复，反而会让调用方误以为拿到的是受控
数据。

## 嵌套大整数不字符串化(全域既有口径)

`stringifyBigInts` 系列只处理**顶层**字段，不递归嵌套结构。本域受影
响的嵌套大整数字段（JS/TS 消费方仍需按 number 处理，`>2^53` 的值有精
度损失风险）：

- `Material.UnitList[].{Uuid,FromUnitUuid}`（嵌在 `material list` 每行
  物品的单位列表里）
- `MaterialQuotaConfig.QuotaUnitUuid`（嵌在 `material list` 每行物品的
  `quota_config` 里）
- `MaterialDetailResp.UnitList.List[].{Uuid,FromUnitUuid}`（`material
  get` 详情里的单位换算列表）
- `sub_shop_roles` 响应 `shops[].roles[].Uuid`（`RoleItem`，复用
  `saas_staff.go` 定义，嵌在每个子店的角色列表里）
- `VisibilityDetailResp.RoleConfigs[].{RoleUuid,CompanyUuid}`（`material
  visibility get` 详情里的角色配置列表）

顶层字段（如 `Material.Uuid`/`CategoryUuid`/`TypeUuid`、
`VisibilityDetailResp.Uuid`/`CategoryUuids[]` 本身作为顶层数组）已由
gateway 字符串化，可安全当字符串比较；上述嵌套字段没有，这是全域既有
口径（同 `purchase receipt pending-items` 的 `units[]`/`unit_list[]`
先例），非本 CLI 引入的新缺陷。

## 本域只读：20 个写端点未接(需用户明确授权)

上游 `shop_material.go`/`shop_material_category_visibility.go` 里另有
**20 个** `POST`/`DELETE` 写端点（1 个 DELETE + 19 个 POST），覆盖物品/
分类/类型/单位可见性的增删改与批量导入，一律不接（只读默认政策）。
**注**：`product_bom/*`、`recipe/cost_estimate` 相关端点虽同在
`shop_material.go` 文件里，但属 `bom` 域范畴（已在单独接入，见
`skills/ttpos-bom/SKILL.md`），不计入本域这 20 条；`test/material/
category/sync`（路径前缀是 `/test/`，非 `/material/`）同样不计入。全仓
（不限于物品主体）已逐条清点为 20 个写端点，其中 17 个属物品本身、
3 个属分类可见性配置，其余
文件无 `/material` 前缀的写路由。**计划阶段"14 个写端点"是估算偏
低（原始 survey 被截断漏看一部分）；本任务第一版曾误报 21（把路径前
缀是 `/test/material/...` 的测试端点算了进来）；以本次全仓 `grep` 结
果 20 为准**：

| 端点 | 动作 |
|---|---|
| `POST material/update_safety_stock` | 修改物品安全库存 |
| `POST material/update_negative_stock` | 修改物品负库存设置 |
| `POST material/category/add` | 创建物品类别 |
| `POST material/category/sort` | 排序物品类别 |
| `POST material/category/edit` | 编辑物品类别 |
| `POST material/category/delete` | 删除物品类别 |
| `POST material/type/add` | 新增物料类型 |
| `POST material/type/edit` | 编辑物料类型 |
| `POST material/type/relate_materials` | 设置类型关联物品 |
| `POST material/type/sort` | 排序物料类型 |
| `POST material/type/delete` | 删除物料类型 |
| `POST material/add` | 添加物品 |
| `POST material/edit` | 编辑物品 |
| `POST material/status/batch` | 批量修改物品状态 |
| `POST material/batch_update_visible` | 批量更新物品可见性 |
| `POST material/import/list` | 导入物品列表——⚠️ **方法与语义不一致**：`ImportMaterialList` 是 POST，但 swagger 摘要写"获取导入物品列表"，`ShouldBindJSON` 只是承载分页/过滤条件，实际是**查询**语义（非写入）。按只读默认政策"方法即边界，不按语义猜"，仍不接；若将来放开只读边界，这是可优先考虑纳入只读集合的候选。 |
| `POST material/import` | 导入物品 |
| `POST material_category_visibility/create` | 创建可见性配置 |
| `POST material_category_visibility/update` | 更新可见性配置 |
| `DELETE material_category_visibility/delete` | 删除可见性配置 |

以上写端点**在用户明确授权之前不会规划接入**：需要先设计确认机制 +
`--dry-run` + 幂等键防重试重复写入 + 审计留痕 + agent 自动化护栏，是
独立的一份计划，。

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `0` | 成功 |
| `1` | 一般错误：上游/gateway 业务错误（含 `SHOP_NOT_IN_SCOPE` 403；`visibility sub-shop-roles` 非总部商户的业务错误也走这条路径，不是 HTTP 403） |
| `2` | 用法错误：位置参数数量不符（`get`/`stock`/`category get`/`type get`/`visibility get` 缺 `<uuid>`）、未知 flag、flag 值解析失败（cobra 层，统一为 exit 2 + JSON 信封）；`--shop` 解析失败；`--format` 取值非法 |
| `3` | 未认证：本地无 token、上游会话过期需重新 `ttpos auth login` |

本域 11 个命令的必填参数只有各 `get`/`stock` 的位置参数 `<uuid>`，由
cobra 的 `Args` 包装器（`exactArgs`，`internal/cliapp/usageerr.go`）在
`RunE` 之前拦下，统一 exit 2 + JSON 信封（此前是：cobra 层裸文本 +
exit 1，现已修复）；`material
unit list` 的 `--uuid` 本身无必填校验，不传按 `uuid=0` 处理，属合法查
询，不触发用法错误。

## 输出契约

同仓库其余命令一致：非 TTY 下固定信封
`{"ok":bool,"data":...,"count":N?,"resolved_shop":{"uuid","name"}?,"error":{"code","message","hint"}?}`
成功时写到 stdout；**失败**（`ok:false`）时信封改写到 **stderr**，stdout
为空，不能靠 stdout 是否为空判断成败，要看退出码。提示/诊断信息一律走
stderr。`resolved_shop` 字段与 `--shop` 解析结果的关系见 `ttpos-shared`。

## 已知局限

- **零数据，非空场景未验**：测试租户物品数据为空。11 个命令均只验证过
  "能通+形状+退出码"这个层面；`material list` 的 `meta.total` 是否与
  真实非空列表条数一致、`material/type/detail` 混合形态取数是否符合预
  期、`visibility sub-shop-roles` 跨库并发读在真实多子店场景下的延迟
  等，均未在有数据的商户上复核，接入有数据的商户时需人工复核一次。
- **20 个写端点未接**：见上文「本域只读」，需用户明确授权后才规划；
  其中 `material/import/list` 虽是 POST 但语义是查询（详见「本域只
  读」表格备注），仍按方法边界不接。
- **`material list`/`material type list` 两个 GET 会触发上游写库（幂
  等种子）**：见上文「副作用」，上游既定行为，不改行为，如实文档化。
  `material category list`（`GetMaterialCategoryList`）**不**调用
  `EnsureSystemMaterialTypes`，不在此列（已逐个核实，"同名三连"
  的猜测不成立）。两处错误处理不同：
  `material list`（`:188` 附近）种子写入失败用 `_ = s.
  EnsureSystemMaterialTypes(ctx)` 丢弃错误，不阻断列表返回；
  `material type list`（`:2899-2901` 附近）是
  `if err := s.EnsureSystemMaterialTypes(ctx); err != nil { return
  ..., err }`——种子写入失败会让 `material type list` 整条命令失败，
  两者对排障的影响不同，不能混为一谈。
- **`material visibility list`/`get` 权限缺口**：见上文「安全观察」与
  证据文档 §4，子店可读取总部专属的可见性配置，ttpos-cli 如实透传，不
  做补偿性拦截。
- **`material unit list` 的 `--uuid` 语义分叉**：见上文，不传时
  `conversion_rate` 不是真实换算率。
- **嵌套大整数不字符串化**：见上文，`UnitList[]`/`QuotaConfig.
  QuotaUnitUuid`/`sub_shop_roles` 里的角色 uuid 等嵌套字段仍是 JSON
  number，JS/TS 消费方需自行处理精度。
- `--shop` 的完整解析规则见 `skills/ttpos-shared/SKILL.md`，
  不在本文档重复。
