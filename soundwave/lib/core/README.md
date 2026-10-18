# Shared data layer

This package boundary is the common contract for search, downloads, and player
features. Keep SQL and filesystem work out of widgets; feature controllers call
repository contracts and repositories use these models and DAOs.

## Identity and units

- `Song.id` is a stable app-wide identifier. Use a deterministic value such as
  `provider:sourceId`; never use a temporary audio URL as identity.
- `Song.durationMs`, `DownloadRecord.bytesReceived`, and
  `DownloadRecord.totalBytes` use milliseconds and bytes respectively.
- `DownloadRecord.localPath` is relative to the app's private audio directory.
  SQLite stores metadata; audio contents belong in files.
- A nullable total means progress is indeterminate. `progress` is a fraction
  from `0.0` through `1.0`, or `null` when it cannot be calculated.

## Repository behavior

- `CatalogRepository.search('')` may return the available catalog/cache;
  `findById` returns `null` when absent. `saveAll` stores canonical songs.
- `DownloadRepository.watchDownloads` emits complete snapshots. Enqueueing a
  duplicate should throw `RepositoryException(conflict, ...)`; retry, removal,
  or undo for a missing song should throw `RepositoryException(notFound, ...)`.
- `AudioFileStore.commit` promotes a completed temporary file and returns its
  relative final path. Callers record that path only after the file is committed.
- Playback blocks are scoped by collection ID. A song must belong to that
  collection before it can be blocked; removing membership clears its block.
- `RepositoryException` codes describe expected recoverable failures. Preserve
  the original cause when wrapping lower-level errors; unexpected programming
  errors should not be disguised as repository failures.

## SQLite and providers

`schema.dart` defines version 1. Add future schema changes as sequential,
version-checked migrations; do not edit a released migration in place. Foreign
keys cascade from songs and playlists to dependent metadata. Use
`soundwaveDatabaseProvider` as the single database lifecycle owner and the DAO
providers for ordinary access. Use a database transaction when one operation
must update multiple tables. `dataModeProvider` selects SQLite on Android and
the demo mode on Chrome/other targets.

`test/support/test_songs.dart` holds stable fixture IDs; fake catalog, download,
file, and playback-preference repositories live in
`test/support/fake_repositories.dart`.
