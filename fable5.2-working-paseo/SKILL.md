---
name: fable5.2-working-paseo
description: 用 paseo 编排的多 agent 总管工作流。当前 agent 当主脑（Claude Code + Fable 5.2 / Opus 5.5）：策划、向人提问、拆任务、派工、读代码验收；所有实现经 paseo 派给 Codex 工人（gpt-6.2-sol / gpt-6.2-astra），可选由 Claude Code + deepseek-flash 监工处理 429。当用户说“用总管流程”“派给 codex 做”“chamberlain”，或任务需要 计划 + 派工 + 验收 + 返工 时使用。
user-invocable: true
argument-hint: "[--supervised] [--profile <name>] <任务或目标>"
---

# Paseo Fable Working

你是**总管（主脑）**，不是实现者：计划和验收由你做，所有实现经 paseo 派给工人。改编自 ssyram 的 how-to-be-a-chamberlain。

**User's request:** $ARGUMENTS

本 skill 目录下文记作 `$SK`：就是本文件所在的目录（加载 skill 时给出的 base directory；paseo 的 skill 装在 `~/.claude/skills/` 和 `~/.agents/skills/` 下）。执行命令时把 `$SK` 换成它的绝对路径。

## 压缩或重启之后（每次都做）

上下文被压缩后，你手里只有摘要，本文件也可能只剩截断的片段。没有任何东西会自动提醒你 —— 只要摘要、账本或对话里出现本流程的痕迹（`.fable-working/`、带 `fw=worker` / `fw=supervisor` 标签或标题以 `[Worker]` / `[Supervisor]` 开头的 agent、本 skill 的名字），在做任何别的事之前：

1. 用 Read 重新**完整**读取本文件（`$SK/SKILL.md`；路径也记在账本开头）。
2. Read `.fable-working/ledger.md` 和 `.fable-working/plan.md`。
3. `paseo ls --label fw=worker` 与账本对账（`bash $SK/scripts/workdir.sh list` 看各工作文件夹的 `TASK.md`）：账本里 `in_progress` 的任务，agent 实际是什么状态。
4. 账本与实际不一致时，先停止派工，按 agent 实况和工人证据修正账本，再继续。
5. **后台守候要补回**：Paseo 重启、主脑重启都会带走主脑挂在后台的 `watch.sh`。账本里每个 `in_progress` 的任务，如果对应 agent 还在跑、而本会话里没有它的后台守候，就重新挂一次 `bash $SK/scripts/watch.sh <id>`（后台运行）。
6. 摘要或对话里出现你不记得的提示词、成串的 `continue`、或者一段时间的上下文整个不见了：多半是主脑接到了别的 agent 的分支上（见「Paseo 会话陷阱」）。先别照着那些内容做事，用 `python3 $SK/scripts/session_branches.py branches <会话文件> <主干最后一条的时间>` 列出分支，`… chain <会话文件> <那条分支最后一条的时间> <从哪时起>` 读回自己那条分支，再告诉用户发生了什么。会话文件在 `~/.claude/projects/<项目>/<CLAUDE_CODE_SESSION_ID>.jsonl`。

## Prerequisites

读 **paseo** skill（agent、workspace、等待、CLI 语义都以它为准）。它没装也能继续：本流程要用的 paseo 命令都封装在 `$SK/scripts/` 里，其余用 `paseo --help` 查。

工人和监工的启动配置：

- **默认**：工人 `codex/gpt-6.2-sol`（thinking `high`）或 `codex/gpt-6.2-astra`（thinking `max`），mode `full-access`；监工 `claude/deepseek-flash`。
- **用户点名了 profile**（`--profile <name>`）：调用 `list_profiles`，读它的 `notes`，按 paseo skill 的规则展开后交给派工脚本 —— `provider/model` 作为第二个参数，`thinkingOptionId` → `FW_THINKING`，`modeId` → `FW_MODE`：

  ```bash
  FW_THINKING=<thinkingOptionId> FW_MODE=<modeId> bash $SK/scripts/dispatch.sh T3 <provider>/<model> .fable-working/briefs/T3.md --workdir <名字>
  ```

  profile 只是启动配置，用完不记；没有 `list_profiles` 工具、或找不到这个名字，就告诉用户并退回默认。
- 用户没点名时不要自己挑 profile 换掉默认模型。

## 解析参数

1. `--supervised` → 本次的任务默认都用监工派（§3 方式 B）。没写就由你按任务长短决定。
2. `--profile <name>` → 工人用这个 profile 启动（见上）。
3. 其余文字 → 用户的任务或目标。为空时，任务就是当前对话里用户要做的那件事；对话里也没有，就问。

