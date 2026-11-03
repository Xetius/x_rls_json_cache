# RLS JSON Cache (`x_rls_json_cache`)

A BeamNG.drive mod that keeps frequently re-read JSON files in memory, so BeamNG and RLS Career Overhaul
stop reading the same files from disk again and again.

## What it caches

| Files | Why they get re-read |
|---|---|
| `/vehicles/**/info*.json`, `/vehicles/**/*.pc` | BeamNG rebuilds its whole vehicle list (about 8,700 files with a large mod list) every time something calls `core_vehicles.clearCache()`: entering garage mode, saving a vehicle configuration. RLS's value calculator also reads `.pc` files thousands of times a session. |
| `/levels/*/streetKnights/*.json` | RLS rescans the Street Knights venues hundreds of times a session. |

Everything else, including save files and `.jbeam` part files, goes straight to BeamNG's normal reader.

## Measured results

From in-game testing with RLS Career Overhaul 2.8.0.1 and a large mod list (BeamNG 0.40.4):

| | Without cache | With cache |
|---|---|---|
| Vehicle-list rebuild | 2,465 ms | 511 ms (cache filled) |
| RLS Street Knights venue reads | ~430 ms per session | ~100 ms |
| RLS value calculator `.pc` reads | ~440 ms per session | ~50 ms |
| Average cached read | 0.16–0.22 ms from disk | 0.01–0.02 ms |
| Memory | | ~24 MB for 8,759 files |

The first build of the vehicle list each session is not faster: the cache fills as it goes.

## How it works

`lua/ge/extensions/xRlsJsonCache.lua` replaces the global `jsonReadFile` when the mod loads.

- **Storage:** each cached file is kept as one `string.buffer`-encoded string. A hit decodes a fresh table,
  so callers can change what they get back without affecting the cache. One string per file also keeps the
  Lua garbage collector's work small.
- **Missing files:** a read that returns nothing is remembered as well.
- **Paths:** case and slashes are normalised (`vehicles\Pickup\INFO.json` and `/vehicles/pickup/info.json`
  are the same entry).
- **Invalidation:**
  - writing a cached path through `jsonWriteFile` or `writeFile` drops that entry;
  - `onFileChanged` for a cached path drops that entry;
  - `onModActivated`, `onModDeactivated`, or a file change under `/mods/` clears everything.
- **Unloading** the extension restores the original functions.

`scripts/x_rls_json_cache/modScript.lua` loads the extension at mod-script time, before the vehicle list is first
built.

## Console commands (GE Lua)

| Command | What it does |
|---|---|
| `xRlsJsonCache.stats()` | Prints version, entries, memory, hits, misses and average read times. Also logged on exit. |
| `xRlsJsonCache.setEnabled(false)` | Turns caching off and frees the memory. `true` turns it back on. |
| `xRlsJsonCache.clear()` | Empties the cache. |

Timing a vehicle-list rebuild with the cache off, empty and filled:

```lua
local function t(on) xRlsJsonCache.setEnabled(on); core_vehicles.clearCache(); local s=os.clockhp(); core_vehicles.getConfigList(); return (os.clockhp()-s)*1000 end; local off=t(false); local cold=t(true); local warm=t(true); print(string.format("rebuild: cache off %.0f ms | cache on, empty %.0f ms | cache on, filled %.0f ms", off, cold, warm))
```

## Building a release

1. Bump `version_string` in `mod_info/x_rls_json_cache/info.json` and `M.version` in
   `lua/ge/extensions/xRlsJsonCache.lua` (the build fails if they differ), and add a `CHANGELOG.md` entry.
2. Run:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\build.ps1
   ```

   This syntax-checks the Lua (when `luajit` is on `PATH`) and writes `dist\x_rls_json_cache_<version>.zip`
   containing only `lua/`, `scripts/` and `mod_info/`. Add `-Install` to also copy the zip into your BeamNG
   mods folder, replacing older versions.

3. To publish, commit the changes, then tag the commit with the bare version and push the tag:

   ```bash
   git tag 0.0.2
   git push origin 0.0.2
   ```

   `.github/workflows/release.yml` then checks the tag is a semver version (no `v` prefix; pre-releases
   like `0.1.0-beta.1` are marked as such) that matches `version_string`, builds the zip and creates a
   GitHub release for it, with the tag's `CHANGELOG.md` section as the release notes. The run fails if
   the versions differ or the changelog has no `## <version>` heading.

`mod_info/x_rls_json_cache/` uses `x_rls_json_cache` as a placeholder tag. If the mod is published on the BeamNG
repository, rename that folder to the tag the repository assigns.

## Repository layout

```
lua/ge/extensions/xRlsJsonCache.lua       the cache
scripts/x_rls_json_cache/modScript.lua    loads it at startup
mod_info/x_rls_json_cache/info.json       title, version and repository description
build.ps1                                 packages dist/x_rls_json_cache_<version>.zip
.github/workflows/release.yml             builds and publishes a release when a version tag is pushed
```
