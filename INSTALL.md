# 安装指南（写给替用户配置的 AI agent）

这个仓库是一组 Claude Code skill，每个顶层目录是一个 skill（目录里有 `SKILL.md`）。你正在帮用户把其中一个或几个装到本机。按顺序做，每一步都看输出；失败就停下来把原始输出告诉用户，不要绕过。

## 1. 确认装哪个

```bash
git clone https://github.com/iceray00/iceray-skill.git
bash iceray-skill/install.sh --list
```

用户没说装哪个就问，不要默认全装。

## 2. 先读这个 skill 自己的说明

如果 `iceray-skill/<skill>/INSTALL.md` 存在，先读它：里面有这个 skill 的依赖、装完要验证什么、要告诉用户什么。有冲突时以它为准。

## 3. 安装

```bash
bash iceray-skill/install.sh <skill>          # 可以一次写多个；--all 装全部
```

它只做一件事：把 `<skill>/` 复制到 `<配置目录>/skills/<skill>/`（已有同名安装会被覆盖）。配置目录取 `$CLAUDE_CONFIG_DIR`，未设置则是 `~/.claude`；也可以用 `--config-dir <目录>` 指定。用户的 Claude Code 不用默认配置目录时，先确认是哪个再装。

加 `--agents` 会另外复制一份到 `~/.agents/skills/<skill>/`（paseo 自带的 skill 也装在这里，Codex 等 provider 从这里读）。只在该 skill 的 `INSTALL.md` 这样写、或用户要求时才加。

安装不改 `settings.json`，不注册钩子，不动其他 skill。

## 4. 验证

```bash
ls "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/<skill>/SKILL.md"
```

再按该 skill 的 `INSTALL.md` 里的“验证”一节检查。

## 5. 告诉用户

- 装了哪些 skill、装在哪。
- 已经开着的 Claude Code 会话要**重启**才会加载新 skill；之后输入 `/<skill 名>` 使用。
- 验证时出现的所有 `[warn]` / `[FAIL]`，原样转告。

## 手动安装（不能跑 install.sh 时）

把 `<skill>/` 整个目录复制到 `<配置目录>/skills/<skill>/`，并给其中的 `*.sh` 加可执行权限。只给单个项目装则复制到 `<项目>/.claude/skills/<skill>/`。

## 不要做的事

- 不要为了装 skill 去改用户的 `settings.json`、加钩子或加权限规则，除非该 skill 的 `INSTALL.md` 明确要求且用户同意。
- 不要替用户安装缺失的依赖或改它们的配置（模型、密钥、provider）；缺什么就告诉用户。
- 不要为了“适配环境”修改 skill 的内容。
