# 账本

> 任务状态的唯一权威。每次派工、验收、返工、状态变化都在同一轮里更新。
> 状态：queued / blocked / in_progress / verification / accepted / rework / failed / expired
> 上下文压缩之后：先重读 <SKILL_DIR>/SKILL.md，再读本账本和 .fable-working/plan.md，然后才继续。

- 项目：<路径>
- 计划：.fable-working/plan.md（批准于 <日期>）
- 当前焦点：<正在验收或等待的那一项>

## 任务

| 任务 | 验收标准 | 依赖 | 模型 / agent id | 状态 | 证据 / 结果 | 下一步 | 教训 / 失效原因 |
|---|---|---|---|---|---|---|---|
| T1 <标题> | <可检查的事实> | — | — | queued | — | 写 brief | — |

## 派工记录

| 时间 | 任务 | 方式 | agent id | 工作文件夹（.tmp/.fable-working/…） | brief | 派出时 HEAD | 结果 |
|---|---|---|---|---|---|---|---|

## 工作栈

- Stack A：Frame 1 — goal: <目标>；inducedByTask: —；returnTo: —

## 未决问题

- <问题> → 阻塞：<任务>；见 .fable-working/questions.md