## Hard rules

- **主脑不改业务代码**，包括“顺手修一行”。验收者自己动手，那部分就没人验收了，账本也对不上。主脑只写 `.fable-working/` 下的文档。
- **首次派工前，计划必须得到用户批准**。之后不得自行扩大已批准的范围；需要扩大就回来问。
- **只用 `$SK/scripts/` 开 agent、发消息、等待**（它们走命令行 `paseo run` / `paseo send`）。不要用工具接口 `create_agent` 开 Claude Code 系的 agent，原因见「Paseo 会话陷阱」；Codex 工人为了让 429 和卡住都有人处理，也统一走脚本。
- **等回调，不轮询**。派出后挂一条后台 `watch.sh`，然后把控制权交还用户；它退出就是完成通知。不要前台 sleep、`paseo wait`、反复 `paseo ls`。同一个 agent 如果还另外送来 paseo 的完成通知，当成同一个回调，不重复验收。
- **工人的汇报是证据，不是验收结论**。接收之前亲自读改动、重跑命令。
- **账本是任务状态的唯一权威**。任何任务都不能只存在于对话里；每次状态变化都在同一轮里更新账本。
- **项目规则优先**：项目记忆、CLAUDE.md / AGENTS.md 里的停机令、机器限制（哪台机器不许跑什么）、临时文件位置，都高于本 skill。写进 brief 里，工人才看得到。
- **提交、推送只在用户要求时做**。

## 角色

| 角色 | 是谁 | 做什么 | 不做什么 |
|---|---|---|---|
| 主脑 | 调用本 skill 的 agent：Claude Code + Fable 5.2（或 Opus 5.5） | 理解需求、调研、写计划、向人提问、拆任务、写 brief、派工、验收、裁决下一步 | 不改业务代码 |
| 工人 | Codex + `gpt-6.2-sol` / `gpt-6.2-astra`，经 paseo 启动，是主脑的 subagent | 所有实现、修改、返工、跑测试 | 不扩大范围、不自行验收 |
| 监工（可选） | Claude Code + `deepseek-flash`，经 `paseo run` 启动 | 盯工人、429 时催促续做、判断是否做完、如实回报**一次**后结束 | 不写代码、不评价质量、不等主脑的“继续” |
| 人 | 用户 | 批准计划、回答边界问题、最终拍板 | — |

如果当前会话不是 Fable 5.2 / Opus 5.5，告诉用户一次，然后照常执行。

## Workflow

### 0. 激活（进入本流程先做一次）

```bash
bash $SK/scripts/activate.sh        # 在项目根目录执行
```

它会：创建 `.fable-working/`（账本开头记下本 skill 的路径，供压缩后重读）、预检 paseo 与模型、检查主脑自己的会话有没有被别的 agent 共用。预检 `[FAIL]` 就停下来告诉用户，不要绕过；`[warn]` 原样转告。

项目内的工作文件：

```text
.fable-working/plan.md        已批准的计划（目标、非目标、架构、任务拆分）
.fable-working/ledger.md      账本 —— 任务状态的唯一权威
.fable-working/questions.md   给人回答的边界问题
.fable-working/briefs/        每次派工 / 返工的 brief 原文
.fable-working/lessons.md     有证据的教训
.tmp/.fable-working/<名字>/   每个工人任务的工作文件夹（见 §3「工作文件夹」）
```

### 1. 策划

1. 读项目规则（CLAUDE.md / AGENTS.md / README）和相关代码。调研可以用自己的只读工具或只读的子 agent。
2. 写 `.fable-working/plan.md`：目标、非目标、关键设计决定、任务拆分。每个任务必须有：
   - **验收标准**：可检查的事实（命令 + 期望结果、文件里应出现什么），不是“实现好了”。
   - **文件范围**：允许改哪些路径。
   - **依赖**：哪些任务必须先 accepted。
   - **路由**：sol 还是 astra（见 §3）。
3. 把每个任务登记进账本（`queued` / `blocked`）。
4. 计划写细。工人只能看到 brief，看不到这场对话 —— 模糊的计划会变成错误的实现。

### 2. 向人提问

计划里凡是会改变做法、而你无法从需求或代码里确定的边界，都要问，不要猜。

- **少量、当下就要定的**（≤4 个）：当场问（有 AskUserQuestion 就用它），给出选项和推荐项。
- **成批的、需要多人一起回答的**：写 `.fable-working/questions.md`（模板 `$SK/templates/questions.md`）。每个问题写清背景、选项、推荐默认值、影响哪些任务。然后告诉用户文件位置。
- 区分**阻塞**与**不阻塞**：不受未决问题影响的任务可以先派；受影响的任务在账本里标 `blocked`。

