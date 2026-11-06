---
name: ttpos-staff
description: Looks up TTPOS staff accounts, roles and the permission tree through the ttpos CLI, with contact details masked by default. Use when asked 有哪些员工, 谁是超管, 员工详情, 员工联系方式, 员工手机号, 有哪些角色, 这个角色有哪些权限, 权限树. Not for orders, products, desks or member data.
---

# ttpos-staff

先读 `ttpos-shared`。本版不提供 `staff search`（按邮箱或手机号跨商户查人）；只能在当前商户内用 `staff list --keyword` 查。

## 联系方式

手机号、邮箱默认打码。**`--reveal` 对 agent 不可用**，调用会被拒（退出码 2，`REVEAL_REQUIRES_TERMINAL`），人明确要求时也一样。

被问联系方式时：不要尝试 `--reveal`，先给打码结果；用户要完整号码时告诉他：完整号码请你自己在终端运行 `ttpos staff get <uuid> --reveal`。

## 命令

```bash
ttpos staff list --keyword <用户名/姓名/手机>
ttpos staff get <uuid>
ttpos staff role list
ttpos staff role get <uuid>
ttpos staff permission-group | jq '.data'
```

查询上限：`staff list`、`staff role list` 每页最多 100 条。

## 读输出

- `is_super`、`is_disable` 是整数 `0/1`，不是 bool，用 `== 1` 判断。
- `staff list` 的 `uuid` 是字符串；`--keyword` 不能用打码后的手机号。
- `staff get` 的 `data` 是未建模的原始详情，`--format table` 也输出 JSON。
- `staff role get` 返回 `uuid` `access_uuids` `name` `staff_count` `staff_uuids` `selected_leaf_count` `total_leaf_count`。`staff_uuids`、`access_uuids` 是 number 数组，可能超过 2^53，不要转 double。
- `staff permission-group` 只输出 JSON，数据量大。节点结构 `{id,uuid,name,path,parent_id,is_route,is_menu,is_show,children:[...]}` 递归嵌套，`uuid` 是大整数。
- 只覆盖账号基础信息、角色和权限树，不含登录日志和操作日志。

退出码见 `ttpos help exit-codes`。
