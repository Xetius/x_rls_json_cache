<#
.SYNOPSIS
  Packages the mod as dist\x_rls_json_cache_<version>.zip.

.DESCRIPTION
  Reads the version from mod_info\x_rls_json_cache\info.json, checks it matches
  M.version in the Lua extension, syntax-checks the Lua files with LuaJIT when
  it is installed, and zips lua\, scripts\ and mod_info\ with forward-slash
  entry names (BeamNG needs these; Compress-Archive on PowerShell 5.1 writes
  backslashes).

.PARAMETER Install
  Also copy the zip into the BeamNG mods folder (removing older
  x_rls_json_cache_*.zip files there).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\build.ps1
  powershell -ExecutionPolicy Bypass -File .\build.ps1 -Install
#>
param([switch]$Install)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$modName = 'x_rls_json_cache'
$includeDirs = @('lua', 'scripts', 'mod_info')

$info = Get-Content -Raw (Join-Path $root "mod_info\$modName\info.json") | ConvertFrom-Json
$version = $info.version_string
if (-not $version) { throw 'version_string is missing from info.json' }

$luaMain = Join-Path $root 'lua\ge\extensions\xRlsJsonCache.lua'
$luaVersion = [regex]::Match((Get-Content -Raw $luaMain), 'M\.version\s*=\s*"([^"]+)"').Groups[1].Value
if ($luaVersion -ne $version) {
  throw "Version mismatch: info.json says '$version' but xRlsJsonCache.lua says '$luaVersion'"
}

$luajit = Get-Command luajit -ErrorAction SilentlyContinue
if ($luajit) {
  Get-ChildItem (Join-Path $root 'lua'), (Join-Path $root 'scripts') -Recurse -Filter *.lua | ForEach-Object {
    & $luajit.Source -e "assert(loadfile([[$($_.FullName)]]))"
    if ($LASTEXITCODE -ne 0) { throw "Lua syntax error in $($_.FullName)" }
  }
} else {
  Write-Warning 'luajit not found; skipping Lua syntax check'
}

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$zipPath = Join-Path $dist "${modName}_$version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
  foreach ($dir in $includeDirs) {
    Get-ChildItem (Join-Path $root $dir) -Recurse -File | ForEach-Object {
      $entry = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
      [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entry, 'Optimal')
    }
  }
} finally {
  $zip.Dispose()
}

$zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
$zip.Entries | ForEach-Object { "  $($_.FullName)" }
$zip.Dispose()
Write-Host "Built $zipPath"

if ($Install) {
  $mods = Join-Path $env:LOCALAPPDATA 'BeamNG\BeamNG.drive\current\mods'
  Get-ChildItem $mods -Filter "${modName}_*.zip" | Remove-Item -Force
  Copy-Item $zipPath $mods
  Write-Host "Installed to $mods"
}
