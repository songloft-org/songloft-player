#!/usr/bin/env python3
"""Assert miot's playlist dropdown search works under real WebF.

Reference case: songloft-org/songloft#410 — the pre-WebF frontend had a
「搜索歌单」input pinned to the top of its playlist popup (static/js/search.js).
The WebF rewrite replaced that popup with the generic SlSelect, which never had
a search box, so the filter silently disappeared.

The load-bearing question this harness answers — and the only one a browser
cannot — is whether `flutter-cupertino-input` renders and accepts focus inside a
`position: fixed` panel. In a browser `useNativeUI` is false and the search box
degrades to a plain `<input>`, so the native path goes unexercised. This repo has
prior art for native elements laying out but never painting inside WebF popups
(songloft-org/songloft-plugin-miot#79, #81), hence the geometry checks below.

Six checks, in ascending order of how hard they are to fake:

1. The panel opens and a non-zero EditText sits between the trigger's bottom edge
    and the first option. Zero-sized or absent means the native input collapsed.
2. Typing lowercase `jazz` leaves only 「Jazz Night」 — case-insensitive substring
    filtering is live, not just a decorative text field.
3. Typing `0` leaves only 「Mix 0」. Every seeded playlist has 0 songs, so every
    label ends in「(0)」: matching against the label would keep all 14 rows. This
    is what pins the filter to SelectOption.searchText (the plain name) rather
    than the rendered label.
4. A no-match query renders the 「无匹配项」 empty row instead of a bare panel.
5. Picking an option while filtered closes the panel and updates the trigger
    label — proves the filtered rows are real, selectable options.
6. Reopening shows an empty search box and the full list. The query lives in a
    component-level ref while the panel itself is v-if'd away, so a missing reset
    would leave the list filtered by a keyword the user can no longer see.

Evidence comes from the accessibility tree (uiautomator dump), not from pixels:
every playlist row is a WebF text node published as content-desc. The search box
is the exception — WebF does not map aria-label onto content-desc, so EditText
nodes are identified by class plus position.
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

BOUNDS = re.compile(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]")
# The chevron glyph SlSelect renders in its trigger (Material `expand_more`).
# It is what separates the trigger from the option rows, which carry the same text.
# Spelled as an escape rather than pasted in: U+E5CF is a private-use codepoint,
# invisible in editors and easily mangled into U+FFFD by tooling.
CHEVRON = "\ue5cf"
# Seeded by run-playlist-search.sh, plus the two built-in playlists the migration
# pre-creates. Listed here so a rename in the runner shows up as a failure rather
# than silently turning the row counting into a no-op.
PLAYLIST_NAMES = (
    "收藏", "电台收藏",
    "Jazz Night", "KPop Hits", "Rock Classic", "Mix 0",
    "周杰伦精选", "周杰伦经典", "华语流行", "欧美金曲",
    "古典音乐", "粤语经典", "日语动漫", "睡前轻音乐",
)
PLACEHOLDER_ROW = "选择歌单"
EMPTY_ROW = "无匹配项"
SONG_COUNT_SUFFIX = re.compile(r"\s*\(\d+\)$")


class Report:
    def __init__(self) -> None:
        self.failures: list[str] = []

    def fail(self, msg: str) -> None:
        self.failures.append(msg)

    def check(self, ok: bool, msg: str) -> bool:
        if not ok:
            self.fail(msg)
        return ok


def nodes(path: Path, report: Report) -> list[dict]:
    try:
        root = ET.parse(path).getroot()
    except Exception as exc:  # noqa: BLE001
        report.fail(f"{path.name}: dump unreadable ({exc})")
        return []
    out = []
    for n in root.iter("node"):
        m = BOUNDS.fullmatch(n.attrib.get("bounds", ""))
        if not m:
            continue
        left, top, right, bottom = map(int, m.groups())
        out.append({
            "desc": (n.attrib.get("content-desc", "") or n.attrib.get("text", "")).strip(),
            "text": n.attrib.get("text", "").strip(),
            "cls": n.attrib.get("class", "").rsplit(".", 1)[-1],
            "box": (left, top, right, bottom),
        })
    return out


def find_trigger(ns: list[dict]) -> dict | None:
    """The dropdown trigger is the only Button carrying the chevron glyph."""
    hits = [n for n in ns if n["cls"] == "Button" and CHEVRON in n["desc"]]
    hits.sort(key=lambda n: n["box"][1])
    return hits[0] if hits else None


def option_rows(ns: list[dict], trigger_bottom: int) -> list[dict]:
    """Panel rows: below the trigger, and whose text is a playlist name /
    the allow-empty placeholder / the no-match row.

    Filtering by name rather than by container matters: the song list's own empty
    state (「没有匹配的歌曲」) sits behind the panel and would otherwise be counted
    as a row.
    """
    rows = []
    for n in ns:
        if n["box"][1] < trigger_bottom:
            continue
        desc = n["desc"]
        if desc in (PLACEHOLDER_ROW, EMPTY_ROW) or SONG_COUNT_SUFFIX.sub("", desc) in PLAYLIST_NAMES:
            rows.append(n)
    # A row shows up as both a Button and an inner View; dedupe on top edge.
    seen, uniq = set(), []
    for n in sorted(rows, key=lambda x: x["box"][1]):
        if n["box"][1] in seen:
            continue
        seen.add(n["box"][1])
        uniq.append(n)
    return uniq


def panel_edits(ns: list[dict], trigger_bottom: int, first_option_top: int | None) -> list[dict]:
    """EditText nodes belonging to the open panel's search row.

    Assumes the panel opens *downwards*, which holds for the main page's playlist
    dropdown: it sits at the top of the viewport, so positionPanel() always has
    room below. A dropdown low enough to flip above its trigger would put the
    search box at top < trigger_bottom and read as missing here — extending this
    harness to such a dropdown means revisiting this function.

    With no rows there is no open panel, so nothing can be "inside" it. Returning
    early matters: MainPage keeps its own song-search EditText below the trigger,
    and without this guard a closed panel would still report a search box.
    """
    if first_option_top is None:
        return []
    out = []
    for n in ns:
        if n["cls"] != "EditText":
            continue
        _, top, _, bottom = n["box"]
        # +20px of slack: the native input's box and the first row can abut.
        if top < trigger_bottom or bottom > first_option_top + 20:
            continue
        out.append(n)
    return sorted(out, key=lambda n: n["box"][1])


def playlist_names(rows: list[dict]) -> list[str]:
    return [
        SONG_COUNT_SUFFIX.sub("", r["desc"])
        for r in rows
        if r["desc"] not in (PLACEHOLDER_ROW, EMPTY_ROW)
    ]


def read(out: Path, tag: str, report: Report) -> dict:
    ns = nodes(out / f"{tag}.xml", report)
    trigger = find_trigger(ns)
    if trigger is None:
        report.fail(f"{tag}: dropdown trigger not found (is the miot tab even open?)")
        return {"tag": tag, "rows": [], "edits": [], "trigger": None}
    trigger_bottom = trigger["box"][3]
    rows = option_rows(ns, trigger_bottom)
    first_top = rows[0]["box"][1] if rows else None
    return {
        "tag": tag,
        "trigger": trigger,
        "trigger_bottom": trigger_bottom,
        "rows": rows,
        "row_texts": [r["desc"] for r in rows],
        "names": playlist_names(rows),
        "first_option_top": first_top,
        "edits": panel_edits(ns, trigger_bottom, first_top),
    }


def describe(state: dict) -> str:
    edit = state["edits"][0]["box"] if state["edits"] else None
    return (f"  {state['tag']}: trigger.bottom={state.get('trigger_bottom')} "
            f"search={edit} rows={state.get('row_texts')}")


def assert_search_box(state: dict, report: Report) -> None:
    tag = state["tag"]
    if not report.check(bool(state["edits"]),
                        f"{tag}: no EditText inside the panel — cupertino input "
                        f"did not render in the fixed container"):
        return
    left, top, right, bottom = state["edits"][0]["box"]
    report.check((right - left) > 0 and (bottom - top) > 0,
                 f"{tag}: search box collapsed to {right - left}x{bottom - top}")
    report.check(top >= state["trigger_bottom"],
                 f"{tag}: search box sits above the trigger "
                 f"(top={top} < trigger.bottom={state['trigger_bottom']})")
    if state["first_option_top"] is not None:
        report.check(bottom <= state["first_option_top"] + 20,
                    f"{tag}: search box overlaps the first option "
                    f"(bottom={bottom} > firstOption.top={state['first_option_top']})")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    out: Path = args.out
    report = Report()

    print("[assert] 1/6 panel opens with a rendered search box")
    opened = read(out, "51-panel-open", report)
    print(describe(opened))
    assert_search_box(opened, report)
    report.check(len(opened["names"]) >= 4,
                 f"51-panel-open: expected the full list, got {opened['names']}")

    print("[assert] 2/6 lowercase 'jazz' filters to Jazz Night")
    jazz = read(out, "53-filtered-jazz", report)
    print(describe(jazz))
    assert_search_box(jazz, report)
    report.check(jazz["names"] == ["Jazz Night"],
                 f"53-filtered-jazz: expected ['Jazz Night'], got {jazz['names']}")

    print("[assert] 3/6 '0' matches the plain name, not the label's (0) suffix")
    zero = read(out, "54-filtered-zero", report)
    print(describe(zero))
    report.check(zero["names"] == ["Mix 0"],
                 f"54-filtered-zero: expected ['Mix 0'], got {zero['names']} — "
                 f"matching the rendered label instead of SelectOption.searchText "
                 f"would keep every row, since all labels end in (0)")

    print("[assert] 4/6 no-match renders the empty row")
    empty = read(out, "55-no-match", report)
    print(describe(empty))
    report.check(EMPTY_ROW in empty["row_texts"],
                 f"55-no-match: missing 「{EMPTY_ROW}」, got {empty['row_texts']}")
    report.check(empty["names"] == [],
                 f"55-no-match: expected no options, got {empty['names']}")

    print("[assert] 5/6 picking a filtered option closes the panel and updates the label")
    kpop = read(out, "56-filtered-kpop", report)
    print(describe(kpop))
    report.check(kpop["names"] == ["KPop Hits"],
                 f"56-filtered-kpop: expected ['KPop Hits'], got {kpop['names']}")
    after = read(out, "57-after-select", report)
    print(describe(after))
    report.check(not after["rows"],
                 f"57-after-select: panel should be closed, still shows {after['row_texts']}")
    if after["trigger"] is not None:
        report.check("KPop Hits" in after["trigger"]["desc"],
                     f"57-after-select: trigger label not updated, "
                     f"got {after['trigger']['desc']!r}")

    print("[assert] 6/6 reopening resets the query and restores the full list")
    reopen = read(out, "58-reopen", report)
    print(describe(reopen))
    assert_search_box(reopen, report)
    if reopen["edits"]:
        residue = reopen["edits"][0]["text"]
        report.check(residue == "",
                     f"58-reopen: search box kept its previous query {residue!r}")
    report.check(len(reopen["names"]) >= 4,
                 f"58-reopen: list is still filtered by the previous keyword, "
                 f"only {reopen['names']} left")

    print()
    if report.failures:
        print(f"FAIL ({len(report.failures)})")
        for f in report.failures:
            print(f"  - {f}")
        return 1
    print("PASS — playlist dropdown search verified under real WebF")
    return 0


if __name__ == "__main__":
    sys.exit(main())
