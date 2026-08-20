# ttpos

TTPOS 的命令行工具：在终端里查商户的订单、商品、员工、桌台、会员、采购、
物料等数据。给人用，也给 AI agent 用。

**只读**——不会改任何业务数据。本仓库只放安装脚本、agent skills 和
[Releases](https://github.com/ZonEaseTech/ttpos-cli/releases) 里的二进制，
不含源码。

## 安装

Linux 与 macOS（Intel / Apple 芯片）：

```sh
curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh
```

装到 `~/.local/bin/ttpos`，不需要 sudo。重复运行即升级。Windows 暂未发布。

<details>
<summary>指定目录、指定版本、卸载、手动下载</summary>

```sh
# 装到别处
TTPOS_INSTALL_DIR=/usr/local/bin curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh

# 装指定版本
VERSION=0.2.0 curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh

# 卸载（保留 ~/.ttpos 下的凭证与配置）
curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh -s -- --uninstall
```

也可以从 [Releases](https://github.com/ZonEaseTech/ttpos-cli/releases)
下载对应平台的 `tar.gz` 自行解压。更建议用上面的脚本：它会先校验 SHA256，
而且 macOS 从浏览器下载的可执行文件会被隔离，命令行下载不会。

</details>

## 上手

需要一个 TTPOS 商户账号。登录会在浏览器里完成，凭证只存在本机。

```sh
ttpos auth login          # 打开打印出的网址，在页面上确认后回到终端
ttpos shop use <店名>      # 设默认商户
ttpos order list          # 开始查
```

查询走进程内，不用另开窗口、也不用常驻服务。卡住时跑 `ttpos doctor`。

## 命令

| 命令 | 查什么 |
| --- | --- |
| `ttpos order` | 订单、退款信息、能否关单 |
| `ttpos product` | 商品、分类、单位 / 加料 / 属性 / 规格 / 税类 |
| `ttpos desk` | 桌台与区域 |
| `ttpos staff` | 员工、角色、权限树 |
| `ttpos member-order` | 会员订单 |
| `ttpos recharge` | 会员充值订单 |
| `ttpos setting` | 营业 / 收银 / 支付 / 自助机 / 厨显 / 打印配置 |
| `ttpos bom` | 配方、物料清单、成本卡 |
| `ttpos purchase` | 采购单、收货单、限购方案 |
| `ttpos material` | 物品、库存、分类、类型、单位 |
| `ttpos shop` | 商户列表与默认商户 |
| `ttpos doctor` | 环境自查 |

`ttpos --help` 看全部，`ttpos <命令> --help` 看细节。能查到什么取决于登录
账号自身的权限。

## 输出

终端里默认表格，管道或 agent 调用时默认 JSON。任何命令都可以加
`--format json`。

| 退出码 | 含义 |
| --- | --- |
| 0 | 成功 |
| 1 | 业务错误或网络失败 |
| 2 | 用法错误（缺参数、取值非法、未知 flag） |
| 3 | 未登录 |

非交互环境下，错误一律是 JSON 信封：

```json
{"ok":false,"error":{"code":"...","message":"...","hint":"..."}}
```

## Agent skills

```sh
npx skills add ZonEaseTech/ttpos-cli
```

每个命令域一份 skill，写了参数陷阱和已知局限。`--shop` 的解析规则只写在
[`ttpos-shared`](skills/ttpos-shared/SKILL.md) 里，和其他 skill 一起装。

也可以只装需要的：

```sh
npx skills add ZonEaseTech/ttpos-cli --skill ttpos-order --skill ttpos-shared
```

## 远端授权

只有授权页必须给另一台机器打开时（例如 Coder）才需要常驻 gateway：

```sh
ttpos gateway serve --public-url https://...   # 机器 A
ttpos auth login --gateway https://...         # 机器 B（可用 --no-wait）
```

## 反馈

问题请开 [Issue](https://github.com/ZonEaseTech/ttpos-cli/issues)。