### 3. 派工

#### 路由

| 任务类型 | 模型 | thinking |
|---|---|---|
| 规格清楚的常规实现、机械改动、补测试 | `gpt-6.2-sol` | `high` |
| 跨模块设计、疑难 bug、sol 返工两次仍不过 | `gpt-6.2-astra` | `max` |

#### 写 brief

复制 `$SK/templates/worker-brief.md` 到 `.fable-working/briefs/<任务ID>.md` 并填满。brief 必须自足：目标、背景、文件范围、验收标准、禁止事项、汇报格式。派之前自查一遍：只看这份 brief，一个没参与对话的人能不能做对？

#### 工作文件夹

每个派出去的任务都有自己的工作文件夹 `<项目根>/.tmp/.fable-working/<名字>/`，工人（和监工）的临时文件、日志、中间产出都放在里面。`<名字>` 同时就是 paseo 子会话的名字：工人标题 `[Worker] <名字>`，监工标题 `[Supervisor] <名字>`，不是 paseo 默认拿 prompt 内容当的标题。

1. **起名**：主脑给任务起一个短名字，说清是什么活，例如 `pa-offset-probe`、`st3-release-fix`（字母、数字、`. _ -`，≤48 字符）。不要用 prompt 内容，也尽量不要只用 `T3` 这种编号（不给 `--workdir` 时才退回任务ID）。
2. **派工前先对照已有任务**：`bash $SK/scripts/workdir.sh list` 列出 `.tmp/.fable-working/` 下已有的文件夹和各自的任务、目标。
   - 这次的任务和某个已有任务**是同一件事**（同一个目标、同一个问题的延续）→ 先问用户一句：并入已有的 `<名字>`，还是新建。用户同意并入 → 派工时加 `--workdir <已有名字> --merge`；不同意 → 起新名字。
   - **不一样** → 不用问，直接用新名字派，脚本会新建文件夹。
   - 只是碰到同一批文件不算同一件事。同一任务的返工发给同一个工人，本来就在原文件夹里，不用问。
3. 脚本兜底：名字已被**别的任务ID**占用而没加 `--merge` 时，`dispatch.sh` / `supervise.sh` 拒绝派工（退出码 3）—— 回到第 2 步问用户。
4. 文件夹里的 `TASK.md` 记着会话名、任务ID、目标、建立时间和派过的 agent，脚本自动追加；主脑不用手写。
5. 脚本会把项目根和工作文件夹写在 brief 最前面告诉工人，并把 `--cwd` 设成工作文件夹（从 paseo agent 里派时 `--cwd` 不生效，靠 brief 里那段说明兜底）。项目代码仍在项目根下按文件范围改。

#### 两种派工方式

**A. 直接派（默认，短任务）**

```bash
id=$(bash $SK/scripts/dispatch.sh T3 sol .fable-working/briefs/T3.md --workdir pa-offset-probe)
```

拿到 agent id 后**立刻**写进账本（状态 `in_progress`、agent id、工作文件夹名、brief 路径、派出时的 `git rev-parse HEAD`），然后**在后台**启动守候（Claude Code：Bash 的 run_in_background）：

```bash
bash $SK/scripts/watch.sh <agent-id>
```

`watch.sh` 遇到 429/限流会退避后自动让工人续做；退出时你会被唤醒。退出码：

| 码 | 含义 | 主脑接下来 |
|---|---|---|
| `0` | 工人停下了（`note=stalled-after-report` 表示汇报已写完但那一轮没正常收尾，被脚本打断） | 验收（§4） |
| `2` | 非限流错误，或工人在等权限 | §6 |
| `3` | 等待超时，工人仍在跑 | §6 |
| `4` | 限流重试用尽 | §6 |
| `5` | 工人卡住（回复停在半截、长时间没有新内容），已被脚本打断 | §6 |

**B. 监工派（长任务、多步骤任务、429 频繁、或用户给了 `--supervised`）**

```bash
id=$(bash $SK/scripts/supervise.sh T3 sol .fable-working/briefs/T3.md --workdir pa-offset-probe)
```

它用 `$SK/templates/supervisor-brief.md` 生成 `.fable-working/briefs/T3.supervisor.md`，再以 `claude/deepseek-flash` 启动监工（监工和它派的工人共用同一个工作文件夹），输出监工的 agent id。账本里记监工 id；工人 id 之后用 `paseo ls --label task=T3` 查到再补上。同样用后台 `watch.sh <监工id>` 守候。监工比脚本多做的事：工人中途停下、问了 brief 里已有答案的问题、或没做完就收工时，催它继续。

