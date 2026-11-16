---
name: project-init
description: 初始化一个「工作区 / 存储区」分离的新项目，并给出两条路径的建议值。用户说「新建项目」「初始化项目」「开个新项目」「这个项目该放哪」「project init」「new project」时使用。会先探测本机情况给建议，也允许直接输入任意路径覆盖；存储区目录名自动带本机机器标识后缀（如 my-project@work-mac），多台机器各写各的目录不会互相覆盖。
---

# 初始化项目（工作区 / 存储区分离）

把「项目放哪、产物放哪、多台机器怎么不打架」一次对话定下来。

## 何时使用

- 用户要开新项目，但没说放哪个目录
- 用户问「这个项目该放哪」「工作区和存储区怎么分」
- 已有项目文件夹，不确定该不该放进云盘同步目录

**不适用**：已有项目的归档/清理；也不要改已存在的项目结构。

## 核心模型：三区

| 区 | 作用 | 建议位置 | 是否同步 |
|---|---|---|---|
| 工作区 | 代码、草稿、日志、缓存、中间数据 | `<工作区根>/<项目>`（本地盘） | **否**，两台机器写会冲突 |
| 存储区 | 唯一成品地，**agent 直接写这里** | `<存储区根>/<项目>@<机器标识>` | 是，每台机器一个目录 |
| Herdr 空间 | 只决定「终端从哪起」 | 由 `new-project` 自动创建 | 否 |

一句话：**工作区可整目录删除（git 兜底），存储区是成品唯一所在，且按机器分区。**

## 第一步：先探测，再建议

不要直接问「你要放哪」，先拿事实：

```sh
new-project --help | head -22          # 看默认值与当前配置
cat ~/.config/new-project/config       # WORK_ROOT / STORE_ROOT
scutil --get LocalHostName 2>/dev/null || hostname -s   # 本机主机名
cat ~/.config/new-project/machines.conf                 # 主机名 → 机器标识
ls -d <工作区根>/<项目> 2>/dev/null                      # 同名是否已存在
ls -d <存储区根>/<项目>@* 2>/dev/null                    # 另一台机器是否建过
df -h ~ | tail -1
```

建议规则：

1. **工作区**：用配置里的 `WORK_ROOT`；若用户历史项目都在某个目录，建议沿用。**绝不建议把工作区放进 iCloud / Dropbox / OneDrive / 坚果云等同步目录**。
2. **存储区**：用配置里的 `STORE_ROOT`，目录名 `<项目>@<机器标识>`。
3. **机器标识查不到映射**（新机器第一次用）：先 `scutil --get LocalHostName`，再往 `machines.conf` 补一行 `<主机名>=<机器标识>`。否则目录名会退化成主机名。
4. **已存在同名**：先报告，不要自动 `--force`，让用户决定改名还是补文件。
5. **另一台机器的同名目录**（`<项目>@<别的标识>`）：提醒那是另一台写的，不要覆盖，也不要用 `--no-machine-suffix` 硬合并。

## 第二步：给用户四个选项

| 选项 | 含义 |
|---|---|
| A. 都用建议路径 | 工作区 + 存储区都按配置 |
| B. 只改工作区 | 用户直接给路径，如 `/Volumes/SSD/proj` |
| C. 只改机器标识或后缀写法 | 换标识、换分隔符，或不要后缀 |
| D. 两个都自己指定 | 各给一个路径 |

用户直接输入路径时**原样接受**，只校验三项：可写、不是根目录、两区不重叠或互相嵌套。有问题请用户再给一个，不要自作主张替换。

## 第三步：先 dry-run，再落地

```sh
new-project "<项目名>" --dry-run
# 复述两条路径（注意存储区带 @机器标识）给用户确认，然后去掉 --dry-run
new-project "<项目名>" --git
```

参数：`--git`（初始化仓库）、`--no-space`（不建 Herdr 空间）、`--readonly`（存储区建好即只读）、`--machine <标识>`、`--suffix-sep <字符>`、`--no-machine-suffix`。

生成结果：

```
<工作区>/<项目>/     src/ tmp/ logs/ AGENTS.md .gitignore PROGRESS.md .claude/settings.json
<存储区>/<项目>@<机器标识>/   OWNER（machine / hostname / store_dir / note）
```

**默认会顺手建一个同名 Herdr 空间**，folder 指向工作区。`herdr-app` 不存在时只警告、不中断。

**建完必须验证空间**（folder 建后不可改，失败又只警告，不能假定成功）：

```sh
herdr-app ls | grep -A4 "<项目名>"      # folder 是否等于工作区绝对路径
```

| 看到什么 | 处理 |
|---|---|
| folder 与工作区一致 | ✅ 完成 |
| 「空间已存在，跳过」但 folder 不一致 | 同名旧空间占了名字，只能 close 重建（会结束终端），**先问用户** |
| 「未找到 herdr-app」或建失败 | 目录照常可用，把脚本给的那条命令告诉用户手动执行 |

## 第四步：告诉用户三件事

1. **产物写哪里**：`<存储区>/<项目>@<机器标识>/`。agent 产出交付物时**直接写这里**，不要先写工作区再问；工作区只放 `src/ tmp/ logs/`。
2. **授权**：`.claude/settings.json` 已把存储区写进 `permissions.additionalDirectories`，Claude 无需额外参数；其他 agent 用 `--add-dir`（qwen 用 `--include-directories`，Codex 用 `tool_config`/`writable_roots`）。
3. **后缀含义**：另一台机器用 `@<它的标识>`，两份目录并存；要合并手动挑文件，别指望同步自动合并。

## 关于 Herdr 空间：folder 建后不可改

- 没有「全局初始文件夹」设置；目录绑在**空间**上（`docs.json` 的 `spaces[].folder`）
- App 里点 `+` 新建空间只问名字，folder 默认取**当前聚焦终端的目录**
- 命令集只有 `space.new / rename / colors / move / select / next / prev / close`，**没有 `set_folder`**
- 命令行建空间不继承 cwd（脚本调用落在家目录），必须显式 `--folder`

```sh
herdr-app do space.new --name "<项目>" --folder "<工作区绝对路径>"
herdr-app do space.close --id <空间id> --confirmed true   # 会结束里面的终端
```

## 脚本缺失时

`command -v new-project` 为空就手工建，并告知用户脚本未安装：

```sh
M="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
mkdir -p "<工作区>/<项目>"/{src,tmp,logs} "<存储区>/<项目>@$M"
printf 'machine: %s\nhostname: %s\ncreated: %s\n' "$M" "$(hostname -s)" "$(date +%F)" \
  > "<存储区>/<项目>@$M/OWNER"
```

## 硬约束

1. **不覆盖已有文件**：`--force` 只补缺失。
2. **工作区不进同步盘**：命中 iCloud / Dropbox / OneDrive / 坚果云 等要明确警告。
3. **存储区只写自己标识的目录**，不要合并两台机器的输出。
4. **不用符号链接**把存储区"映射"进项目——换机、改用户名就断链。
5. **不移动已有项目目录**：agent 历史按 cwd 绝对路径编码，移动后 `--continue` 找不到旧对话。
6. **不把 `.git` 放进同步盘**：容易 `index.lock` 残留、坏对象。
