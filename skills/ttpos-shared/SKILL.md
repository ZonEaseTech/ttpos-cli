---
name: ttpos-shared
description: Use this skill whenever another ttpos-cli skill (ttpos-order, ttpos-shop, or any future one) is in play and the task touches the `--shop` flag, shop resolution, local aliases, or the default-shop context — e.g. "用别名查订单"、"设置默认商户"、"这个 --shop 参数能不能填名字"、"resolved_shop 是什么". This skill documents the shared `--shop` resolution contract; other skills assume the caller has already read it and only cover their own command-specific flags. Do not use this in isolation to answer questions unrelated to shop identification (order filters, auth flow, etc. — see the command-specific skill instead).
---

# ttpos-shared

`ttpos` 的 `--shop` 参数在多个命令（`order list`/`order get`、`shop use`）间
共享同一套解析规则："标识"可以是 `company_uuid`、本机别名、商户名全称或
前缀，由同一条解析链归约为唯一的 `company_uuid`。本文档是这条规则的唯一
出处，其余 skill（如 `ttpos-order`）不重复讲这部分，只讲各自命令特有的
flag。

## 四级上下文：`--shop` 缺省时怎么兜底

`ttpos order list`/`order get` 的 `--shop` 是可选的。缺省时按优先级从高到
低依次尝试：

```
--shop flag
  │  最高优先级，显式传了就不看后面三级
  ▼
TTPOS_SHOP 环境变量
  │  适合 agent/脚本在单次调用里临时指定，不落盘
  ▼
./.ttpos/config.json 的 default_shop（目录级，ttpos shop use --dir 写入）
  │  适合按项目目录固定商户
  ▼
~/.ttpos/config.json 的 default_shop（全局，ttpos shop use 写入）
```

四级全空时命令直接报 `USAGE`(exit 2)，hint 提示「用 --shop 指定商户，或
运行 ttpos shop use 设置默认商户」，不会带着空标识去猜。

## 解析链：标识 → uuid

拿到标识（不管来自 `--shop`、环境变量还是配置文件）后，按开销从低到高走
以下步骤，**命中即返回，不做后续步骤**：

```
标识
├─ 1. 是合法 company_uuid（非零、1~20 位数字）？ → 直接取用
│      不拉商户列表；resolved_shop.name 留空（这是"未经名称解析"的标记）
├─ 2. 命中本机别名（ttpos shop alias 设置的）？   → 取别名映射的 uuid
│      同样不拉列表；映射的 uuid 会过一次合法性校验，防止别名配置写脏
└─ 3. 否则拉当前账号可访问的商户列表，按 normalize 后的 company_name 匹配
       ├─ 精确相等，唯一命中 → 返回
       ├─ 精确相等，多个命中 → 报错，列出候选 uuid+名称（USAGE, exit 2）
       ├─ 无精确命中，按前缀匹配，唯一命中 → 返回
       ├─ 前缀匹配，多个命中 → 报错，列出候选（同上）
       └─ 0 命中 → 报错，提示 ttpos shop list 核对可访问商户（USAGE, exit 2）
```

**确定性约定**：任何一步只要命中不止一个商户，一律拒绝并报错列出候选，
**绝不**做"选第一个"之类的隐式选择——标识本来就是给 agent 用的，agent 不
擅长在歧义面前做主观判断，宁可报错让调用方换更精确的输入或直接用 uuid。

前缀匹配是"前缀"不是"子串"：输入 `"ios"` 能匹配 `"iOS审核-测试商户"`（前
缀 `iOS` 忽略大小写经 normalize 后一致），但不会匹配 `"App-iOS专用店"`
（`ios` 不在开头）。

商户名比较前都经过 normalize（大小写折叠 + NFKC + 剥离首尾空白/不可见填
充符），生产里出现过前导空格、全角字符、U+3164 HANGUL FILLER 等"看起来正
常实际是脏数据"的商户名，normalize 是为了让这类名字也能被合理匹配到——
但如果 normalize 后整个标识变成空串（比如输入本身就是纯 U+3164），会在拉
列表前直接报错，不会去匹配任何商户，因为一个"空标识"不可能唯一对应任何
可读商户名。

## 本机别名：`ttpos shop alias`

别名是纯本机概念（存在 `~/.ttpos/config.json`），不发起网络请求，也不会
出现在任何 gateway wire 契约里。

```bash
ttpos shop alias <name> <uuid>     # 设置/覆盖一个别名
ttpos shop alias --list            # 列出全部别名（TTY 表格 / 非 TTY JSON+count）
ttpos shop alias --remove <name>   # 删除别名，删除是幂等的
```

- `<name>` 不能为空，也不能是纯数字——纯数字会跟 `company_uuid` 本身的形
  式冲突，解析时无法区分究竟是别名还是直接传入的 uuid。
- `--list` 与 `--remove` 互斥，同时传报错。
- `ttpos shop list` 的 TTY 表格会多一列"别名"，用本机 Aliases 反查
  `company_uuid` 展示（一个 uuid 可能对应多个别名，逗号连接）；非 TTY 的
  JSON 输出**不带**这一列——别名是本机概念，混进 wire data 会让同一个
  uuid 在不同机器上输出不一致，破坏 agent 消费 JSON 时的稳定契约。

## 设置默认商户：`ttpos shop use`

```bash
ttpos shop use <标识>          # 写入 ~/.ttpos/config.json 的 default_shop
ttpos shop use <标识> --dir    # 写入 ./.ttpos/config.json（只对当前目录生效）
```

`<标识>` 走上面同一条解析链。写完后后续命令的 `--shop` 就可以省略，走四
级上下文兜底拿到这里设置的值。

## 回显与 `resolved_shop`

任何经过名称/别名解析（不是纯 uuid 直取）的命令，成功后都会：

- 向 **stderr** 打一行回显：`已解析: <你的输入> → <uuid> <商户名>`，管道
  安全（不占用 stdout），方便人/agent 核对"我以为是这家"与实际解析结果一
  致。纯 uuid 直取不产生歧义，不回显。
- 在输出信封里带上 `resolved_shop` 字段：

  ```json
  {"ok": true, "data": {...}, "resolved_shop": {"uuid": "<商户uuid>", "name": "iOS审核-测试商户"}}
  ```

  纯 uuid 输入时 `resolved_shop.name` 为空字符串——这是"未经名称解析"的
  标记，不代表商户没有名字。
- **别名命中时 `name` 是 `(别名 <你输入的别名>)` 占位符而非真实商户名**（该
  路径不拉商户列表，零网络开销的代价）。例如输入别名 `t5609` 命中后：

  ```json
  {"ok": true, "data": {...}, "resolved_shop": {"uuid": "<商户uuid>", "name": "(别名 t5609)"}}
  ```

## 退出码

| 退出码 | 触发条件 |
|---|---|
| `2` (`USAGE`) | 四级上下文全空；标识非法（normalize 后为空）；0 命中；多命中歧义；缺位置参数（如 `ttpos shop use` 不带 `<标识>`）或传了多余位置参数 |
| `3` (`AUTH_REQUIRED`/`AUTH_EXPIRED`) | 解析需要拉商户列表但未登录，或登录态已过期 |
| `1` | 拉列表时上游/gateway 返回的其它错误（`UPSTREAM_ERROR`） |

未登录只在"确实需要拉列表"时才报——纯 uuid 直取、别名命中两条路径都不
触网，即使没登录也能正常解析（但后续实际发请求仍然需要登录，会在更早的
"本地是否有 token"检查处拦截）。
