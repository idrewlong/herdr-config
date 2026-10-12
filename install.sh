#!/usr/bin/env bash
# Install this herdr setup: config, Claude progress scripts, sounds, cheat sheet, pinned plugins,
# and the Claude Code hooks that feed the sidebar. Linux and macOS.
#
#   ./install.sh            # install or refresh
#   ./install.sh --dry-run  # show what would change
#
# Safe to rerun. Every file it replaces is backed up next to itself as <file>.bak-<timestamp>.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
[[ "${1:-}" == --dry-run ]] && DRY=1
STAMP="$(date +%s)"

PACER_REPO="amali01/herdr-pacer"
PACER_REF="e011783ab81225793bb0850e766c6ca15cc77be2"
NUMBERING_REPO="kokatsu/herdr-numbering"
NUMBERING_REF="f5064208e73ea8b7e3251a482f30eaea85e9e577"

HERDR_DIR="$HOME/.config/herdr"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

say()  { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '    ! %s\n' "$*" >&2; }
run()  { if [[ $DRY -eq 1 ]]; then echo "    [dry-run] $*" >&2; else "$@"; fi; }
has()  { command -v "$1" >/dev/null 2>&1; }
backup() { [[ -e "$1" && ! -L "$1" ]] && run cp -p "$1" "$1.bak-$STAMP" || true; }

# ---------------------------------------------------------------------------
say "1/6 Checking tools"
missing=0
for t in git python3 herdr; do
  if has "$t"; then note "$t: ok"; else warn "$t: missing"; missing=1; fi
done
has claude && note "claude: ok" || note "claude: not found (the progress bars need Claude Code)"
has cargo && note "cargo: ok" || warn "cargo: missing (needed to build herdr-pacer; install Rust from https://rustup.rs)"
has lazygit || note "lazygit: not found (prefix alt+g opens it)"
has bat || note "bat: not found (the cheat sheet falls back to less)"
[[ $missing -eq 0 ]] || { warn "install the missing tools above, then rerun"; exit 1; }
if [[ "$(uname)" == Darwin ]]; then
  has terminal-notifier || note "for clickable herdr notifications: brew install terminal-notifier"
fi
herdr status server 2>/dev/null | grep -q "status: running" || warn "herdr isn't running: start herdr once in another terminal, then rerun so plugins can install"

# ---------------------------------------------------------------------------
say "2/6 herdr config, scripts, sounds, cheat sheet ($HERDR_DIR)"
run mkdir -p "$HERDR_DIR"
backup "$HERDR_DIR/config.toml"
run cp "$ROOT/config.toml" "$HERDR_DIR/config.toml"   # copied: herdr-pacer rewrites it
for d in scripts sounds; do
  if [[ -d "$HERDR_DIR/$d" && ! -L "$HERDR_DIR/$d" ]]; then run mv "$HERDR_DIR/$d" "$HERDR_DIR/$d.bak-$STAMP"; fi
  run ln -sfn "$ROOT/$d" "$HERDR_DIR/$d"                # linked: git pull updates them
done
run ln -sf "$ROOT/cheatsheet.md" "$HERDR_DIR/cheatsheet.md"
note "config copied; scripts, sounds and cheat sheet linked from this repo"

# ---------------------------------------------------------------------------
say "3/6 Claude Code hooks ($CLAUDE_SETTINGS)"
run mkdir -p "$HOME/.claude"
backup "$CLAUDE_SETTINGS"
if [[ $DRY -eq 0 ]]; then
  python3 - "$ROOT/claude/hooks.json" "$CLAUDE_SETTINGS" <<'PY'
import json, sys
base = json.load(open(sys.argv[1]))
path = sys.argv[2]
try:
    cur = json.load(open(path))
except Exception:
    cur = {}
hooks = cur.setdefault("hooks", {})
for event, entries in base["hooks"].items():
    have = hooks.setdefault(event, [])
    for e in entries:
        cmd = e["hooks"][0]["command"]
        if not any(h.get("command") == cmd for x in have for h in x.get("hooks", [])):
            have.append(e)
json.dump(cur, open(path, "w"), indent=2)
open(path, "a").write("\n")
PY
fi
note "progress hooks merged (everything else in your settings is left alone)"

# ---------------------------------------------------------------------------
say "4/6 herdr agent integrations"
for agent in claude codex opencode cursor pi; do
  bin="$agent"; [[ $agent == cursor ]] && bin="cursor-agent"
  if has "$bin"; then run herdr integration install "$agent" >/dev/null 2>&1 && note "$agent: installed" || note "$agent: skipped"; fi
done

# ---------------------------------------------------------------------------
say "5/6 herdr plugins (pinned)"
install_plugin() {
  if herdr plugin list 2>/dev/null | grep -q "$1@$2"; then note "$1: already at ${2:0:7}"; return; fi
  run herdr plugin uninstall "$3" >/dev/null 2>&1 || true
  run herdr plugin install "$1" --ref "$2" -y >/dev/null && note "$1: installed at ${2:0:7}" || warn "$1: install failed (is herdr running? for pacer: is cargo installed?)"
}
install_plugin "$PACER_REPO" "$PACER_REF" herdr-pacer
install_plugin "$NUMBERING_REPO" "$NUMBERING_REF" kokatsu.numbering

pacer_cfg="$(herdr plugin config-dir herdr-pacer 2>/dev/null || echo "$HERDR_DIR/plugins/config/herdr-pacer")"
run mkdir -p "$pacer_cfg"
run cp "$ROOT/plugins/herdr-pacer.settings.json" "$pacer_cfg/settings.json"
[[ $DRY -eq 1 ]] || echo '{"hidden": true}' > "$pacer_cfg/dock.json"
pacer_bin="$(ls -d "$HERDR_DIR"/plugins/github/herdr-pacer-*/target/release/herdr-pacer 2>/dev/null | head -n1 || true)"
if [[ -n "$pacer_bin" ]]; then
  [[ $DRY -eq 1 ]] || { sed -i.tmp "s#@PACER_BIN@#$pacer_bin#g" "$HERDR_DIR/config.toml" && rm -f "$HERDR_DIR/config.toml.tmp"; }
  run "$pacer_bin" claude-hook install >/dev/null && note "Claude statusLine wrapped (context bars)"
else
  [[ $DRY -eq 1 ]] || { sed -i.tmp "/@PACER_BIN@/d" "$HERDR_DIR/config.toml" && rm -f "$HERDR_DIR/config.toml.tmp"; }
  warn "herdr-pacer not built; its tab bar entry was left out. Rerun after installing cargo"
fi

# ---------------------------------------------------------------------------
say "6/6 Check and reload"
herdr config check || warn "herdr config has problems (see above)"
run herdr server reload-config >/dev/null 2>&1 && note "herdr reloaded" || note "herdr not running; the config applies when it starts"

cat <<'DONE'

done. Restart open Claude sessions so the hooks and statusLine load.
Inside herdr, prefix i (ctrl+space, then i) opens the cheat sheet.
DONE