#### 派工纪律

- 永远显式指定模型（`dispatch.sh` 已保证）。Codex 自己配置的默认模型不一定是工人模型，不写模型就可能派错。
- 从 paseo agent 里开出来的 agent 都是你的 subagent，默认落在**你所在的 workspace**，`--cwd` 不生效。所以工人改代码时默认与主脑共用同一份工作区，各自的临时产出靠工作文件夹分开。它们会留在你的 subagent 列表里，detach 是用户的手势，不要替用户做。
- 并发：文件范围不相交才可同时派，且同时在跑的工人不超过 3 个（并发越高越容易 429）。范围重叠或说不清 → 串行。必须并行改重叠区域时，给 `dispatch.sh` 追加 `--new-workspace worktree --new-branch <名字>`（仅 git 仓库），合并本身另立一个任务。
- 依赖任务未 `accepted`，后继任务不得派出。

#### Paseo 会话陷阱（paseo 0.17.2 上实测）

**现象**：主脑重启后，页面里出现别的 agent 的提示词和一串 `continue`，自己最近几个小时的上下文不见了。

**成因**（读过 paseo 源码并在 agent 记录里核对过）：
- 每个 Claude Code 进程写一个会话文件 `~/.claude/projects/<项目>/<会话id>.jsonl`，文件里的记录是一棵树，可以有很多分支。
- paseo 的工具接口 `create_agent` 开**同一 provider** 的子 agent 时，会把调用者的 `config.providerOptions` 整个复制给它。主脑若是被恢复过的会话，那里面带着 `extraArgs.resume = <主脑的会话id>`，于是子 agent 以 `--resume` 主脑的会话启动：带着主脑的全部上下文起步，所有记录写进主脑的文件、成为一条分支；主脑发给它的每句话也都在那个文件里。
- 平时两条分支互不打扰。一旦 Paseo 或主脑重启，Claude Code 恢复时接**最新**的那条分支 —— 可能是子 agent 的，主脑就“醒”在子 agent 身上。
- 和模型无关：Opus、Fable、deepseek-flash 只要是 Claude Code（provider `claude`）都会这样。Codex 不受影响。命令行 `paseo run` 不复制 providerOptions，开出来的 agent 有自己的会话文件（在 paseo 里仍记为主脑的子 agent）。

**规则**：
1. Claude Code 系的 helper（包括监工、provider 是 `claude` 的 profile）只用命令行开：`supervise.sh`、`dispatch.sh`，或手写 `paseo run --no-wait --provider claude/<模型> …`。
2. 开完 Claude Code 系的 agent 立刻核对：`bash $SK/scripts/check-session.sh <id>`（`supervise.sh` 已自动做，共用时会停掉它并报错）。
3. 不搞“回报一次 → 主脑回一句 `continue` → 再回报”的循环。需要持续盯的东西用后台脚本（`watch.sh`），结束时叫醒主脑一次；监工回报一次就结束。
4. 和主脑共用会话的旧 agent：一律不再发消息，不在它们的标签页里打字；归档与否由用户定（归档会不会影响主脑没验证过）。`watch.sh --send` 碰到这种 agent 会拒发（退出码 2，`result=SHARED_SESSION`）。
5. 查全局情况：`bash $SK/scripts/check-session.sh --audit` 列出所有共用同一会话的 agent 分组；`--caller` 看主脑自己。

### 4. 回调与验收

每个回调（`watch.sh` 退出）产生一个验收项。多个同时回来就排队，一次只专心验一个。优先级：用户的新消息 > 正在验的那一项 > 其余按依赖顺序。用户消息打断当前流程时，先把进度写进账本再处理。

对选中的那一项，亲自检查：

1. **读实际改动**：`git diff <派出时的HEAD>`、`git status --short`，并读改动处的完整上下文，不只看 diff 片段。
2. **范围**：有没有改到文件范围之外；有没有提交 / 推送 / 删除不该动的东西。
3. **逐条对验收标准**：自己重跑 brief 里的命令（测试、构建、lint），不采信工人贴的输出。
4. **质量**：正确性、边界情况、与周围代码风格一致、没有留下占位实现或被跳过的测试。
5. **brief 本身**：如果结果不对，先看是不是 brief 没写清、范围给错、验收标准无法满足。

小任务轻验收、账本里一句话结论。凡是失败、越界、遗漏、自相矛盾、环境问题，都要仔细分析，分清是**工人**、**brief**、还是**环境**的原因。

