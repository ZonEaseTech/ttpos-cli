# 变更日志

TTPOS CLI（`@ttpos/cli`）每个版本的变更都记在这里，最新的在最上面。

格式遵循 [Keep a Changelog 1.1.0](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循[语义化版本](https://semver.org/lang/zh-CN/)：

| 分类 | 含义 |
| --- | --- |
| Added | 新增的功能 |
| Changed | 已有功能的变化 |
| Deprecated | 即将移除的功能（会提前至少一个版本标出） |
| Removed | 已移除的功能 |
| Fixed | 修复的问题 |
| Security | 安全相关的修复 |

破坏性变更（升级后原来的用法会失效）在条目开头标 **BREAKING**，并说明怎么迁移。1.0 之前，破坏性变更升中间一位（例如 0.3 → 0.4）；1.0 之后升第一位。

## [Unreleased]

## [0.5.1] - 2026-11-10

### Fixed

- CI 等自动化环境（设置了 `CI` 环境变量）里运行时不再上报使用统计，发版验收不会被计入使用量。

## [0.5.0] - 2026-11-10

### Added

- `ttpos takeout`：Grab、LINE MAN 的外卖订单（`orders` 已结束、`active` 进行中）、订单详情（`get`），以及平台是否开启、是否绑定、菜单最近一次推送（`status`）。
- `ttpos staff log`：员工操作日志，查谁在什么时候改了什么，可按操作人、操作名、对象、结果筛选。
- `ttpos feedback`：给维护者提建议，或用 `--unsupported` 反馈 CLI 做不到的需求。AI 助手只在用户同意后发送。
- 匿名使用统计：命令结束后上报命令名、版本、是否成功、用时，以及是人还是 AI 在调用；不上报参数、门店、金额、账号。首次在终端运行时提示一次，设置 `TTPOS_NO_TELEMETRY=1` 或 `DO_NOT_TRACK=1` 关闭。
- `CHANGELOG.md`：每个版本的变更记录，GitHub Release 说明取自这里。

### Changed

- 表格里以 `_at` 结尾的时间字段也显示为日期时间，值为 0 时显示为空。

## [0.4.6] - 2026-11-10

### Fixed

- 公开 README 的能力表在 GitHub 页面上，业务域名称不再被挤成两行。

## [0.4.5] - 2026-11-10

### Fixed

- 公开 README 的能力表改为两列，命令不再在连字符处折行；去掉加载失败的徽章。

## [0.4.4] - 2026-11-10

### Changed

- 公开 README 按业务域重写：能查什么、计划支持、不会支持，以及两种安装方式（让 AI 装、自己装）、常见问题对照、技能表、数据安全说明。
- npm 页面改为同一口径的精简版。

## [0.4.3] - 2026-11-10

### Changed

- `stats business` 和 `stats shops` 的金额字段改用 TTPOS 后台首页的名字：总销售额、实收金额，并新增「营业收入」。原来叫「营业额」的就是总销售额。
- 营业概况显示服务端实际统计的营业日和时段，和后台对数时先核对这两项。

## [0.4.2] - 2026-11-10

### Changed

- npm 页面直接给出可以复制给 AI 助手的安装和登录指令。

### Fixed

- 公开 README 的防钓鱼说明与新登录页一致（改为核对终端里的核对码）。

## [0.4.1] - 2026-11-10

### Changed

- 重做登录页：左侧表单、右侧餐饮场景图，图上的终端演示跟随登录状态变化；手机上改为图片顶栏加表单面板。
- 登录页交互：密码框内显示或隐藏密码、大写锁定提示、验证码点击换图、错误显示在对应输入框旁、回车跳到下一个空项、提交中锁定、链接失效时可复制登录命令。

### Removed

- 登录页不再显示终端所在机器的用户名和主机名。

## [0.4.0] - 2026-11-10

### Added

- `ttpos stats`：营业概况、多店对比、热销商品、支付方式收入、员工提成。统计必须带时间范围：默认今天，最长 31 天，按门店营业日计算。
- `ttpos member`：搜会员、会员详情（余额、积分、等级）、消费和充值流水、会员等级。
- `ttpos shop expiry` 和 `ttpos auth login --cloud`：用云平台账号查哪些门店快到期或已过期。
- 每个业务域的 `--help` 开头列出它能回答的问题；内置技能按业务域组织。

### Changed

- 打码规则改为：列表和搜索结果打码，按 ID 查单条时完整显示，密码和密钥任何情况下都遮蔽。
- 状态码显示成文字，商品显示分类名。

## [0.3.4] - 2026-11-07

### Removed

- **BREAKING** 删除 `gateway serve`、`--gateway`、`TTPOS_GATEWAY_URL`、`--upstream`、`--no-wait`、`--device-code`。CLI 不再连接 TTPOS 以外的地址。迁移：去掉这些参数直接运行；远程机器登录改用 `ttpos auth login --port <端口>` 加端口转发。

### Security

- 修复 `staff get` 可读到其他商户员工、`--reveal` 可被绕过、符号链接覆盖文件、不可见字符注入、跳转后重发密码等问题。
- 升级到 Go 1.27.3，并在每次构建时检查已知漏洞。

## [0.3.3] - 2026-11-07

### Changed

- 安装脚本先确认新下载的程序能运行，再替换旧版本。

## [0.3.2] - 2026-11-06

### Changed

- 内置技能整改，并补充真实场景的评测。
- 查询时不再锁住本机会话库，多个命令可以同时运行。

### Security

- `--reveal`（显示完整联系方式）只能由人在终端运行并输入确认码，AI 和脚本调用会被拒绝。

### Fixed

- 补全门店名称的内部读取不再被记成一次 `--reveal` 使用。

## [0.3.1] - 2026-11-05

### Changed

- 帮助系统重做：按用途分组、每个命令带示例、命令写错时提示最接近的写法、新增 `ttpos help <主题>`。

## [0.3.0] - 2026-11-05

### Added

- `ttpos payment-method`（支付方式）和 `ttpos printer template list`（打印模板）。
- `ttpos skills list` 和 `ttpos skills read`：内置的 AI 使用说明，和当前版本一致。
- 通过 npm 安装：`npm install -g @ttpos/cli`。

### Changed

- 登录页只在本机回环地址提供，并重做安全设置；`auth login` 支持 `--port` 和 `--no-browser`。
- 列表每页最多 100 条，订单类查询的时间范围最长 31 天。
- 默认时间范围按门店时区计算。

### Removed

- **BREAKING** 停用采购、物料、员工搜索、订单退款信息、能否关单、会员外送单退款信息这几个查询，因为它们在 TTPOS 服务端会写入数据或加锁。上游修复后恢复。

### Security

- 本机登录信息加密保存，优先使用系统钥匙串；登录最长 30 天有效，重新登录会作废同一账号的旧登录。
- 输出默认遮蔽敏感字段，并去掉终端控制字符。

## [0.2.0] - 2026-08-20

### Changed

- 查询、登录状态、登出默认在本进程内完成，不再需要另开一个常驻服务。
- `auth login` 默认拉起一个只在登录期间存在的本机授权页。

### Fixed

- 本机会话库被占用时，`doctor` 给出正确的提示。

## [0.1.0] - 2026-08-19

### Added

- 首次公开发布：订单、会员外送单、充值、商品（含单位、加料、属性、规格、税类）、配方与成本卡、桌台、门店配置、员工与角色、采购、物料的只读查询。
- 浏览器登录（核对码确认），`doctor` 环境自查，安装脚本，以及 macOS 和 Linux 四个平台的程序。
- 用法错误统一返回退出码 2 和 JSON 格式的错误信息。

[Unreleased]: https://github.com/ZonEaseTech/ttpos-cli/compare/v0.5.1...HEAD
[0.5.1]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.5.1
[0.5.0]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.5.0
[0.4.6]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.4.6
[0.4.5]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.4.5
[0.4.4]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.4.4
[0.4.3]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.4.3
[0.4.2]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.4.2
[0.4.1]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.4.1
[0.4.0]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.4.0
[0.3.4]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.3.4
[0.3.3]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.3.3
[0.3.2]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.3.2
[0.3.1]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.3.1
[0.3.0]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.3.0
[0.2.0]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.2.0
[0.1.0]: https://github.com/ZonEaseTech/ttpos-cli/releases/tag/v0.1.0
