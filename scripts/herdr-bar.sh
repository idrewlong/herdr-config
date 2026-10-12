#!/bin/sh
# Tab-bar status (ui.tab_bar_right command entry): agent counts plus all Claude todo progress summed.
#   ●2 working  ▲1 blocked  ✓3 done  ▰▰▰▰▱▱▱▱ 12/20
# Reads herdr's live snapshot and the per-pane files claude-progress.py writes. On the way it
# reports each workspace's own rollup to the sidebar's Space rows ($wsagents, $wsbar, $wscount),
# only when a value changed.
exec python3 - <<'PY'
import glob, json, os, subprocess, time

STATE = os.path.expanduser("~/.cache/herdr-progress")
CELLS = 8
bar = lambda d, t: "▰" * round(CELLS * d / t) + "▱" * (CELLS - round(CELLS * d / t))

try:
    snap = json.loads(subprocess.run(["herdr", "api", "snapshot"], capture_output=True, text=True, timeout=2).stdout)["result"]["snapshot"]
except Exception:
    raise SystemExit(0)

agents = snap.get("agents", [])
SYMS = (("●", "working"), ("▲", "blocked"), ("✓", "done"))

def counts(group, words=True):
    out = []
    for sym, status in SYMS:
        n = sum(a.get("agent_status") == status for a in group)
        if n:
            out.append(f"{sym}{n} {status}" if words else f"{sym}{n}")
    return out

# per-pane todo progress, keyed by workspace
live = {p["pane_id"]: p["workspace_id"] for p in snap.get("panes", [])}
prog = {}
for f in glob.glob(os.path.join(STATE, "*.json")):
    try:
        s = json.load(open(f))
    except Exception:
        continue
    ws = live.get(s.get("pane"))
    if ws is None:
        os.remove(f)  # pane closed
        continue
    if time.time() - s.get("updated", 0) < 6 * 3600 and s.get("total"):
        d, t = prog.get(ws, (0, 0))
        prog[ws] = (d + s["done"], t + s["total"])

# workspace rollups for the sidebar
try:
    last = json.load(open(os.path.join(STATE, "workspaces.last")))
except Exception:
    last = {}
now = {}
for w in snap.get("workspaces", []):
    ws = w["workspace_id"]
    mine = [a for a in agents if a.get("workspace_id") == ws]
    d, t = prog.get(ws, (0, 0))
    now[ws] = {"wsagents": " ".join(counts(mine, words=False)), "wsbar": bar(d, t) if t else "", "wscount": f"{d}/{t}" if t else ""}
    if now[ws] != last.get(ws):
        cmd = ["herdr", "workspace", "report-metadata", ws, "--source", "herdr-bar", "--seq", str(time.time_ns())]
        for k, v in now[ws].items():
            cmd += ["--token", f"{k}={v}"] if v else ["--clear-token", k]
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
try:
    os.makedirs(STATE, exist_ok=True)
    json.dump(now, open(os.path.join(STATE, "workspaces.last"), "w"))
except Exception:
    pass

# the tab bar line
parts = counts(agents)
if not parts and agents:
    parts.append(f"○{len(agents)} idle")
done = sum(d for d, _ in prog.values()); total = sum(t for _, t in prog.values())
if total:
    parts.append(f"{bar(done, total)} {done}/{total}")
print("  ".join(parts))
PY