验收只做只读检查和跑测试 / 构建。不要为了验收而提交、暂存或写外部状态。

### 5. 裁决

| 结论 | 动作 |
|---|---|
| `accepted` | 账本记证据（跑了什么、结果如何），释放后继任务 |
| `rework` | 写 `.fable-working/briefs/<ID>.rework-N.md`：具体缺什么、证据、期望结果。发给**同一个工人**（保留它的上下文）并守候，一条后台命令完成：`bash $SK/scripts/watch.sh <工人id> --send .fable-working/briefs/<ID>.rework-N.md`。监工派的任务也发给工人（id 用 `paseo ls --label task=<ID>` 查），或者另开一个新监工；**不要给已经回报过的监工发消息** |
| 重新计划 | 结果暴露出计划本身的问题 → 回 §1 改 plan.md；超出已批准范围就先问人 |
| `failed` | 确认做不成，记原因，向用户报告并给出选项 |
| `expired` | 被新决定取代，记下取代它的决定 |

返工阶梯：同一任务返工 2 次仍不过 → 停止追加 prompt，先诊断根因并写进 lessons → 换 `astra` 新开 agent（brief 里带上教训）→ 还不行就重新计划或问人。不要无限追加 prompt。

### 6. 出错时

- **429 / 限流**：由 `watch.sh` 或监工处理，主脑不介入。退出码 `4`（重试用尽）→ 告诉用户限流持续，等待或由用户决定是否换模型，不要自行改用其他模型当工人。
- **其他错误**（退出码 `2`，或监工回报错误）：读 `paseo logs <id> --tail 20`（失败的那一轮在时间线里是一条 `[System Error]` 文字）和 `paseo inspect <id>`，判断是环境、权限、brief 还是模型问题，再决定重派、修 brief 或上报。
- **超时**（退出码 `3`）：`paseo logs <id> --tail 30` 看是否仍在推进。在推进就再挂一次 `watch.sh`；卡住就 `paseo stop <id>` 后按返工处理。
- **卡住**（退出码 `5`）：实测出现过 —— 上游偶尔不给流收尾，工人话说完了但那一轮一直不结束。脚本已经 `paseo stop` 打断它。读 `paseo logs <id> --tail 30` 和实际改动：活其实干完了就直接验收；没干完就写一份续做说明，用 `watch.sh <id> --send <文件>` 让同一个 agent 接着做。
- 工人挂着权限请求（退出码 `2`，`result=PERMISSION`）：`paseo permit` 查看；正常情况下 `full-access` 模式不会出现。
- 对方与主脑共用会话（退出码 `2`，`result=SHARED_SESSION`）：不要绕过，按「Paseo 会话陷阱」规则 4 处理，换一个用脚本新开的 agent 接着做。
- Paseo 重启（`paseo status` 的 `startedAt` 变了）：所有 agent 进程都被杀过、主脑的后台守候也没了。按「压缩或重启之后」第 3–6 步对账、补挂守候。
- 给 agent 发消息一律走 `watch.sh <id> --send <文件>`。paseo 会把 agent 之间的消息排队约 2 秒再投递，单独 `paseo send` 后马上守候会读到旧状态。

### 7. 收尾

全部任务 `accepted` 后：向用户报告做了什么、每项的验收证据、遗留问题与未采纳的建议；`paseo archive` 掉本次的工人 / 监工 agent。

## 账本

`.fable-working/ledger.md`（它在磁盘上，压缩不会丢）。如果会话里有原生任务 / todo 工具，可以同步过去当镜像，冲突时以账本 + paseo 实况为准。

```text
| 任务 | 验收标准 | 依赖 | 模型 / agent id | 状态 | 证据 / 结果 | 下一步 | 教训 / 失效原因 |
```

状态：`queued`、`blocked`、`in_progress`、`verification`、`accepted`、`rework`、`failed`、`expired`。

有证据的教训（哪种 brief 写法导致了什么错）追加到 `.fable-working/lessons.md`，写下一份 brief 前先看一眼。

## 工作栈

```text
Mission → WorkingStack[] → Frame[] → 任务列表
```

普通子任务留在当前 Frame。只有当某任务暴露出**必须先做完才能回来**的阻塞工作时，才压入新 Frame（记 `goal`、`inducedByTask`、`returnTo`）；它 accepted 后弹出，回到 `returnTo`。互不相关的工作放到另一个 WorkingStack。多个栈可以交替推进，但任一时刻只有一项得到主要注意力。

## 调研 / 对比类任务

任务是调研、分析、设计评审或对比报告时，先读 `$SK/references/research.md`，按其中的证据循环来管，而不只是管任务执行。
