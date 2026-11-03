# Changelog

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
