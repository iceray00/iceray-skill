# 安装 fable5.2-working（写给替用户配置的 AI agent）

通用步骤见仓库根目录的 [INSTALL.md](../INSTALL.md)。这里是这个 skill 特有的部分。每一步都看输出；失败就停下来把原始输出告诉用户，不要绕过。

## 依赖

| 依赖 | 用途 | 检查 |
|---|---|---|
| Claude Code | 主脑会话（建议 Fable 5.2 或 Opus 5.5） | `claude --version` |
| paseo（daemon 在运行） | 启动和管理工人 / 监工 agent | `paseo status` |
| Codex，能用 `gpt-6.2-sol`、`gpt-6.2-astra` | 工人，所有实现都由它做 | `paseo provider models codex` |
| paseo 的 claude provider 下有 `deepseek-flash` | 监工（可选，没有就只能用直接派工） | `paseo provider models claude` |
| `bash`、`jq`、`perl`、`git` | 脚本用到 | `command -v jq perl git` |

缺依赖时不要替用户安装或改它们的配置（模型、密钥、provider），把缺什么告诉用户。

## 安装

```bash
git clone https://github.com/iceray00/iceray-skill.git
bash iceray-skill/install.sh fable5.2-working
```

只是把目录复制到 `<配置目录>/skills/fable5.2-working/`。**不注册钩子，不改 `settings.json`，不往配置目录写任何别的东西** —— 这个 skill 没被调用时，对其他会话没有任何影响。不要自己给它加钩子。

## 验证

```bash
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SK="$CFG/skills/fable5.2-working"

ls -l "$SK/SKILL.md" "$SK/scripts/"      # 文件在，scripts/*.sh 可执行

# 预检 paseo 和模型：在一个临时目录里跑，[FAIL] 表示缺依赖
d="$(mktemp -d)" && bash "$SK/scripts/activate.sh" "$d"; rm -rf "$d"
```

## 装完告诉用户

- 已经开着的 Claude Code 会话要**重启**才会加载这个 skill。
- 用法：在项目里输入 `/fable5.2-working`，或者说“用总管流程”“派给 codex 做”。
- 这个流程会在项目里建一个 `.fable-working/` 目录（计划、账本、brief），并自动把它加进该仓库的 `.git/info/exclude`，不会被提交。
- 上下文压缩后的重读靠 skill 自己的规则和账本开头的指引，不靠钩子。
- 把预检里的 `[warn]` / `[FAIL]` 原样转告用户。

## 手动安装

把 `fable5.2-working/` 整个目录复制到 `<配置目录>/skills/fable5.2-working/`，然后 `chmod +x <配置目录>/skills/fable5.2-working/scripts/*.sh`。

只给单个项目装：复制到 `<项目>/.claude/skills/fable5.2-working/`。脚本都按自己的位置定位，不依赖安装路径。

## 卸载

```bash
rm -rf "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/fable5.2-working"
```

没有别的东西要清理。各项目里的 `.fable-working/` 是工作记录，删不删由用户决定。

## 不要做的事

- 不要改 skill 里的模型名、并发数、重试次数来“适配”环境 —— 环境不满足就告诉用户。
- 不要在安装过程中启动工人或监工 agent；安装只到预检为止。
