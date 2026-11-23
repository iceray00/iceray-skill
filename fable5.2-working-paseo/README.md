# fable5.2-working-paseo

[`fable5.2-working`](../fable5.2-working/README.md) 的 paseo 版：写成 paseo 编排 skill 的样子，和 paseo 自带的 `paseo-advisor`、`paseo-committee`、`paseo-handoff` 同一套约定，装在同样的位置，任何 paseo agent 里输入 `/fable5.2-working-paseo <任务>` 就进入流程。同时防着 paseo 的会话陷阱（见下文和 SKILL.md「Paseo 会话陷阱」）。两个版本可以同时装。

多 agent 总管工作流：调用它的 agent 当主脑做策划和验收，所有实现经 paseo 派给 Codex。

```text
人 ──批准计划 / 回答边界问题──┐
                              ▼
主脑  调用本 skill 的 paseo agent：Claude Code + Fable 5.2 / Opus 5.5
      策划 → 写计划和账本 → 向人提问 → 写 brief → 派工 → 读代码验收 → 接收 / 返工 / 重新计划
          │ paseo run                      │ paseo run（可选）
          ▼                                ▼
工人  Codex + gpt-6.2-sol / astra  ◀── 监工  Claude Code + deepseek-flash
      所有实现、返工、跑测试            盯工人；429 时让它续做；做完或出别的错就回报主脑
```

## 和 `fable5.2-working` 的区别

流程一样。多出来的是 paseo 这一层：

| | `fable5.2-working` | `fable5.2-working-paseo` |
|---|---|---|
| 调用 | `/fable5.2-working` | `/fable5.2-working-paseo [--supervised] [--profile <name>] <任务>`，参数经 `$ARGUMENTS` 传入 |
| 结构 | 按流程顺序写 | paseo skill 的骨架：Prerequisites（先读 **paseo** skill）、Hard rules、Workflow |
| 启动配置 | 固定模型 | 默认还是固定模型；用户点名 `--profile` 时读 paseo 的 agent profile |
| 安装位置 | `~/.claude/skills/` | `~/.claude/skills/` 和 `~/.agents/skills/`（paseo 自带 skill 的两个位置） |
| agent 标题 | `fw:T3`、`fw:T3:supervisor` | `[Worker] T3`、`[Supervisor] T3`（标签一样：`fw=worker` / `fw=supervisor`、`task=<ID>`） |
| 会话陷阱 | 不处理 | 开完 Claude Code 系的 agent 核对会话是否独立、拒绝给共用会话的 agent 发消息、重启后补挂守候和读回分支 |

和 paseo 自带 skill 不一样的一处是有意的：开 agent、发消息、等待只走 `scripts/` 里的命令行脚本，不用工具接口 `create_agent`。理由一是 paseo 的会话陷阱（工具接口开的 Claude Code 子 agent 会写进主脑的会话文件），二是 429 续做和卡住打断都在 `watch.sh` 里，paseo 的完成通知管不了这两件事。后台 `watch.sh` 的退出就是本流程的“完成通知”。

- **主脑不写业务代码**，只写 `.fable-working/` 下的计划、账本和 brief；验收靠自己读改动、重跑命令，工人的汇报只当证据。
- **向人提问**：少量问题当场问；成批的边界问题写成 `.fable-working/questions.md` 让多人一起回答。
- **429 自动续做**：`watch.sh` 遇到限流会退避后让同一个工人从中断处继续；其他错误立刻交回主脑。
- **压缩后重读**：规则写在 skill 开头，账本开头也记着 skill 的路径；任务状态都在磁盘上的账本里，压缩不会丢。不注册钩子，不用这个 skill 时对其他会话没有任何影响。
- **返工有上限**：同一任务返工两次不过，就先诊断、换更强的模型，再不行重新计划或问人。
- **避开 paseo 的会话陷阱**：只用命令行 `paseo run` 开 agent，开完核对会话是否独立，监工回报一次就结束、不搞 `continue` 循环。详见 SKILL.md「Paseo 会话陷阱」。

## 安装与使用

```bash
git clone https://github.com/iceray00/iceray-skill.git
bash iceray-skill/install.sh --agents fable5.2-working-paseo
```

重启 agent，在项目里输入 `/fable5.2-working-paseo <任务>`。依赖、验证、手动安装和卸载见 [INSTALL.md](INSTALL.md)。

它不在 paseo 的安装包里，所以 paseo 设置页的 Skills 列表不会显示它，paseo 升级、同步、卸载自带 skill 时也不会动它。

## 目录

```text
SKILL.md                    主脑规则（paseo skill 格式）
scripts/activate.sh         建 .fable-working/、预检 paseo 与模型
scripts/dispatch.sh         派一个工人（默认 Codex；也接受 provider/模型）
scripts/supervise.sh        派一个监工，由它去派工人并盯到做完
scripts/watch.sh            守候 agent：429 续做、卡住打断、其他错误返回；拒绝给与主脑共用会话的 agent 发消息
scripts/check-session.sh    查 paseo agent 是否和主脑共用 Claude Code 会话文件（--caller / --audit）
scripts/session_branches.py 只读：列出 / 读回一个会话文件里的各条分支（主脑接错分支后找回上下文）
templates/                  工人 brief、监工 brief、账本、问题清单
references/research.md      调研 / 对比类任务的证据规则
```

## 致谢

改编自 [ssyram/prompts](https://github.com/ssyram/prompts) 的 `how-to-be-a-chamberlain`。
