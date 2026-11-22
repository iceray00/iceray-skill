# fable5.2-working

多 agent 总管工作流：Claude Code 当主脑做策划和验收，所有实现经 paseo 派给 Codex。

```text
人 ──批准计划 / 回答边界问题──┐
                              ▼
主脑  Claude Code + Fable 5.2 / Opus 5.5
      策划 → 写计划和账本 → 向人提问 → 写 brief → 派工 → 读代码验收 → 接收 / 返工 / 重新计划
          │ paseo                          │ paseo（可选）
          ▼                                ▼
工人  Codex + gpt-6.2-sol / astra  ◀── 监工  Claude Code + deepseek-flash
      所有实现、返工、跑测试            盯工人；429 时让它续做；做完或出别的错就回报主脑
```

- **主脑不写业务代码**，只写 `.fable-working/` 下的计划、账本和 brief；验收靠自己读改动、重跑命令，工人的汇报只当证据。
- **向人提问**：少量问题当场问；成批的边界问题写成 `.fable-working/questions.md` 让多人一起回答。
- **429 自动续做**：`watch.sh` 遇到限流会退避后让同一个工人从中断处继续；其他错误立刻交回主脑。
- **压缩后重读**：规则写在 skill 开头，账本开头也记着 skill 的路径；任务状态都在磁盘上的账本里，压缩不会丢。不注册钩子，不用这个 skill 时对其他会话没有任何影响。
- **返工有上限**：同一任务返工两次不过，就先诊断、换更强的模型，再不行重新计划或问人。

## 安装与使用

```bash
git clone https://github.com/iceray00/iceray-skill.git
bash iceray-skill/install.sh fable5.2-working
```

重启 Claude Code，在项目里输入 `/fable5.2-working`。依赖、验证、手动安装和卸载见 [INSTALL.md](INSTALL.md)。

## 目录

```text
SKILL.md                    主脑规则
scripts/activate.sh         建 .fable-working/、预检 paseo 与模型
scripts/dispatch.sh         派一个 Codex 工人
scripts/supervise.sh        派一个监工，由它去派工人并盯到做完
scripts/watch.sh            守候 agent：429 续做、卡住打断、其他错误返回
templates/                  工人 brief、监工 brief、账本、问题清单
references/research.md      调研 / 对比类任务的证据规则
```

## 致谢

改编自 [ssyram/prompts](https://github.com/ssyram/prompts) 的 `how-to-be-a-chamberlain`。
