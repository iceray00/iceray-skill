# 安装 paseo-fable5.2-working（写给替用户配置的 AI agent）

通用步骤见仓库根目录的 [INSTALL.md](../INSTALL.md)。这里是这个 skill 特有的部分。每一步都看输出；失败就停下来把原始输出告诉用户，不要绕过。

## 依赖

| 依赖 | 用途 | 检查 |
|---|---|---|
| paseo（daemon 在运行） | 启动和管理工人 / 监工 agent | `paseo status` |
| Claude Code | 主脑会话（建议 Fable 5.2 或 Opus 5.5） | `claude --version` |
| Codex，能用 `gpt-6.2-sol`、`gpt-6.2-astra` | 工人，所有实现都由它做 | `paseo provider models codex` |
| paseo 的 claude provider 下有 `deepseek-flash` | 监工（可选，没有就只能用直接派工） | `paseo provider models claude` |
| `bash`、`jq`、`perl`、`git`、`python3` | 脚本用到 | `command -v jq perl git python3` |
| paseo 自带的 **paseo** skill | 本 skill 的 Prerequisites 会让主脑先读它（可选，没装也能跑） | `ls ~/.claude/skills/paseo/SKILL.md` |

缺依赖时不要替用户安装或改它们的配置（模型、密钥、provider、paseo 的 skill 选择），把缺什么告诉用户。

## 安装

```bash
git clone https://github.com/iceray00/iceray-skill.git
bash iceray-skill/install.sh --agents paseo-fable5.2-working
```

paseo 自带的 skill 装在两个位置，这条命令照样各放一份：

- `<Claude Code 配置目录>/skills/paseo-fable5.2-working/` —— Claude Code agent 读这里（配置目录取 `$CLAUDE_CONFIG_DIR`，未设置则 `~/.claude`，也可用 `--config-dir` 指定）。
- `~/.agents/skills/paseo-fable5.2-working/` —— Codex 等 provider 读这里。只在 Claude Code 里用的话，去掉 `--agents` 就不装这一份。

两处是两份拷贝，更新时重跑同一条命令。

**不注册钩子，不改 `settings.json`，不改 paseo 的配置** —— 这个 skill 没被调用时，对其他会话没有任何影响。不要自己给它加钩子。

**不要把它放进 paseo 的安装包**（`@getpaseo/server` 里的 `skills/` 目录），也不要写 `.paseo-managed-files.json`：那里的东西归 paseo 管，升级会整个换掉。本 skill 的名字不在 paseo 管理的名单里，paseo 同步、卸载自带 skill 时不会碰它。

## 验证

```bash
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SK="$CFG/skills/paseo-fable5.2-working"

ls -l "$SK/SKILL.md" "$SK/scripts/"      # 文件在，scripts/*.sh 可执行
ls ~/.agents/skills/paseo-fable5.2-working/SKILL.md    # 用了 --agents 时

# 预检 paseo 和模型：在一个临时目录里跑，[FAIL] 表示缺依赖
d="$(mktemp -d)" && bash "$SK/scripts/activate.sh" "$d"; rm -rf "$d"

# 会话共用情况（只读）：[warn] 原样转告用户
bash "$SK/scripts/check-session.sh" --audit
```

`check-session.sh` 读 `$PASEO_HOME/agents/`（未设置时是 `~/.paseo/agents/`）；paseo 的 home 不在默认位置时，确认 `PASEO_HOME` 在 agent 的环境里。

## 装完告诉用户

- 已经开着的 agent 会话要**重启**才会加载这个 skill。
- 用法：在 paseo agent 里输入 `/paseo-fable5.2-working <任务>`，或者说“用总管流程”“派给 codex 做”。可选参数：`--supervised`（任务都交给监工盯）、`--profile <name>`（工人用 paseo 里配好的某个 agent profile 启动）。
- 这个流程会在项目里建一个 `.fable-working/` 目录（计划、账本、brief），并自动把它加进该仓库的 `.git/info/exclude`，不会被提交。
- 上下文压缩后的重读靠 skill 自己的规则和账本开头的指引，不靠钩子。
- 它不会出现在 paseo 设置页的 Skills 列表里（那里只列 paseo 安装包自带的）。
- 把预检里的 `[warn]` / `[FAIL]` 原样转告用户。

## 手动安装

把 `paseo-fable5.2-working/` 整个目录复制到 `<配置目录>/skills/paseo-fable5.2-working/`（需要时再复制一份到 `~/.agents/skills/paseo-fable5.2-working/`），然后给两处的 `scripts/*.sh` 加可执行权限。

只给单个项目装：复制到 `<项目>/.claude/skills/paseo-fable5.2-working/`。脚本都按自己的位置定位，不依赖安装路径。

## 卸载

```bash
rm -rf "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/paseo-fable5.2-working" ~/.agents/skills/paseo-fable5.2-working
```

没有别的东西要清理。各项目里的 `.fable-working/` 是工作记录，删不删由用户决定。

## 不要做的事

- 不要改 skill 里的模型名、并发数、重试次数来“适配”环境 —— 环境不满足就告诉用户。
- 不要在安装过程中启动工人或监工 agent；安装只到预检为止。
