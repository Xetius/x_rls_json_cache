local M = {}
local logTag = "xRlsCache"

M.version = "0.0.1"

local buffer = require("string.buffer")
local clock = os.clockhp or os.clock

local NIL = false

local originals = {}
local enabled = true
local cache = {}
local stats

local function resetStats()
  stats = {
    hits = 0,
    nilHits = 0,
    misses = 0,
    passthrough = 0,
    entries = 0,
    bytes = 0,
    invalidations = 0,
    clears = 0,
    encodeFailures = 0,
    hitTime = 0,
    missTime = 0,
  }
end
resetStats()

local function normalize(path)
  if type(path) ~= "string" then return nil end
  local p = path:gsub("\\", "/"):lower()
  if p:sub(1, 1) ~= "/" then p = "/" .. p end
  return p
end

local function isCacheable(p)
  if p:find("^/vehicles/") then
    if p:find("%.pc$") then return true end
    local name = p:match("([^/]+)$")
    return name ~= nil and name:find("^info.*%.json$") ~= nil
  end
  return p:find("^/levels/[^/]+/streetknights/[^/]+%.json$") ~= nil
end

local function drop(key)
  local entry = cache[key]
  if entry == nil then return false end
  if entry ~= NIL then stats.bytes = stats.bytes - #entry end
  stats.entries = stats.entries - 1
  cache[key] = nil
  stats.invalidations = stats.invalidations + 1
  return true
end

local function clearAll(reason)
  if stats.entries > 0 then
    log("I", logTag, string.format("Clearing %d entries (%.1f MB): %s", stats.entries, stats.bytes/1e6, tostring(reason)))
  end
  cache = {}
  stats.entries, stats.bytes = 0, 0
  stats.clears = stats.clears + 1
end

local function store(key, value)
  if cache[key] == nil then stats.entries = stats.entries + 1 end
  cache[key] = value
  if value ~= NIL then stats.bytes = stats.bytes + #value end
end

local function cachedJsonReadFile(filename, ...)
  local key = enabled and normalize(filename)

  if not key or not isCacheable(key) then
    stats.passthrough = stats.passthrough + 1
    return originals.jsonReadFile(filename, ...)
  end

  local entry = cache[key]
  if entry ~= nil then
    if entry == NIL then
      stats.nilHits = stats.nilHits + 1
      return nil
    end
    local t0 = clock()
    local data = buffer.decode(entry)
    stats.hits = stats.hits + 1
    stats.hitTime = stats.hitTime + (clock() - t0)
    return data
  end

  local t0 = clock()
  local data = originals.jsonReadFile(filename, ...)
  stats.misses = stats.misses + 1
  if data == nil then
    store(key, NIL)
  elseif type(data) == "table" then
    local ok, encoded = pcall(buffer.encode, data)
    if ok then
      store(key, encoded)
    else
      stats.encodeFailures = stats.encodeFailures + 1
    end
  end
  stats.missTime = stats.missTime + (clock() - t0)
  return data
end

local function invalidatingWrite(originalName)
  return function(filename, ...)
    local key = normalize(filename)
    if key then drop(key) end
    return originals[originalName](filename, ...)
  end
end
local wrappedJsonWriteFile = invalidatingWrite("jsonWriteFile")
local wrappedWriteFile = invalidatingWrite("writeFile")

local function install()
  if originals.installed then return end
  originals.jsonReadFile = jsonReadFile
  originals.jsonWriteFile = jsonWriteFile
  originals.writeFile = writeFile
  jsonReadFile = cachedJsonReadFile
  jsonWriteFile = wrappedJsonWriteFile
  writeFile = wrappedWriteFile
  originals.installed = true
  log("I", logTag, "Installed JSON cache " .. M.version)
end

local function uninstall()
  if not originals.installed then return end
  if jsonReadFile == cachedJsonReadFile then jsonReadFile = originals.jsonReadFile end
  if jsonWriteFile == wrappedJsonWriteFile then jsonWriteFile = originals.jsonWriteFile end
  if writeFile == wrappedWriteFile then writeFile = originals.writeFile end
  originals.installed = false
  clearAll("unloaded")
  log("I", logTag, "Removed JSON cache")
end

function M.stats()
  local lookups = stats.hits + stats.nilHits + stats.misses
  local text = string.format(
    "xRlsCache " .. M.version .. ": %s | %d entries, %.1f MB | hits %d (+%d missing-file hits), misses %d, hit rate %.1f%% | " ..
    "avg hit %.3f ms, avg miss %.3f ms | invalidations %d, clears %d, encode failures %d, passthrough %d",
    enabled and "on" or "off", stats.entries, stats.bytes / 1e6,
    stats.hits, stats.nilHits, stats.misses,
    lookups > 0 and (stats.hits + stats.nilHits) * 100 / lookups or 0,
    stats.hits > 0 and stats.hitTime * 1000 / stats.hits or 0,
    stats.misses > 0 and stats.missTime * 1000 / stats.misses or 0,
    stats.invalidations, stats.clears, stats.encodeFailures, stats.passthrough)
  log("I", logTag, text)
  print(text)
  return stats
end

function M.clear()
  clearAll("console")
end

function M.setEnabled(value)
  enabled = value and true or false
  if not enabled then clearAll("disabled") end
  log("I", logTag, "Caching " .. (enabled and "enabled" or "disabled"))
end

function M.onFileChanged(filename, fileType)
  local key = normalize(filename)
  if not key then return end
  if key:find("^/mods/") then
    clearAll("mod file changed: " .. filename)
  elseif isCacheable(key) then
    drop(key)
  end
end

function M.onModActivated() clearAll("mod activated") end
function M.onModDeactivated() clearAll("mod deactivated") end

function M.onExit()
  M.stats()
end

function M.onExtensionUnloaded()
  uninstall()
end

install()

return M
