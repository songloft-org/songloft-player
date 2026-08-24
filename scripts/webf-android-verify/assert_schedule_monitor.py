#!/usr/bin/env python3
"""Assert miot's global schedule actions (enable/disable conversation monitor) work.

Reference case: songloft-org/songloft-plugin-miot#89 — the plugin's schedule
handler validated task params against a 5-action switch that predates
enable_monitor / disable_monitor, so both fell through to `default` and the task
was rejected with "未知的动作类型: enable_monitor". Nothing reached the DB.

Four checks, in ascending order of how hard they are to fake:

1. With the default action (play_playlist) the editor publishes a target-device
   section. This is the *control* — without it, check 2 passing would only mean
   "the runner never scrolled far enough to see anything".
2. After switching the action to 开启对话监听, the target-device section and the
   playlist picker are gone. Global actions are not bound to a device.
3. The save toast says 定时任务已保存 (not 请输入任务名称 / an error), and the
   task list renders the Chinese label 开启对话监听 rather than the raw
   enable_monitor value.
4. The task is actually in the DB with action=enable_monitor, and carries no
   devices. This is the anchor: checks 1-3 only observe the editor, and #89 was
   a handler-side rejection. Today the editor happens to surface it (the error
   toast replaces the success one), but that coupling is incidental — a refactor
   that closes the editor before awaiting the POST would make checks 1-3 pass on
   a broken build, so the backend read stays the load-bearing assertion.

Evidence comes from the accessibility tree (uiautomator dump), not from pixels:
every string this file looks for is a WebF text node published as content-desc.
"""

from __future__ import annotations

import argparse
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# The runner's capture names, so a rename shows up here instead of silently
# turning a check into a no-op.
DEFAULT_SHOTS = ("12-default-bottom", "13-default-bottom-2")
GLOBAL_SHOTS = ("16-global-action", "17-name-filled", "18-global-bottom")
TOAST_SHOT = "19-toast"
LIST_SHOT = "20-list-after-save"

TARGET_SECTION = ("目标设备", "所有受管理设备")
PLAYLIST_FIELD = "选择歌单"
TASK_NAME = "WebF-issue89"


def node_texts(path: Path) -> list[str]:
    if not path.exists():
        return []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return []
    out = []
    for node in root.iter("node"):
        for key in ("content-desc", "text"):
            value = node.attrib.get(key, "").strip()
            if value:
                out.append(value)
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path, help="artifact directory")
    args = parser.parse_args()
    out: Path = args.out

    texts = {name: node_texts(out / f"{name}.xml")
             for name in (*DEFAULT_SHOTS, *GLOBAL_SHOTS, TOAST_SHOT, LIST_SHOT)}
    failures: list[str] = []

    # 1) control: the default action does publish a target-device section
    seen_default = {name for name in DEFAULT_SHOTS
                    for label in TARGET_SECTION if label in texts[name]}
    if not seen_default:
        failures.append(
            f"default action (play_playlist) never published {TARGET_SECTION} in "
            f"{list(DEFAULT_SHOTS)} — the runner probably did not scroll to the "
            "bottom of the editor, so check 2 proves nothing")

    # 2) the global action hides it
    for name in GLOBAL_SHOTS:
        leaked = [label for label in (*TARGET_SECTION, PLAYLIST_FIELD) if label in texts[name]]
        if leaked:
            failures.append(f"{name}: global action still shows {leaked}")

    # 3) save toast + Chinese label in the list
    toast = texts[TOAST_SHOT]
    if "定时任务已保存" not in toast:
        failures.append(f"{TOAST_SHOT}: missing 定时任务已保存 toast (got {toast[:12]}…)")
    # Judge the list on the post-toast capture alone. The toast capture is a
    # full-screen dump that happens to contain the list too, so folding it in
    # here would let a missing/blank 20-* still pass these three.
    listing = texts[LIST_SHOT]
    if not any("开启对话监听" in t for t in listing):
        failures.append(f"{LIST_SHOT}: task list does not render the label 开启对话监听")
    if any("enable_monitor" in t for t in listing):
        failures.append(f"{LIST_SHOT}: task list leaks the raw action value enable_monitor")
    if not any(TASK_NAME in t for t in listing):
        failures.append(f"{LIST_SHOT}: saved task {TASK_NAME!r} not in the list")

    # 4) the anchor: it reached the DB
    try:
        after = json.loads((out / "schedules-after.json").read_text())
        tasks = after.get("data", {}).get("tasks") or []
    except (OSError, ValueError) as exc:
        tasks = []
        failures.append(f"schedules-after.json unreadable: {exc}")
    saved = [t for t in tasks if t.get("action") == "enable_monitor"]
    if not saved:
        failures.append(
            "no enable_monitor task in GET /schedules — the handler rejected it "
            f"(this is the #89 regression). tasks={tasks}")
    else:
        target = saved[0].get("target") or {}
        if target.get("devices"):
            failures.append(f"global task should carry no devices, got {target['devices']}")

    for line in ("check 1 (default shows target section)",
                 "check 2 (global action hides it)",
                 "check 3 (toast + Chinese label)",
                 "check 4 (task persisted)"):
        print(f"[assert] {line}")
    sys.stdout.flush()  # keep the checklist above the unbuffered stderr failures
    if failures:
        print("\n[assert] FAILED:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
        return 1
    print(f"[assert] PASS — saved task: {json.dumps(saved[0], ensure_ascii=False)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
