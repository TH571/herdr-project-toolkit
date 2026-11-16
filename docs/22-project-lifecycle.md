# 22. 项目生命周期：初始化、产物落地与删除

> 本文原是作者本地教程的一章，收录为本项目的设计说明，已做脱敏处理。
> 文中 `<工作区根>`、`<存储区根>`、`<机器标识>` 是占位符，含义见 [README](../README.md#配置)。
> 坑清单编号（BB–BI）沿用原教程的连续编号，不必在意跳跃。

> [!info] 本章前提（2026-11-16 实测）
> 本章描述的是一套已经在本机跑通的工具链：`new-project 1.9.0`（建项目）、`delete-project 1.2.0`（删项目）、`skills-sync 2.0.0`（分发技能）。三个结论都经实测：**①** 产物规则写在项目里的 `AGENTS.md`，agent 直接写存储区、不问用户；**②** Herdr 空间的 `folder` 建后不可改，命令集里没有 `set_folder`；**③** 删除时若在项目自己的终端里执行，会因「移走 cwd + 关闭所在空间」而中途被杀，什么都没发生。

## 一、三区模型：工作区、存储区、空间各管一件事

| 区 | 位置 | 放什么 | 是否同步 |
|---|---|---|---|
| **工作区** | `<工作区根>/<项目>` | 代码、草稿、日志、缓存、中间数据 | 否，本地盘 |
| **存储区** | `<存储区根>/<项目>@<机器标识>` | **所有交付物** | 是，群晖备份 |
| **Herdr 空间** | `docs.json` 里的 `spaces[].folder` | 只是「终端从哪起」 | 否 |

三者职责不重叠：**工作区可整目录删除**（产物已在存储区），**存储区是成品唯一所在**，**空间只负责让你一眼看见谁在跑**。混在一起就会出现「删了工作区把交付物一起删了」这类事故。

## 二、new-project：一条命令做完六件事

```sh
new-project 客户月报 --git
```

| 产物 | 作用 |
|---|---|
| `src/ tmp/ logs/` | 过程文件的家，明确「这里的东西不进存储区」 |
| `AGENTS.md` | 项目约定：三区职责、硬规则、产物判定表、收尾。**规则随项目走** |
| `.gitignore` | 已排除 `.claude/settings.local.json`、aider 历史、`node_modules`、`DONE` |
| `PROGRESS.md` | 跨轮状态：已完成 / 下一步 / 卡点，三段空模板 |
| `.claude/settings.json` | `permissions.additionalDirectories` 写入存储区，Claude 不再反复要授权 |
| 存储区 `OWNER` | 记录 `machine` / `hostname` / `store_dir`，标明这个目录归哪台机器 |
| Herdr 空间 | 同名空间，`folder` 指向工作区；同名已存在则跳过 |

常用开关：`--git`、`--no-space`（不建空间）、`--readonly`（存储区建好即只读）、`--dry-run`（只预览）、`--force`（只补缺失文件，不覆盖）、`--machine`（换机器标识）。

## 三、存储区命名：机器标识不是主机名

目录名形如 `my-project@mac-a`。后缀是**机器标识**，来自 `~/.config/new-project/machines.conf` 的主机名映射：

```
my-macbook=mac-a
my-macbook=mac-a
imac-7.local=iMac-7
imac=iMac-7
```

为什么不直接用主机名：`my-macbook` 又长又难认，而「存储区根」下已有 `mac-a` / `iMac-7` / `mac-b` 这套目录名。映射表把两者分开，目录可读、脚本可查。

> [!danger] 同步不等于合并
> 两台机器各写 `@mac-a` 和 `@iMac-7`，同步时不再抢同一个目录，冲突副本基本消失。**但代价是**同一项目的产物会分成两份，要合并得手动挑文件。分区解决的是「互相覆盖」，不解决「自动合并」。

## 四、产物判定：规则写在项目里，且禁止询问

早期版本让 agent「先写工作区，再问用户这是不是产物」——结果是每条指令都要人确认一次，而且判断标准每次都不一样。现在的做法是**先定规则，再让 agent 自己判**：

| 是产物 → 直接写存储区 | 不是产物 → 留工作区 |
|---|---|
| 文档/报告（`.md .docx .pdf` 成品） | 草稿、废稿、试验版本 |
| 数据表（`.xlsx .csv` 结果表、台账） | 日志、缓存、`__pycache__`、`node_modules` |
| 演示/图表（`.pptx`、导出的 `.png .svg`） | 中间数据、原始素材、解压临时目录 |
| 成品页面/程序、可复用工具脚本 | 一次性迁移/调试脚本 |

三条硬规则写进 `AGENTS.md`：**①产出即写存储区**，不许先写工作区再复制；**②禁止询问**「这是不是产物」；**③判不了就写存储区 `_待确认/`**，宁可多存，不要打断用户。

> [!success] 实测证据
> 项目 `proj-b` 里让 agent 产出 `report.md`，结果该文件**只出现在存储区**，工作区顶层没有副本。对照早期项目 `proj-a`：`notes.md` 在工作区与存储区各一份、mtime 完全相同（`cp -p` 保留时间戳的特征），说明那份是「先写工作区再被复制」——两种结果一比，规则是否生效一目了然。

**为什么最终没保留自动兜底**（曾有一个按扩展名白名单扫描复制的 `sync`）：兜底制造了两个判断者——规则一套、白名单一套，冲突时人不知道信谁；而且扩展名启发式会把 `说明.md` 当产物、漏掉 `.numbers`，维护面越滚越大。删掉之后只剩一条链路，写错就是写错，`git status` 一眼可见。

## 五、Herdr 空间：folder 在创建瞬间定格

> [!danger] 没有「全局初始文件夹」这个设置
> 初始目录绑在**空间**上，不在偏好设置里。位置是 `~/.local/state/herdr-core/default/docs.json` 的 `spaces[].folder`。App 里点 `+` 新建空间时，对话框**只问名字**，folder 默认取「当前聚焦终端的目录」——官方说明原文：*the folder its terminals start in (default: the focused terminal's)*。

两条必须记住的规则：

1. **folder 建后不可改。** 命令集只有 `space.new / rename / colors / move / select / next / prev / close`，**没有 `set_folder`**。要换目录只能 close 后重建，而 close 会结束空间里所有终端。
2. **终端自己的 cwd 独立于空间 folder。** 在终端里 `cd` 只改该终端的 `cwd`（记在 `terminals.json`），空间的 folder 不动。所以「先建空间再 cd」不会让空间指向新目录，顺序必须是「先 cd 到目标 → 再建空间」，或者干脆用命令行指定。

```sh
# 直接指定目录建空间（推荐，不用先 cd）
herdr-app do space.new --name 客户月报 --folder "$HOME/Projects/my-project"

# 可选参数：起一个 agent、给它首句任务、不抢焦点
herdr-app do space.new --name X --folder /abs/path --argv '["zsh"]' --focus false

# 关闭空间（会结束里面的终端）
herdr-app do space.close --id <空间id> --confirmed true
```

**命令行不继承当前目录**：不带 `--folder` 时脚本路径落到该机器的家目录（官方原文 *this computer for scripts … its terminals start in that machine's home unless folder*），所以命令行建空间务必显式给绝对路径。

推荐用法是「孵化器 + 一项目一空间」：`init` 空间的 folder 永远停在 `<工作区根>`，用它发起新项目；项目建好后 `new-project` 自动给它建一个同名空间，folder 指向该项目。

## 六、删除项目：三个动作，四道闸

`delete-project <项目>` 一次做三件事：工作区移入回收站、存储区移入回收站、关闭 Herdr 空间。四道闸保证不误删：

| 闸 | 行为 |
|---|---|
| 只读清单 | 不加 `--yes` 只打印：路径、大小、文件数、空间终端数、风险项 |
| 风险预检 | git 未提交改动 / 零提交 / 无 `DONE` / 空间有活动终端，逐条告警 |
| 不使用 `rm` | 两个目录整体 `mv` 到 `<工作区根>/.deleted/<时间>-<项目>/`，并写 `META.md`（时间、机器、空间 id、原路径、恢复命令） |
| 执行后自检 | 搬完再查两个目录是否真的消失，缺一则明确报「删除未完成」 |

> [!danger] 不要在项目自己的终端里执行删除
> 这是本轮踩到的真坑：在 `proj-a` 的终端里跑 `delete-project proj-a --yes`，脚本会先移走该目录、再关闭它所在的空间——终端被结束后命令中途终止，**结果什么都没有发生**（目录还在、空间还在、回收站是空的），而终端上看起来像「执行过了」。
> 现行版本会在项目目录内直接拒绝（退出码 2），并给出两条出路：`cd` 到项目外再跑，或加 `--keep-space` 只删目录、空间稍后手动关。`--force-inside` 可跳过该检查，但没人需要用它。

## 七、技能分发：一份源，十四处可见

技能装在用户级目录，不跟项目走，所以任何 cwd 都能触发。源统一放在 `~/.agents/skills/<name>`（omp 直接读这里），其余 Agent 由 `skills-sync` 分发：Claude 建软链，qwen / codex / opencode / workbuddy / codebuddy / commandcode / dsh / hermes / minimax / qoder-cn / reasonix / trae-cn 复制副本，最后逐个校验哈希。

```sh
skills-sync                 # 全部技能同步 + 校验
skills-sync project-init    # 只同步指定技能
```

> [!success] 一个例外
> Codex 0.169 **不读 SKILL.md**（子命令里只有 `plugin` / `marketplaces`，二进制里没有相关字符串），它认的是全局指令文件 `~/.codex/AGENTS.md`。所以同一套规则要往那里也写一份，否则 Codex 什么都看不到。

分发方式也有取舍：**不要用软链接指向同步盘**。某同步目录里 76 个符号链接有 69 个已断，断因是「指向另一台机器的绝对路径」和「不同机器上用户名大小写差异（`/Users/alice` vs `/Users/Alice`）」。把技能源放在本地 home、用实体副本分发，比省那点磁盘更划算。

## 坑清单（本章新增 BB–BI）

| # | 坑 | 对策 |
|---|---|---|
| BB | **在 App 里点 `+` 新建空间，找不到填 folder 的地方**：对话框只问名字，目录默认取聚焦终端的 cwd | 先 `cd` 到目标再点 `+`；或直接 `herdr-app do space.new --name X --folder /abs/path` |
| BC | **以为空间 folder 可以改**：命令集里没有 `set_folder`，改不了 | 创建时就指对；确实要换只能 `space.close` 后重建（会结束终端） |
| BD | **在项目自己的终端里执行删除**：移走 cwd + 关闭所在空间，命令中途被杀，结果什么都没发生 | 到项目外执行；或 `--keep-space` 只删目录、稍后手动关空间。v1.2.0 已加拦截 |
| BE | **空间名与项目名不一致时找不到空间**，删除后空间残留 | 匹配条件改为「名字 **或** folder 路径」双条件 |
| BF | **bash 3.2 里 `$VAR` 紧跟中文标点会被吞进变量名**，报 `unbound variable: NAME�` | 一律写 `${VAR}`；本轮在三个脚本里共修了 10 处 |
| BG | **把 `-name *.md` 放进变量再展开**：当前目录的 glob 会先把 `*.md` 打成真实文件名，find 表达式报废且静默无输出 | find 的 `-name` 模式内联并加引号：`-name '*.md'` |
| BH | **以为 Codex 也会读 SKILL.md**：0.169 没有 skills 机制 | 规则另写一份到 `~/.codex/AGENTS.md`；其余 Agent 用 `skills-sync` |
| BI | **用 `du` 判断「复制占不占空间」**：APFS 写时复制下 `du` 把共享块算两遍，会显示双倍 | 看 `df`：实测 256 MB 文件 `cp -c` 后可用空间变化 0 MB；同卷复制基本免费 |

> [!danger] ⚠️ 一句总结
> 项目生命周期的关键不是工具多，而是**每个动作只有一个负责人**：目录由 `new-project` 建、产物由 agent 直接写存储区、空间由创建时的 folder 决定、删除由 `delete-project` 一次完成且不碰 `rm`。任何一步出现「两个负责人」，就会出现两个判断者、两份副本、两种真相。

依据：本机 `new-project 1.9.0` / `delete-project 1.2.0` / `skills-sync 2.0.0` 的实际行为与源码；`herdr-app commands` 输出的 `space.*` 命令集（无 `set_folder`）、`space.new` 的七个参数、`space.close` 的 `id` / `confirmed` 参数；Herdr 二进制内的命令说明原文「the folder its terminals start in (default: the focused terminal's)」「its terminals start in that machine's home unless folder」；`~/.local/state/herdr-core/default/docs.json` 中 `spaces[].folder` 与 `terminals.json` 中独立 `cwd` 的对照；项目 `proj-b`（`report.md` 仅存于存储区）与 `proj-a`（`notes.md` 双份、mtime 相同）的实测对照；该会话记录 会话记录中最后一条 `run_shell_command` 无返回的证据；本机同步根 76 个符号链接中 69 个断链的统计；APFS 写时复制实测（256 MB 文件 `cp -c` 前后 `df` 变化 0 MB、`du` 报 512 MB）。
