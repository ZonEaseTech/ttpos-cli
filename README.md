# TTPOS CLI

[![npm](https://img.shields.io/npm/v/@ttpos/cli?label=npm&color=FFBE00)](https://www.npmjs.com/package/@ttpos/cli)

在终端里查询 TTPOS 门店的经营数据：今天卖了多少、某张订单怎么回事、会员还剩多少余额、哪些门店快到期。
你可以自己输入命令查，也可以交给 Claude Code、Codex、Cursor 等 AI 助手代查。

- **只读**：只查询，不修改任何业务数据。
- **账号即权限**：你的 TTPOS 账号在后台能看到什么，这里就能查到什么。
- **登录在浏览器完成**：密码只在 TTPOS 登录页输入，AI 助手接触不到。
- **口径与后台一致**：金额字段名称和统计口径与 TTPOS 后台首页相同，按门店营业日统计。

> 内部预览版，面向 TTPOS 运营与支持同事。支持 macOS 与 Linux，Windows 暂未提供。

---

## 能查什么

| 业务域 | 命令与能查到的内容 |
| --- | --- |
| **经⁠营** | `ttpos stats`<br>总销售额、实收金额、营业收入、订单数、客单价、退款与取消单；逐日明细；各渠道（堂食、外带、Grab、LINE MAN）；商品分类与桌台区域销售；名下各门店对比；热销菜品；各支付方式收入；员工业绩与提成 |
| **订⁠单** | `ttpos order`<br>按日期、订单号、状态查门店订单；订单明细、付款与退款记录 |
| **外⁠送⁠订⁠单** | `ttpos member-order`<br>会员在线下单的外送订单：配送状态与详情 |
| **外⁠卖** | `ttpos takeout`<br>Grab、LINE MAN 的外卖订单（已结束和进行中）、订单详情；平台是否开启和绑定、菜单最近一次推送 |
| **会⁠员⁠充⁠值** | `ttpos recharge`<br>充值记录、充值详情、还能退多少 |
| **会⁠员** | `ttpos member`<br>按手机号、会员号、昵称找会员；余额、积分、等级；消费、充值、积分流水；全体会员的余额合计、充值和消费排行、积分与余额变动、会员卡 |
| **营⁠销** | `ttpos marketing`<br>营销活动（邀请有礼、扫码领券等）与领券记录；优惠券的剩余、发放与核销；满减活动 |
| **商⁠品** | `ttpos product`<br>价格、上下架、分类；单位、加料、属性、规格、税类 |
| **配⁠方⁠成⁠本** | `ttpos bom`<br>菜品配方、BOM 配置、套餐与订单用料、成本卡 |
| **门⁠店** | `ttpos shop`<br>账号能访问哪些门店、默认门店与别名；哪些门店授权快到期或已过期 |
| **桌⁠台** | `ttpos desk`<br>桌台是否开台、所在区域 |
| **门⁠店⁠配⁠置** | `ttpos setting` `ttpos payment-method` `ttpos printer`<br>营业、收银副屏、支付开关、自助点餐机、厨显、打印联数；支付方式；打印模板 |
| **员⁠工** | `ttpos staff`<br>员工账号、角色、每个角色的权限；操作日志（谁在什么时候改了什么） |

每个命令的 `--help` 开头都列着它能回答的问题，例如 `ttpos stats --help`。

### 计划支持

| 业务域 | 计划内容 |
| --- | --- |
| 外卖 | 外卖菜单、促销活动、营业时间 |
| 交班 | 交班报表 |
| 库存 | 采购、物料、调拨、盘点 |
| 连锁总部 | 商品上架计划、管控策略、总部下发记录 |
| 其他 | 门店基本信息、系统通知、打印自定义配置 |

排期以 [Releases](https://github.com/ZonEaseTech/ttpos-cli/releases) 为准。

### 不会支持

| 内容 | 原因 |
| --- | --- |
| 下单、改价、退款、改会员余额、改门店设置等任何修改操作 | TTPOS CLI 只做查询，修改请在 TTPOS 后台或收银机上完成 |
| 查看账号权限以外的门店或数据 | 权限以 TTPOS 账号为准 |
| 批量导出会员的完整手机号、邮箱等联系方式 | 列表结果始终打码，防止名单外流 |
| 查看支付渠道密钥、密码、令牌 | 这类信息始终遮蔽 |
| 生成 Excel 或文件导出 | 需要表格时用 `--format json` 输出后自行转换 |
| 云平台的商户开通、续费、改限额等管理操作 | 云平台账号只用于查询门店到期时间 |

---

## 安装与上手

### 让 AI 帮你装（推荐）

把下面这段话原样发给你的 AI 助手：

```text
请帮我安装 TTPOS 命令行工具并登录：
1. 运行 npm install -g @ttpos/cli && npx skills add ZonEaseTech/ttpos-cli -g -y
2. 运行 ttpos --version 确认安装成功
3. 把 ttpos auth login 放到后台运行，把它打印的授权链接和核对码发给我；我在浏览器里登录后，等命令自己退出
4. 运行 ttpos shop list，列出我能查看的商户
之后我问商户数据时，先读 ttpos-shared 技能再查。
```

登录必须由你本人在浏览器里完成，AI 助手不会、也不应该替你输入密码。

### 自己装

需要 Node.js 18 或以上：

```sh
npm install -g @ttpos/cli
```

没有 Node.js 时用安装脚本，装到 `~/.local/bin/ttpos`，不需要 sudo，重复运行即升级：

```sh
curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh
```

### 三步上手

```sh
ttpos auth login         # 打开浏览器，核对码与终端一致后输入 TTPOS 账号密码
ttpos shop use <店名>     # 设默认门店，之后的命令不用再指定门店
ttpos stats business     # 今天的总销售额、实收金额、订单数
```

### 常见问题怎么问

| 想知道 | 命令 |
| --- | --- |
| 今天卖了多少 | `ttpos stats business` |
| 上个月卖了多少 | `ttpos stats business --date last-month` |
| 名下哪家店昨天卖得最好 | `ttpos stats shops --date yesterday` |
| 本周最畅销的菜 | `ttpos stats products --date this-week` |
| 这个月每天卖了多少 | `ttpos stats daily --date this-month` |
| 今天 Grab 取消了哪些单 | `ttpos takeout orders --platform grab --status 60` |
| 谁改了价格 | `ttpos staff log --title 改价` |
| 查一张订单 | `ttpos order list --order-no <订单号>` |
| 某个会员还剩多少余额 | `ttpos member list --keyword <手机号>`，再 `ttpos member get <会员 uuid>` |
| 哪些门店快到期 | `ttpos auth login --cloud`，再 `ttpos shop expiry` |
| 某道菜的成本 | `ttpos bom module list --keyword <菜名>` |

统计默认查今天，可用 `--date yesterday|this-week|last-week|this-month|last-month`，或 `--from 2026-10-01 --to 2026-10-31`（最长 31 天）。按门店营业日计算：跨 0 点营业的门店，凌晨的单算前一天。

---

## 给 AI 助手用

安装时的 `npx skills add` 会把下面这些技能装给 AI 助手，它会按问题自动选用。技能也内置在 CLI 里，没装时可以运行 `ttpos skills read shared` 直接读。

| 技能 | 用途 |
| --- | --- |
| `ttpos-shared` | 通用规则：登录、选门店、打码、查询上限；所有技能都先读它 |
| `ttpos-stats` | 营业额、多店对比、热销、支付构成、提成 |
| `ttpos-order` | 订单查询与明细 |
| `ttpos-member-order` | 会员外送单 |
| `ttpos-takeout` | Grab、LINE MAN 外卖订单与平台状态 |
| `ttpos-recharge` | 会员充值与可退金额 |
| `ttpos-member` | 会员、余额积分、流水、等级、会员卡、排行 |
| `ttpos-marketing` | 营销活动、优惠券、满减 |
| `ttpos-product` | 商品及单位、加料、属性、规格、税类 |
| `ttpos-bom` | 配方、BOM、成本卡 |
| `ttpos-shop` | 可访问门店、默认门店、授权到期 |
| `ttpos-desk` | 桌台与区域 |
| `ttpos-setting` | 门店配置 |
| `ttpos-payment-method` | 支付方式 |
| `ttpos-printer` | 打印模板 |
| `ttpos-staff` | 员工、角色、权限、操作日志 |
| `ttpos-doctor` | 登录失效、连不上等问题的自查 |

只装部分技能：`npx skills add ZonEaseTech/ttpos-cli -g -y --skill ttpos-stats --skill ttpos-shared`。
升级 CLI 后运行 `npx skills update -g`，让技能跟上新版本。

AI 助手调用时输出固定为 JSON，用退出码判断结果，见下方「输出格式与退出码」。

---

## 数据安全

- 登录页只在本机 `http://127.0.0.1:<端口>` 打开。地址不是它、或页面上的核对码和终端里不一致，就不要输入密码。
- 登录凭证只保存在本机，有效期最长 30 天。`ttpos auth logout` 立即清除。
- 列表和搜索结果里的手机号、邮箱、证件号、银行账号、会员昵称、详细地址会打码；按 uuid 查单条时完整显示。
- 列表里也要看完整值时加 `--reveal`：只能由人在终端运行，并输入屏幕上的确认码，AI 助手调用会被拒绝。
- 密码、密钥、令牌类信息任何情况下都不显示。
- 为保护线上系统，列表每页最多 100 条，订单与统计的时间范围最长 31 天。
- 使用统计：每条命令结束后，会匿名上报命令名、版本、是否成功、用时，以及是人在终端还是 AI 在调用，用于决定先改进什么。不上报参数、门店、金额、账号；首次在终端运行时会提示一次。在 CI 等自动化环境里不统计。关闭：设置环境变量 `TTPOS_NO_TELEMETRY=1`。

---

<details>
<summary><b>输出格式与退出码</b></summary>

在终端里默认输出表格，被脚本或 AI 助手调用时默认输出 JSON。任何命令都可以加 `--format json`。

| 退出码 | 含义 |
| --- | --- |
| 0 | 成功 |
| 1 | 业务错误或网络失败 |
| 2 | 用法错误（缺参数、取值非法、未知参数） |
| 3 | 未登录或登录已失效 |

出错时输出：

```json
{"ok":false,"error":{"code":"...","message":"...","hint":"..."}}
```

更多说明：`ttpos help output`、`ttpos help exit-codes`。

</details>

<details>
<summary><b>CLI 装在远程机器上，怎么登录</b></summary>

CLI 在远程机器（如 Coder、SSH 登录的服务器）、浏览器在自己电脑上时，固定登录页端口，再转发到本地：

```sh
ttpos auth login --port 7080                 # 在远程机器上运行
ssh -L 7080:127.0.0.1:7080 <主机>             # 在自己电脑上运行（Coder 用 coder port-forward <工作区> --tcp 7080）
```

然后在自己电脑的浏览器打开终端里打印的 `http://127.0.0.1:7080/authorize?...`。

只把端口转发到你自己的机器，不要运行别人发来的转发命令，也不要打开别人发来的登录链接。

</details>

<details>
<summary><b>使用后在后台留下的痕迹</b></summary>

CLI 只查询，但进入某个门店查询时，TTPOS 会记录两件事：

- 账号「上次进入的门店」会更新为最近查询的门店，移动管理端下次默认打开它；
- 门店的设备列表里会出现一条名为 `ttpos-cli` 的管理端设备，不占设备名额。

同一账号对同一门店，每小时最多记录一次。

</details>

<details>
<summary><b>升级、指定版本与卸载</b></summary>

```sh
npm install -g @ttpos/cli@latest                  # npm 安装的升级
curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh                          # 脚本安装的升级
curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | VERSION=0.4.3 sh            # 装指定版本
curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | TTPOS_INSTALL_DIR=/usr/local/bin sh   # 装到别的目录
curl -fsSL https://raw.githubusercontent.com/ZonEaseTech/ttpos-cli/main/install.sh | sh -s -- --uninstall        # 卸载（保留 ~/.ttpos 下的登录与配置）
```

也可以从 [Releases](https://github.com/ZonEaseTech/ttpos-cli/releases) 下载对应平台的压缩包。建议用安装脚本：它会校验文件完整性，并避开 macOS 对浏览器下载文件的隔离。

</details>

<details>
<summary><b>遇到问题</b></summary>

先运行 `ttpos doctor`，它会检查登录、会话和默认门店，并给出处理建议。
命令写错时会提示最接近的写法；按 Tab 补全可运行 `ttpos completion zsh`（或 bash、fish）开启。

</details>

## 反馈

想要的功能还没有，或有改进建议，直接在终端里发给维护者：

```sh
ttpos feedback "希望能查交班报表"
```

AI 助手遇到做不到的事，会先问你要不要反馈，你同意后它才会发送。维护者每天处理一次反馈：能用现有能力做到的排进下一个版本，需要 TTPOS 后台提供能力的转给后台开发排期。做好的功能写进 [CHANGELOG](CHANGELOG.md)，排进计划的列在上面的「计划支持」里。也可以提 [Issue](https://github.com/ZonEaseTech/ttpos-cli/issues)。
