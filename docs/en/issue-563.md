# #563 Server favorite synchronization

Authenticated sessions subscribe to `/playlists/favorites/changes` and reconcile complete favorite IDs on invalidation, independently of settings/plugin WebViews. Backgrounding, logout and server/account changes stop old subscriptions; resume reconciles. Older-host 404 stops subscription; network failures back off.

Baseline `87a7699d2580b8c4463fa43e159d7bff18f6df29` plus uncommitted tree. `flutter analyze` and all 831 `flutter test` cases passed. New tests cover hanging requests, failed-refresh cursors, late events after stop, both favorite caches and old initialization. Isolating the old service reproduces ID 2 being replaced by 1.

Actual Docker Chrome library rows change Favorite→Unfavorite→Favorite on real QuickJS writes without heart clicks or page reload. Profile Web build passed.

Evidence: test/build logs, screenshots and `worktree-final.json` under `/tmp/songloft-563-extra/`. Initial parallel compilation hit memory pressure and was retried sequentially by target. The first Lynx full suite failed on a missing artifact from that build; the full suite passed after successful builds.

Not run: Android/iOS or desktop devices, release packages and remote CI. This records pre-commit code, Web and injected checks only. The user subsequently authorized commits, pushes, SDK publication and an Issue reply. GitHub and the parent delivery record govern final commits and CI.
