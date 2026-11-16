# herdr-project-toolkit

给 AI coding agent 用的项目生命周期工具：**工作区放过程、存储区放成品**，两台电脑同时干活也不会互相覆盖。

三个命令 + 两个 Agent 技能（Skill）：

| 命令 | 作用 |
|---|---|
| `new-project <name>` | 建工作区 + 存储区 + `AGENTS.md` + 只读授权 + Herdr 空间 |
| `delete-project <name>` | 删项目：两个目录移入回收站、关闭空间，不用 `rm` |
| `skills-sync` | 把 `~/.agents/skills` 下的技能分发到所有 Agent 的目录 |

| 技能 | 触发 |
|---|---|
| `project-init` | 「新建项目」「初始化项目」「这个项目该放哪」 |
| `project-delete` | 「删除项目」「删掉这个项目」 |

## 它解决什么问题

用 AI agent 做项目的常见混乱：产物和过程文件混在一个目录、两台电脑通过网盘同步同一个文件夹导致冲突副本、删项目时不确定该删什么。

这套工具的做法是**把三件事分开**：

```
工作区（本地盘，可随时整目录删除）
  src/  tmp/  logs/        ← 草稿、日志、缓存、中间数据
  AGENTS.md               ← 规则：产物写哪儿、怎么判定
  .claude/settings.json   ← 预先授权 agent 写存储区

存储区（可放网盘同步，按机器分区）
  <项目>@<机器标识>/        ← 交付物直接落在这里 + OWNER + MANIFEST
```

关键点：**产物默认直接写存储区**，所以不存在"先写工作区、再问用户是不是产物、再复制"这一串动作。

## 安装

```sh
git clone https://github.com/<you>/herdr-project-toolkit.git
cd herdr-project-toolkit
./install.sh
```

`install.sh` 会：

1. 把 `bin/` 下三个脚本装到 `~/.local/bin`
2. 把 `skills/` 下两个技能装到 `~/.agents/skills`
3. 首次生成 `~/.config/new-project/config`（不覆盖已有）
4. 调用 `skills-sync` 分发到各 Agent
5. 打印版本自检

依赖：macOS（用到 `scutil` / `md5`）、`bash 3.2+`。可选：`herdr-app`（自动建/关空间）、`python3`（解析 JSON）。

## 快速开始

```sh
# 1) 配路径（默认 ~/Projects 与 ~/Projects-archive）
$EDITOR ~/.config/new-project/config

# 2) 配机器标识（多台机器时重要）
$EDITOR ~/.config/new-project/machines.conf

# 3) 先看它准备建到哪
new-project my-project --dry-run

# 4) 真建
new-project my-project --git
```

## 配置

`~/.config/new-project/config`：

```
WORK_ROOT=/Users/you/Projects
STORE_ROOT=/Users/you/Projects-archive
```

`~/.config/new-project/machines.conf`（主机名 → 目录里用的机器标识）：

```
my-macbook=mac-a
mac-a=mac-a
imac-7=iMac-7
```

为什么要映射：目录名要短、要稳定，而主机名可能很长或带 `.local`。

## 为什么这样设计

**1. 工作区与存储区分离**
工作区可以整目录删掉（产物已经在存储区），所以不用纠结"这个文件夹能不能删"。

**2. 存储区按机器分区（`<项目>@<机器>`）**
两台机器同步同一个目录，必然产生冲突副本（`xxx_机器名_时间_Conflict.md`）。分区后各写各的，冲突消失；代价是**同步不等于合并**——同一项目在两台机器上做，产物会分成两份，要合并得手动挑。

**3. 产物判定写成规则，而不是每次问人**
`AGENTS.md` 里有判定表：文档/报告/数据表/演示图/成品页/可复用工具 = 产物；草稿/日志/缓存/中间数据/一次性脚本 = 过程。拿不准就写存储区的 `_待确认/`，**宁可多存，不要打断用户**。

**4. 删除不用 `rm`**
两个目录整体 `mv` 到 `<工作区根>/.deleted/<时间>-<项目>/`，附 `META.md` 记录恢复命令。同卷移动瞬间完成，不占额外空间。

**5. 不用符号链接**
把存储区"映射"进项目的做法在换机、改用户名后会断链。实测某同步目录里 76 个符号链接断了 69 个。

## 常见坑

| 现象 | 原因 | 处理 |
|---|---|---|
| 空间目录不对，且改不了 | Herdr 空间的 `folder` 建后不可改（无 `set_folder`） | 创建时用 `--folder` 指对；要换只能关掉重建 |
| 删除命令执行了但什么都没发生 | 在项目自己的终端里跑：移走 cwd + 关空间把命令杀了 | `cd ~` 后再执行，或加 `--keep-space` |
| 存储区目录名是奇怪的主机名 | `machines.conf` 没配这台机器 | 补一行 `<主机名>=<标识>` |
| 脚本报 `unbound variable: NAME�` | bash 3.2 里 `$VAR` 紧跟中文标点被吞 | 脚本内一律写 `${VAR}`（已修） |
| Agent 不读 `SKILL.md` | Codex 0.169 没有 skills 机制 | 规则另写到 `~/.codex/AGENTS.md` |

## 设计说明

[`docs/22-project-lifecycle.md`](docs/22-project-lifecycle.md) 是这套工具的设计依据，讲清了三区模型、为什么存储区要按机器分区、产物判定为什么写成规则而不是每次问人、删除为什么不用 `rm`，以及这一路踩到的 8 个坑。

## 目录结构

```
bin/new-project       建项目（含 AGENTS.md / .claude/settings.json / Herdr 空间）
bin/delete-project    删项目（清单 → 确认 → 回收站 → 关空间 → 自检）
bin/skills-sync       技能分发与哈希校验
skills/project-init/  初始化技能
skills/project-delete/删除技能
config/               配置模板
docs/                 设计说明
```

## License

MIT
