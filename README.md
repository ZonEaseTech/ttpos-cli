# ttpos CLI

TTPOS 的命令行工具:在终端里查商户的订单、商品、员工、桌台、会员、采购、
物料等数据。**只读**——不会修改任何业务数据。

给人用,也给 AI agent 用:所有命令都支持 `--format json`,配套的 agent
skills 见下方「给 AI agent 用」。

> 本仓库只放发布产物与安装脚本,不含源码。

## 安装

**Linux / macOS**(Intel 与 Apple 芯片都支持):

```sh
curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh
```

装到 `~/.local/bin/ttpos`,不需要 sudo。重复运行即升级。

Windows 暂未发布。

<details>
<summary>其他安装方式</summary>

```sh
# 装到别处
TTPOS_INSTALL_DIR=/usr/local/bin curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh

# 装指定版本
VERSION=0.1.0 curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh

# 卸载(保留 ~/.ttpos 下的凭证与配置)
curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh -s -- --uninstall
```

也可以直接从 [Releases](https://github.com/ZonEaseTech/ttpos-cli/releases)
下载 `tar.gz` 自行解压。**建议用上面的命令行方式**:macOS 从浏览器下载的
可执行文件会被系统标记隔离,首次运行会被拦下;命令行下载不会。

安装脚本会先校验 SHA256 再解压,校验不通过直接中止。
</details>

## 上手

```sh
ttpos auth login         # 1. 浏览器打开打印出的网址并登录（命令会等待，完成后退出）
ttpos shop use <店名>     # 2. 选默认商户
ttpos order list         # 3. 开始查
```

登录时命令会自己在本机起一个临时授权页,登完就退出,不用另开窗口。查数据
也走进程内,不需要常驻服务。凭证只存在本机。

卡住时先跑 `ttpos doctor`,它会逐项检查并告诉你下一步做什么。

### 远端授权 / Coder

笔记本默认不用这一步。只有授权页需要给别的机器打开时(Coder、`--public-url`)
才常驻 gateway:

```sh
ttpos gateway serve --public-url https://...   # 机器 A
ttpos auth login --gateway https://...         # 机器 B（可用 --no-wait）
```

## 能查什么

| 命令 | 内容 |
|---|---|
| `ttpos order` | 订单列表/详情/退款信息/能否关单 |
| `ttpos product` | 商品、分类,以及单位/加料/属性/规格/税类 |
| `ttpos desk` | 桌台与桌台区域 |
| `ttpos staff` | 员工、角色、权限树 |
| `ttpos member-order` | 会员订单 |
| `ttpos recharge` | 会员充值订单 |
| `ttpos setting` | 营业/收银/支付/自助机/厨显/打印配置快照 |
| `ttpos bom` | 配方、物料清单、成本卡 |
| `ttpos purchase` | 采购单、收货单、限购方案 |
| `ttpos material` | 物品、库存、分类、类型、单位 |
| `ttpos shop` | 商户列表与默认商户 |
| `ttpos doctor` | 环境自查 |

`ttpos --help` 看全部,`ttpos <命令> --help` 看细节。

## 给 AI agent 用

配套 skills 覆盖每个命令域的用法、参数陷阱与已知局限。
井号后面的版本必须和 `ttpos --version` 一致（不要写成 `@v0.2.0`，那个会被
当成 skill 名，不是版本）：

```sh
npx skills add ZonEaseTech/ttpos-cli#v0.2.0
```

也可以只装需要的:

```sh
npx skills add ZonEaseTech/ttpos-cli#v0.2.0 --skill ttpos-order --skill ttpos-shared
```

`ttpos-shared` 描述了所有命令共用的 `--shop` 解析规则,建议与任一其他
skill 一起装。

**退出码**(agent 可直接分支):

| 码 | 含义 |
|---|---|
| 0 | 成功 |
| 1 | 业务错误或网络失败 |
| 2 | 用法错误(参数缺失、取值非法、未知 flag) |
| 3 | 未登录 |

非交互环境下,错误一律是 JSON 信封:
`{"ok":false,"error":{"code":"...","message":"...","hint":"..."}}`。

## 说明

- 只读:不提供下单、审批、入库、删除等会改数据的命令。
- 凭证存在本机(优先系统密钥链,没有则退到 `~/.ttpos/` 下权限 600 的文件)。
- 需要一个 TTPOS 商户账号才能登录;能查到什么取决于该账号自身的权限。

问题反馈请开 [Issue](https://github.com/ZonEaseTech/ttpos-cli/issues)。
