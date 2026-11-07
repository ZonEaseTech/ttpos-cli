---
name: ttpos-doctor
description: Diagnoses whether the ttpos CLI environment works, interpreting ttpos doctor checks for version, gateway, credentials, data directory, login and default merchant, plus the optional upstream check, and turns failures into concrete fixes. Use when asked 为什么连不上, 登录态是不是过期了, 环境有没有配置对, CLI 能不能用, or when a command fails for no obvious reason. Not for business errors of a specific query (use that domain's skill).
metadata:
  requires:
    bins: ["ttpos"]
---

# ttpos-doctor

先读 `ttpos-shared`。遇到环境问题先跑它，别逐个猜。

```bash
ttpos doctor --format json             # 只查本机，不访问 TTPOS 服务端
ttpos doctor --network --format json   # 追加 upstream 项，实际连一次服务端
```

agent 必须显式加 `--format json`：这条命令被调用时默认仍输出文本。

## 读输出

```json
{"ok":false,"checks":[{"id":"auth","status":"fail","label":"登录态","detail":"未登录","fix":"运行 ttpos auth login"}],"summary":{"ok":3,"warn":2,"fail":1,"skip":0}}
```

- 顶层 `ok`：没有 `fail` 就是 `true`，`warn`、`skip` 不影响。能不能继续跑业务命令读它就够。
- `status`：`ok` `warn` `fail` `skip`。`skip` 不是通过，是前序失败后没有跑。
- `fix` 可能不存在，这时线索在 `detail`（如 `upstream` 失败时是服务端原文）。

**退出码与其他命令不同**：`0` 没有 fail；`1` 至少一项 fail（**未登录也是 1，不是 3**）；`2` 用法错误。

## 各项检查

| id | 异常时怎么处理 |
|---|---|
| `cli-version` | `warn` 表示开发构建，不阻断 |
| `gateway` | 会话库被占用：等其他 ttpos 进程结束后重试，**不要设 `TTPOS_CONFIG_DIR` 绕开**，那会打开第二份空库。权限问题：检查数据目录，或设 `TTPOS_CONFIG_DIR` 指向可写目录。`warn` 是版本不一致，不阻断 |
| `credentials` | 没有 token 也是 `ok`，登录态只看 `auth`。`warn` 是凭证文件权限不是 0600，按 `fix` 执行 `chmod`。`fail` 看 `detail` |
| `data-dir` | 只会 `ok` 或 `warn`，不受其他项影响。检查目录权限（容器要挂可写卷）。 |
| `auth` | `fail`：请人运行 `ttpos auth login`。`skip`：先解决 `gateway` |
| `shop-context` | `warn`：没配默认商户，属可选项，可用 `ttpos shop use <标识>` 或每次传 `--shop`。`fail`：配置文件损坏，按 `detail` 里的路径修复 |
| `upstream` | 只在 `--network` 时出现。`skip`：先解决 `gateway`、`auth`。`fail`：看 `detail` |

连锁规则：`gateway` 为 `fail` 时 `auth`、`upstream` 跳过；`auth` 不是 `ok` 时 `upstream` 跳过。`gateway` 只是 `warn` 不会触发跳过。

