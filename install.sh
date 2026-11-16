#!/usr/bin/env bash
# Install herdr-project-toolkit: three commands and two agent skills.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

printf '== commands -> ~/.local/bin ==\n'
mkdir -p "$HOME/.local/bin"
for f in new-project delete-project skills-sync; do
  install -m 755 "$HERE/bin/$f" "$HOME/.local/bin/$f"
  printf '  %s\n' "$f"
done

printf '== skills -> ~/.agents/skills ==\n'
mkdir -p "$HOME/.agents/skills"
for s in project-init project-delete; do
  rm -rf "$HOME/.agents/skills/$s"
  cp -R "$HERE/skills/$s" "$HOME/.agents/skills/$s"
  printf '  %s\n' "$s"
done

printf '== config ==\n'
mkdir -p "$HOME/.config/new-project"
if [ -e "$HOME/.config/new-project/config" ]; then
  printf '  exists, skipped: ~/.config/new-project/config\n'
else
  cat > "$HOME/.config/new-project/config" <<CONF
# work area root (local disk)
WORK_ROOT=$HOME/Projects
# store area root (may live on a synced disk)
STORE_ROOT=$HOME/Projects-archive
CONF
  printf '  created: ~/.config/new-project/config\n'
fi
if [ -e "$HOME/.config/new-project/machines.conf" ]; then
  printf '  exists, skipped: ~/.config/new-project/machines.conf\n'
else
  cp "$HERE/config/machines.conf.example" "$HOME/.config/new-project/machines.conf"
  printf '  created: ~/.config/new-project/machines.conf (add a mapping per machine)\n'
fi
printf '  hostname here: %s / %s\n' "$(scutil --get LocalHostName 2>/dev/null || echo '?')" "$(hostname -s)"

printf '== distributing skills ==\n'
if [ -x "$HOME/.local/bin/skills-sync" ]; then
  "$HOME/.local/bin/skills-sync" project-init project-delete || true
fi

printf '\n== self-check ==\n'
for c in new-project delete-project skills-sync; do
  if command -v "$c" >/dev/null 2>&1; then
    printf '  %-14s %s\n' "$c" "$("$c" --version)"
  else
    printf '  %-14s not on PATH; add ~/.local/bin or open a new terminal\n' "$c"
  fi
done
cat <<'TIPS'

Next:
  1) edit the two roots in ~/.config/new-project/config
  2) multiple machines: edit ~/.config/new-project/machines.conf
  3) new-project demo --dry-run      # check both paths first
  4) new-project demo --git          # create it
  5) delete: cd ~ && delete-project demo --yes   (never from inside the project)
TIPS
