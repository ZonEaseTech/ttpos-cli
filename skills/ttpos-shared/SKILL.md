---
name: ttpos-shared
description: Sets the baseline rules for every ttpos CLI skill, covering how to judge results, --shop resolution, default merchants and aliases, human-only login, masking and --reveal limits, query limits, and capabilities v1 does not offer. Use before running any ttpos command, or when asked 怎么登录, 远端机器登录, 未登录, 设置默认商户, 商户别名, --shop 能不能填名字, resolved_shop 是什么, 手机号为什么打码, 完整手机号, 查询上限.
---

# ttpos-shared

所有 ttpos skill 的底座，先读这份。`ttpos` 是 TTPOS 餐饮 POS 的只读查询 CLI，不改业务数据。内置说明与当前版本一致：`ttpos skills list`、`ttpos skills read <名>`。

## 通用准则

1. **先看 `ttpos <命令> --help`，别猜参数。** 帮助主题：`ttpos help exit-codes|output|environment|reference`。
2. **用 `ok` 和退出码判断结果，不要解析 `message`。** 被调用时成功写 stdout；失败信封写 stderr，stdout 为空。
3. **读 `notice` 再下结论。** 信封可能带 `notice`，说明查询窗口或可能的传参错误。列表为空不等于不存在，先核对 `notice`、`resolved_shop` 和时间范围。
4. **登录必须由人完成。** agent 不代输账号密码。
5. **agent 不用 `--reveal`。** 规则见下方「打码」。
6. **不推算。** 只报告系统给出的字段，不根据字段推算系统没给的结论（例如用订单金额算可退金额）。
7. **用户没点名具体商户，就不传 `--shop`，用默认商户。** "TTPOS" 是产品名，不是商户名。`--shop` 解析失败时运行 `ttpos shop list` 换正确标识继续查，不要就此停下。
8. **没有就说没有。** 本版不提供 purchase、material 整域，以及 `staff search`、`order return-info`、`order can-close`、`member-order return-info`。不要拿相近命令代替（例如不能拿订单号去查 `recharge refund-info`），请用户到商户后台查看。

## 查询上限

- 列表每页最多 100 条（`--size` 超过会截断到 100），默认 20 条。`count` 大于本页条数时用 `--page` 翻页。
- 订单、会员订单、充值的 `--from/--to` 跨度最长 31 天，超过 exit 2，请分段查询。日期按商户时区计算。

## 读输出

信封：`{"ok":true,"data":{"list":[]},"count":20,"resolved_shop":{"uuid":"<商户uuid>","name":"商户名"},"notice":"..."}`

- `resolved_shop` 是本次实际查询的商户，用它确认查对了。`name` 可能为空，别名命中时可能是 `(别名 xx)`，以 `uuid` 为准。
- 列表顶层 uuid 是字符串；详情和嵌套字段里的 uuid 可能是 number 且超过 2^53，一律按字符串或 int64 读，不要转 double。

## 打码

- 密码、私钥、token、secret 类恒为 `***`，`--reveal` 也不显示。
- 手机号、证件号、税号、银行账号、会员卡号保留末 4 位；邮箱保留首字符和域名；详细地址整体为 `***`。
- 打码后的值不是原值，不能拿去当 `--keyword` 等查询条件。

`--reveal` 只能由人在交互终端运行并输入 yes 确认。agent 和脚本调用一律被拒：退出码 2，错误码 `REVEAL_REQUIRES_TERMINAL`。不要尝试，也不要用伪终端绕过。这条不是"人明确要求就能加"：

| 用户说 | 正确做法 |
|---|---|
| 「列出员工联系方式」 | 不加 `--reveal`，给打码结果 |
| 「我要完整手机号」 | 也不加。先给打码结果，并告诉用户：完整号码请你自己在终端运行 `ttpos <命令> --reveal` |

## `--shop`

没传时依次取：`--shop` > `TTPOS_SHOP` > `./.ttpos/config.json` > `~/.ttpos/config.json`。全空 exit 2。标识按顺序解析，命中即止：

1. 1~20 位数字且非零：当作商户 uuid。纯数字不会被当成别名或商户名。
2. 本机别名。
3. 当前账号可访问的商户名：先精确匹配，再前缀匹配（不是子串，忽略大小写、全半角和首尾空白）。

多个命中或 0 命中都是 exit 2，错误里会列候选或提示运行 `ttpos shop list`。不会替你选第一个，换更精确的标识或直接用 uuid。uuid 不在账号范围内是 `SHOP_NOT_IN_SCOPE`（exit 1）。

```bash
ttpos shop list                    # 当前账号可访问的商户；JSON 里不带别名
ttpos shop use <标识>              # 设全局默认商户，加 --dir 只对当前目录生效
ttpos shop alias <名称> <uuid>     # 设别名（不能纯数字），只存本机；另有 --list、--remove <名称>
```

## 登录

未登录或登录失效 exit 3（`AUTH_REQUIRED`/`AUTH_EXPIRED`），让人完成登录。确认身份用 `ttpos auth status`。查询不需要常驻服务。

```bash
ttpos auth login               # 人在本机终端：自动开浏览器，核对码一致后登录
ttpos auth login --port 7080   # CLI 在远端：本地再运行 ssh -L 7080:127.0.0.1:7080 <host> 或 coder port-forward <workspace> --tcp 7080
```

agent 要把链接转给人时用两段式，必须显式指向本机的 `ttpos gateway serve`：

```bash
ttpos gateway serve &                                                         # 只监听 127.0.0.1:7080
ttpos auth login --gateway http://127.0.0.1:7080 --no-wait                    # 输出 verification_uri、user_code、device_code
ttpos auth login --gateway http://127.0.0.1:7080 --device-code <device_code>  # 人授权后运行，拿到登录态
```

把 `verification_uri` 和 `user_code` 一起转给人，提醒「页面核对码与这里一致再登录」。授权链接只会是 `127.0.0.1` 或 `localhost`，否则 CLI 直接报错，这是防钓鱼，不要绕过。
