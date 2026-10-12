#!/usr/bin/env python3
"""Claude Code hook -> herdr sidebar: a todo progress bar and a live "what it's doing" line.

Wired in ~/.claude/settings.json for PreToolUse, PostToolUse, UserPromptSubmit and Stop.
Reports custom pane tokens that config.toml places in the agent rows:

  $bar    ▰▰▰▱▱▱▱▱        todo progress (TodoWrite or TaskCreate/TaskUpdate)
  $count  3/8
  $step   current in-progress todo ("Running the tests")
  $doing  latest tool call ("$ cargo test", "✎ main.rs"), cleared when the turn ends

State per pane lives in ~/.cache/herdr-progress/<pane>.json so herdr-bar.sh can sum all agents
into the tab bar. Does nothing outside herdr and never fails the hook.
"""
import json
import os
import re
import subprocess
import sys
import time

CELLS = 8
STATE_DIR = os.path.expanduser("~/.cache/herdr-progress")


def bar(done, total):
    filled = round(CELLS * done / total) if total else 0
    return "▰" * filled + "▱" * (CELLS - filled)


def short(text, n=42):
    text = " ".join(str(text).split())
    return text if len(text) <= n else text[: n - 1] + "…"


def describe(tool, inp):
    """One short line for a tool call."""
    base = lambda p: os.path.basename(str(p).rstrip("/")) or str(p)
    if tool == "Bash":
        return "$ " + short(inp.get("description") or inp.get("command", ""), 40)
    if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        return "✎ " + base(inp.get("file_path") or inp.get("notebook_path", ""))
    if tool == "Read":
        return "◉ " + base(inp.get("file_path", ""))
    if tool in ("Grep", "Glob"):
        return "⌕ " + short(inp.get("pattern", ""), 36)
    if tool in ("WebSearch", "WebFetch"):
        return "◍ " + short(inp.get("query") or re.sub(r"^https?://", "", inp.get("url", "")), 36)
    if tool in ("Agent", "Task"):
        who = inp.get("subagent_type") or "agent"
        return "↯ " + short(f"{who}: {inp.get('description', '')}", 40)
    if tool == "Skill":
        return "★ " + short(inp.get("skill", ""), 36)
    if tool.startswith("mcp__"):
        parts = tool.split("__")
        return "⚙ " + short(" ".join(parts[1:]), 36)
    return "· " + tool


def load(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {"todos": {}}


def task_id(resp):
    if isinstance(resp, dict):
        t = resp.get("task") if isinstance(resp.get("task"), dict) else resp
        if t.get("id") is not None:
            return str(t["id"])
        resp = json.dumps(resp)
    m = re.search(r"#(\d+)", str(resp))
    return m.group(1) if m else None


def update_todos(state, tool, inp, resp):
    todos = state.setdefault("todos", {})
    if tool == "TodoWrite":
        todos.clear()
        for i, t in enumerate(inp.get("todos") or []):
            todos[str(i)] = {"subject": t.get("content", ""), "active": t.get("activeForm", ""), "status": t.get("status", "pending")}
    elif tool == "TaskCreate":
        tid = task_id(resp) or str(len(todos) + 1)
        todos[tid] = {"subject": inp.get("subject", ""), "active": inp.get("activeForm", ""), "status": "pending"}
    elif tool == "TaskUpdate":
        tid = str(inp.get("taskId", ""))
        t = todos.setdefault(tid, {"subject": "", "active": "", "status": "pending"})
        for key, field in (("status", "status"), ("subject", "subject"), ("activeForm", "active")):
            if inp.get(key):
                t[field] = inp[key]
        if t["status"] == "deleted":
            todos.pop(tid, None)
    else:
        return False
    return True


def main():
    pane = os.environ.get("HERDR_PANE_ID")
    if os.environ.get("HERDR_ENV") != "1" or not pane:
        return
    try:
        hook = json.load(sys.stdin)
    except Exception:
        return
    if hook.get("agent_id"):  # subagents share the pane; only the main session reports
        return
    event = hook.get("hook_event_name", "")
    tool = hook.get("tool_name", "")
    inp = hook.get("tool_input") or {}

    os.makedirs(STATE_DIR, exist_ok=True)
    path = os.path.join(STATE_DIR, pane.replace(":", "_") + ".json")
    state = load(path)

    if event == "PreToolUse":
        state["doing"] = describe(tool, inp)
    elif event == "PostToolUse":
        update_todos(state, tool, inp, hook.get("tool_response"))
    elif event == "UserPromptSubmit":
        state["doing"] = "… thinking"
    elif event == "Stop":
        state["doing"] = ""
    else:
        return

    todos = state.get("todos", {}).values()
    total = len(todos)
    done = sum(t["status"] == "completed" for t in todos)
    current = next((t for t in todos if t["status"] == "in_progress"), None)
    if total and done == total:
        step = "✓ all done"
    elif current:
        step = current.get("active") or current.get("subject", "")
    else:
        step = ""
    state.update(pane=pane, cwd=hook.get("cwd", ""), done=done, total=total, step=step, updated=time.time())

    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f)
    os.replace(tmp, path)

    cmd = ["herdr", "pane", "report-metadata", pane, "--source", "claude-progress", "--seq", str(time.time_ns())]
    tokens = {"bar": bar(done, total) if total else "", "count": f"{done}/{total}" if total else "",
              "step": short(step), "doing": state.get("doing", "")}
    for name, value in tokens.items():
        cmd += ["--token", f"{name}={value}"] if value else ["--clear-token", name]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
