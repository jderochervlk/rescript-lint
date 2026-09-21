# Watch Discovery Work Log

## 2026-09-21

- Continued after pushing banned API resolution and runtime throws contracts as
  `2beb32d` to `origin/main`.
- Inspected the watch loop, CLI dispatch, input selection and project discovery.
  The loop previously observed only the initial selected file list.
- Added a dynamic snapshot loop, retaining the existing fixed-file adapter.
  Project snapshots rediscover source files and observe `rescript.json`, explicit
  input files, and supplied linter configuration paths. Discovery failures are
  snapshot state, so failure and recovery trigger reruns without polling spam.
- Project declarations are watched even when lint inputs are explicit files,
  because changing a provider can change diagnostics in an unchanged consumer.
- Added deterministic tests for additions/deletions, provider changes, exclusions,
  linter-config parsing/recovery, dependency contracts, report changes and disabled
  dependency loading. A real CLI transcript starts with an empty project, adds a
  source, observes a malformed config and recovers. Existing signal/fix checks
  remain intact.
- `make check coverage` passed, watcher **93.22%**, overall **95.47%**. Release
  JSON watch smoke emitted one valid record, stderr status banners and exit 143.
