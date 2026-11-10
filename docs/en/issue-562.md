# #562 Flutter follow-up

2026-11-11; baseline `59bc9c7def13e73ced81df045cf77e3ce32f0426`, uncommitted. Shared playlist/song tags, independent tag-filtered browsing, source labels, scrolling playlist titles, 96px phone covers, readable counts and compact rows are implemented, including all home layouts. Machine-only Navidrome markers are hidden only for display; stored descriptions remain intact.

Static analysis and the first 819-test full suite passed. Home changes then passed 119 affected tests, including 390px/1600px source labels. Final full-suite/build/browser results are recorded centrally in the parent repository's `docs/en/issue-562-verification.md`. The row index regression caught 4px overflow during development and passes after fixing line bounds.

Chrome evidence is under `/tmp/songloft-562-implementation/`. Reporter Honor/HarmonyOS Bundle hardware and native builds: Not run. No commit, push, release or Issue write.

Final full suite with `--concurrency=2`: 821 pass; 48 affected tests pass after the final count-font adjustment. Analysis and final JavaScript Web build (no CDN or Wasm probe) pass. Actual Chrome home/detail show source tags, artwork and compact layouts. Opening the Navidrome tag defaults to playlists; its actual `tag_id=1` request, linked playlist and member artwork are verified.

Same-day review found that deleting a tag refreshed the catalog but retained cached playlist references, potentially displaying a wrong source after ID reuse. Playlist lists, details and binding caches now invalidate together. A new actual-delete widget regression retains `tag:1` before the fix and passes afterward. The parent verification record tracks the revised worktree and affected checks.

The same review refreshes cached visible-playlist tag counts after individual/batch deletion and hiding/restoring playlists. Each operation has a regression failing before the fix.

Final review object: 94 affected tests, analysis and the embedded JavaScript Web build pass. The initial 821-test full suite and browser evidence identify the earlier snapshot; the parent record distinguishes verification objects.
