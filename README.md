# herdr-config

My [herdr](https://herdr.dev) setup for running several Claude Code (and Codex, Cursor, OpenCode, pi) agents side by side. It adds:

- **Live progress bars per Claude pane**: todo progress (`▰▰▰▱▱▱▱▱ 3/8`), the current step, and the latest action (`$ cargo test`, `✎ main.rs`)
- **Workspace rollups in the sidebar**: agents working, blocked, or done, plus the git branch and summed todo progress
- **A tab bar** with every agent's state, all todos, and Claude 5h and weekly usage
- **Context, 5h, and weekly usage bars** per agent (via [herdr-pacer](https://github.com/amali01/herdr-pacer))
- **Numbered workspaces and tabs** (via [herdr-numbering](https://github.com/kokatsu/herdr-numbering))
- **Sounds**: a soft chime when an agent finishes, a double ping when one needs you
- **Popups**: a cheat sheet (`prefix i`), lazygit (`prefix alt+g`), and the usage dock (`prefix u`)
- Tokyo Night colors

Linux and macOS.

## Setup

### 1. Install the tools

**macOS**
```bash
brew install git python node lazygit bat terminal-notifier
```
Then install Rust from https://rustup.rs (it builds herdr-pacer) and herdr from https://herdr.dev.

**Linux (Arch)**
```bash
sudo pacman -S git python nodejs npm rust lazygit bat
```
Then install herdr from the AUR package `herdr`.

You also need [Claude Code](https://docs.claude.com/claude-code). Run `claude` once and log in. lazygit, bat, and terminal-notifier are optional; everything else works without them.

### 2. Clone

```bash
git clone https://github.com/idrewlong/herdr-config.git ~/code/herdr-config
```
Keep the clone where it is. The scripts, sounds, and cheat sheet are symlinked from it, so moving it breaks them.

### 3. Start herdr, then run the installer inside it

Plugins install through the running herdr server, so start herdr first:
```bash
herdr
```
Then, in a herdr pane:
```bash
~/code/herdr-config/install.sh --dry-run   # preview
~/code/herdr-config/install.sh
```

The installer:
1. Checks for the tools above.
2. Copies `config.toml` to `~/.config/herdr/`, and links `scripts/`, `sounds/`, and `cheatsheet.md` there.
3. Merges four hooks into `~/.claude/settings.json` that run `scripts/claude-progress.py`. These feed the progress bars. **Nothing else in your Claude settings changes.**
4. Runs `herdr integration install` for each agent CLI it finds (claude, codex, cursor-agent, opencode, pi).
5. Installs herdr-pacer and herdr-numbering at the pinned commits, applies the pacer settings, and wraps Claude's statusLine for the context bars.
6. Validates the config and reloads herdr.

Every file it replaces is backed up next to itself as `<file>.bak-<timestamp>`, and it's safe to rerun.

### 4. Restart Claude sessions

Open Claude sessions only load new hooks and the statusLine when they start. Then start a Claude pane in herdr. Its progress bars appear once it makes a todo list.

### Check it worked

- `herdr plugin list` shows `herdr-pacer` and `kokatsu.numbering`
- `herdr config check` passes
- `prefix i` (`ctrl+space`, then `i`) opens the cheat sheet

## Keys

The prefix is `ctrl+space`. [cheatsheet.md](cheatsheet.md) has the full list; the essentials are:

| Key | Does |
|---|---|
| `alt+up` / `alt+down` | previous / next workspace |
| `alt+1..9` | jump to tab N |
| `ctrl+alt+arrows` | move between panes |
| `alt+enter` | split side by side |
| `prefix z` | zoom the current pane |
| `prefix shift+c` | new workspace |
| `prefix i` | cheat sheet |
| `prefix alt+g` | lazygit |
| `prefix u` | Claude usage dock |
| `prefix d` | detach (run `herdr` to come back) |

## Files

| Path | Installed to | How |
|---|---|---|
| `config.toml` | `~/.config/herdr/config.toml` | copied, because herdr-pacer rewrites it. `@PACER_BIN@` is replaced with the built pacer path |
| `scripts/claude-progress.py` | `~/.config/herdr/scripts/` | linked. A Claude Code hook that reports todo progress and the current action to the herdr sidebar. Does nothing outside herdr and never fails the hook |
| `scripts/herdr-bar.sh` | `~/.config/herdr/scripts/` | linked. Builds the tab bar and the per-workspace rollups |
| `sounds/` | `~/.config/herdr/sounds/` | linked |
| `cheatsheet.md` | `~/.config/herdr/cheatsheet.md` | linked |
| `plugins/herdr-pacer.settings.json` | herdr-pacer's config dir | copied |
| `claude/hooks.json` | `~/.claude/settings.json` | merged into the `hooks` key |

## Updating

- `git pull` updates the scripts, sounds, and cheat sheet right away, since they're symlinks.
- For `config.toml` or plugin changes, rerun `./install.sh`. This overwrites `~/.config/herdr/config.toml`, after backing it up.
- The plugin versions are pinned in `install.sh` (`PACER_REF`, `NUMBERING_REF`). Bump them only after reading the new code.

## Customizing

Edit `~/.config/herdr/config.toml` directly for personal tweaks. Your edits are overwritten the next time you run `install.sh` (a backup is kept). To keep them, fork this repo and edit `config.toml` there. If you copy a live config back in, replace the pacer binary path with `@PACER_BIN@`.

## Uninstall

1. Delete the `claude-progress.py` entries from `hooks` in `~/.claude/settings.json`.
2. Remove the symlinks in `~/.config/herdr` (`scripts`, `sounds`, `cheatsheet.md`).
3. Restore `config.toml` from a `.bak-*` file.
4. Run `herdr plugin uninstall herdr-pacer` and `herdr plugin uninstall kokatsu.numbering`.
