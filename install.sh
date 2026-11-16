#!/usr/bin/env bash
# 安装 herdr-project-toolkit：三个命令 + 两个技能
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

printf '== 脚本 → ~/.local/bin ==\n'
mkdir -p "$HOME/.local/bin"
for f in new-project delete-project skills-sync; do
  install -m 755 "$HERE/bin/$f" "$HOME/.local/bin/$f"
  printf '  %s\n' "$f"
done

printf '== 技能 → ~/.agents/skills ==\n'
mkdir -p "$HOME/.agents/skills"
for s in project-init project-delete; do
  rm -rf "$HOME/.agents/skills/$s"
  cp -R "$HERE/skills/$s" "$HOME/.agents/skills/$s"
  printf '  %s\n' "$s"
done

printf '== 配置 ==\n'
mkdir -p "$HOME/.config/new-project"
if [ -e "$HOME/.config/new-project/config" ]; then
  printf '  已存在，跳过: ~/.config/new-project/config\n'
else
  cat > "$HOME/.config/new-project/config" <<CONF
# 工作区根（本地盘）
WORK_ROOT=$HOME/Projects
# 存储区根（可放同步盘）
STORE_ROOT=$HOME/Projects-archive
CONF
  printf '  已生成: ~/.config/new-project/config\n'
fi
if [ -e "$HOME/.config/new-project/machines.conf" ]; then
  printf '  已存在，跳过: ~/.config/new-project/machines.conf\n'
else
  cp "$HERE/config/machines.conf.example" "$HOME/.config/new-project/machines.conf"
  printf '  已生成: ~/.config/new-project/machines.conf（多台机器时请补映射）\n'
fi
printf '  本机主机名: %s / %s\n' "$(scutil --get LocalHostName 2>/dev/null || echo '?')" "$(hostname -s)"

printf '== 分发到各 Agent ==\n'
if [ -x "$HOME/.local/bin/skills-sync" ]; then
  "$HOME/.local/bin/skills-sync" project-init project-delete || true
fi

printf '\n== 自检 ==\n'
for c in new-project delete-project skills-sync; do
  if command -v "$c" >/dev/null 2>&1; then
    printf '  %-14s %s\n' "$c" "$("$c" --version)"
  else
    printf '  %-14s 未在 PATH，请把 ~/.local/bin 加进去或重开终端\n' "$c"
  fi
done
cat <<'TIPS'

下一步：
  1) 改 ~/.config/new-project/config 里的两个路径
  2) 多台机器：改 ~/.config/new-project/machines.conf
  3) new-project demo --dry-run      # 先看两条路径对不对
  4) new-project demo --git          # 真建
  5) 删除：cd ~ && delete-project demo --yes   （不要在项目自己的终端里跑）
TIPS
