# Changelog

## 0.0.3 - 2026-11-03

No change to how the cache behaves.

- Renamed the mod to `x_rls_json_cache` and the extension to `xRlsJsonCache`. The console commands are
  now `xRlsJsonCache.stats()`, `xRlsJsonCache.clear()` and `xRlsJsonCache.setEnabled(bool)`. Remove
  any older `x_rls_cache_v*.zip` or `xRlsCache_v*.zip` from your mods folder.
- Release zips are now named `x_rls_json_cache_<version>.zip`.
- Releases are built and published by GitHub Actions when a version tag is pushed.
- `build.ps1` also runs under PowerShell 7 on Linux.

## 0.0.1 - 2026-10-31

First release.

- Caches vehicle `info*.json` and `.pc` files, and RLS Street Knights venue files, in memory as
  `string.buffer` blobs. Each read returns a fresh table.
- Cache survives `core_vehicles.clearCache()`, so vehicle-list rebuilds (garage mode, saving a
  configuration) read from memory: about 2.5 s down to 0.5 s in testing.
- Missing files are remembered too, which covers RLS's value calculator probing for `.pc` paths that
  don't exist.
- Entries are dropped on `jsonWriteFile`/`writeFile` and `onFileChanged`; the whole cache clears when mods
  are activated or deactivated or files under `/mods/` change.
- Console: `xRlsJsonCache.stats()`, `xRlsJsonCache.clear()`, `xRlsJsonCache.setEnabled(bool)`.
