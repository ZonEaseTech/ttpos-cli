# ttpos

TTPOS 的命令行工具：在终端里查商户的订单、商品、员工、桌台、配置、支付方式等
数据。给人用，也给 AI agent 用。

> 当前为内部预览版，面向 TTPOS 运营与支持同事。

**只读**——不会改任何业务数据。本仓库只放安装脚本、agent skills 和
[Releases](https://github.com/ZonEaseTech/ttpos-cli/releases) 里的二进制，
不含源码。

## 让 AI 帮你装（推荐）

把下面这段话原样发给你的 AI 助手（Claude Code、Codex、Cursor 等）：

```text
请帮我安装 TTPOS 命令行工具并登录：
1. 运行 npm install -g @ttpos/cli && npx skills add ZonEaseTech/ttpos-cli -g -y
2. 运行 ttpos --version 确认安装成功
3. 把 ttpos auth login 放到后台运行，把它打印的授权链接和核对码发给我；我在浏览器里登录后，等命令自己退出
4. 运行 ttpos shop list，列出我能查看的商户
之后我问商户数据时，先读 ttpos-shared 技能再查。
```

登录必须你本人在浏览器里完成，AI 不会也不应该替你输入密码。

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
curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | TTPOS_INSTALL_DIR=/usr/local/bin sh

# 装指定版本
curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | VERSION=0.3.3 sh

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

## 按业务域查

| 业务域 | 能回答的问题（举例） |
| --- | --- |
| `ttpos stats` 经营 | 今天、本月营业额，实收、单数、客单价；各门店对比；热销菜；支付方式收入；员工提成 |
| `ttpos order` 订单 | 某段时间的订单、按订单号查、取消单、某单明细与退款 |
| `ttpos member-order` / `ttpos recharge` | 会员外送单；充值单与可退金额 |
| `ttpos member` 会员 | 按手机号或会员号找会员；余额、积分、等级；消费与充值记录 |
| `ttpos product` / `ttpos bom` 商品 | 价格、上下架、分类；配方与成本卡 |
| `ttpos shop` 门店 | 能查哪些店；哪些店快到期（需云平台账号） |
| `ttpos desk` / `setting` / `payment-method` / `printer` | 桌台占用、门店配置、支付方式、打印模板 |
| `ttpos staff` 员工 | 员工、角色、权限 |

每个业务域的 `--help` 开头列着它能回答的问题和对应命令，例如 `ttpos stats --help`。
状态码都显示成文字（如"已完成""空闲"），商品显示分类名。

统计必须带时间范围：默认今天，可用 `--date yesterday|this-week|this-month|...` 或
`--from/--to`（最长 31 天），按门店营业日计算。

门店到期时间只有云平台能查，需要云平台账号：`ttpos auth login --cloud`（登录有效 10 小时）。

## 帮助

```sh
ttpos --help                 # 全部命令（按用途分组）与快速上手
ttpos order list --help      # 某个命令的用法、示例与注意事项
ttpos help exit-codes        # 帮助主题：environment / exit-codes / output / reference
```

命令或参数写错时会提示最接近的写法，例如 `ttpos order lst` 会提示
`ttpos order list`。按 Tab 补全：`ttpos completion zsh`（或 bash / fish）。

能查哪些商户取决于登录
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
- 列表和搜索结果里，手机号、邮箱、证件号、银行账号、会员昵称、详细地址打码（如
  `******5678`、`a***@example.com`），防止批量拉取名单。
- 按 uuid 查单条（如 `member get`、`staff get`、`order get`）时完整显示联系方式。
- 列表里也要看完整值时加全局 `--reveal`：只能由人在终端运行，并输入屏幕上显示的确认码；agent 调用会被拒绝。
- 字符串中的终端控制字符会被去掉。

## Agent skills

skills 已编进二进制，与当前版本一致：

```sh
ttpos skills list
ttpos skills read order
```

CLI 和 skills 一起装给 agent 用（推荐全局安装，任何目录都生效；需要 Node）：

```sh
npm install -g @ttpos/cli && npx skills add ZonEaseTech/ttpos-cli -g -y
```

agent 代办登录时，把 `ttpos auth login` 放到后台运行，把它打印的链接和核对码转给人，等它退出。

去掉 `-g` 只装到当前项目。升级 CLI 后运行 `npx skills update -g`，让 skills 跟上。没有 Node
时让 agent 直接读内置说明：先 `ttpos skills read shared`，再读对应业务的 skill。

每个命令域一份 skill，写了参数陷阱和已知局限。`--shop` 的解析规则只写在
[`ttpos-shared`](skills/ttpos-shared/SKILL.md) 里，和其他 skill 一起装。

也可以只装需要的：

```sh
npx skills add ZonEaseTech/ttpos-cli -g -y --skill ttpos-order --skill ttpos-shared
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

**防钓鱼：**端口只转发到你自己的机器，不要运行别人发来的转发命令，也不要打开别人发来的授权链接。
页面底部会显示它来自哪台机器的哪个账号，不是你自己的就立刻关闭。

## 反馈

问题请开 [Issue](https://github.com/ZonEaseTech/ttpos-cli/issues)。
