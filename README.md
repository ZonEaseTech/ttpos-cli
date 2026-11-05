# ttpos

TTPOS 的命令行工具：在终端里查商户的订单、商品、员工、桌台、配置、支付方式等
数据。给人用，也给 AI agent 用。

> 当前为内部预览版，面向 TTPOS 运营与支持同事。

**只读**——不会改任何业务数据。本仓库只放安装脚本、agent skills 和
[Releases](https://github.com/ZonEaseTech/ttpos-cli/releases) 里的二进制，
不含源码。

## 安装

### 方式一：npm（需 Node ≥18）

```sh
npm install -g @ttpos/cli
ttpos --version
```

Linux 与 macOS（Intel / Apple 芯片）自动装对应平台包，Windows 暂未发布。

### 方式二：安装脚本（无需 Node）

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

需要一个 TTPOS 商户账号。登录在浏览器里完成，凭证只存在本机。

```sh
ttpos auth login          # 自动打开浏览器；核对码与终端一致后输入账号密码
ttpos shop use <店名>      # 设默认商户
ttpos order list          # 开始查
```

授权页只在本机 `http://127.0.0.1:<端口>` 提供，地址栏不是它就别输密码。
浏览器没弹出时手动打开终端里的链接；不想自动打开加 `--no-browser`。
查询走进程内，不用另开窗口、也不用常驻服务。卡住时跑 `ttpos doctor`。

## 命令

| 命令 | 查什么 |
| --- | --- |
| `ttpos order` | 订单列表与详情 |
| `ttpos product` | 商品、分类、单位 / 加料 / 属性 / 规格 / 税类 |
| `ttpos desk` | 桌台与区域 |
| `ttpos staff` | 员工、角色、权限树 |
| `ttpos member-order` | 会员订单 |
| `ttpos recharge` | 会员充值订单 |
| `ttpos setting` | 营业 / 收银 / 支付 / 自助机 / 厨显 / 打印配置 |
| `ttpos bom` | 配方、物料清单、成本卡 |
| `ttpos payment-method` | 支付方式、系统默认支付方式清单 |
| `ttpos printer` | 打印模板 |
| `ttpos shop` | 商户列表与默认商户 |
| `ttpos doctor` | 环境自查 |
| `ttpos skills` | 内置的 agent 使用说明（与当前版本一致） |

`ttpos --help` 看全部，`ttpos <命令> --help` 看细节。能查哪些商户取决于登录
账号绑定了哪些商户。

为保护生产系统，列表单页最多 100 条，订单类查询的时间范围最长 31 天。

## 已知副作用

CLI 只发查询请求，但 TTPOS 服务端在"进入某个商户"这一步会记录两件事：

- 该账号"上次进入的门店"会更新为最近查询的商户（移动管理端下次默认打开它）；
- 商户的设备列表里会出现一条名为 `ttpos-cli` 的管理端设备记录（不占设备名额）。

同一账号对同一商户每小时最多触发一次。

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

## 敏感信息

输出默认做了脱敏，方便直接交给 agent：

- 密码、私钥、token 类字段始终显示为 `"***"`。
- 手机号、邮箱、税号/证件号、银行账号、详细地址默认打码（如
  `******5678`、`a***@example.com`）。
- 需要看完整联系方式时加全局 `--reveal`；密码类字段仍然遮蔽。
  `--reveal` 只在人明确需要时使用，不要让 agent 自行添加。
- 字符串中的终端控制字符会被去掉。

## Agent skills

skills 已编进二进制，与当前版本一致：

```sh
ttpos skills list
ttpos skills read order
```

也可以装进 agent 的 skills 目录：

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

CLI 在远端机器（Coder、SSH 登录的服务器），浏览器在本地时：固定授权页端口，
再转发到本地。

```sh
ttpos auth login --port 7080                 # 远端
coder port-forward <workspace> --tcp 7080    # 本地，二选一
ssh -L 7080:127.0.0.1:7080 <host>            # 本地，二选一
```

然后在本地浏览器打开终端打印的 `http://127.0.0.1:7080/authorize?...`。
授权页只监听回环地址，不提供公网访问方式。

## 反馈

问题请开 [Issue](https://github.com/ZonEaseTech/ttpos-cli/issues)。
