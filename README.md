# iceray-skill

iceray 的 Claude Code skill 合集。每个顶层目录是一个独立的 skill，可以单独安装。

| Skill | 做什么 |
|---|---|
| [`fable5.2-working`](fable5.2-working/README.md) | 多 agent 总管工作流：Claude Code（Fable 5.2 / Opus 5.5）当主脑做策划、提问和验收，实现全部经 paseo 派给 Codex，429 自动续做 |
| [`fable5.2-working-paseo`](fable5.2-working-paseo/README.md) | 上一个的 paseo 加固版：只用命令行 `paseo run` 开 agent、核对子 agent 没有共用主脑的 Claude Code 会话、监工回报一次就结束、重启后补挂守候和读回分支 |

## 安装

```bash
git clone https://github.com/iceray00/iceray-skill.git
bash iceray-skill/install.sh --list            # 看有哪些 skill
bash iceray-skill/install.sh fable5.2-working  # 装其中一个（可写多个，--all 装全部）
```

只复制文件，不改 `settings.json`、不加钩子。skill 会被复制到 `~/.claude/skills/<skill>/`（设了 `CLAUDE_CONFIG_DIR` 则在其下，也可用 `--config-dir` 指定）。装完重启 Claude Code，输入 `/<skill 名>` 使用。

**让 AI 替你装**：把 [INSTALL.md](INSTALL.md) 交给它。各 skill 特有的依赖和验证方法在它自己目录的 `INSTALL.md` 里。

## 仓库约定

```text
<skill 名>/
  SKILL.md        必需。frontmatter 里的 name 与目录名一致
  README.md       给人看的介绍
  INSTALL.md      可选。这个 skill 特有的依赖、验证、卸载（写给 AI）
  ...             脚本、模板、参考资料
install.sh        通用安装脚本
INSTALL.md        通用安装指南（写给 AI）
```

skill 的内容不写死任何机器路径或个人信息：脚本按自己的位置定位，装到哪都能用。
