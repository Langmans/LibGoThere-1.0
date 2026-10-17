-- Shortest Path Forever: a route by foot, flight path, boat and the hearthstone, and travel times.
-- Through its documented API, ShortestPathForever.API (version 1): Navigate(owner, map, x, y,
-- title), Cancel(owner), Estimate(fromMap, fromX, fromY, toMap, toX, toY). Coordinates 0 to 1.
-- SPF is GPL-3; the library only calls it.

local lib = LibStub("LibGoThere-1.0") --[[@as LibGoThere]]

---SPF's API, when it is loaded and has what this file uses.
---@return SPFPublicAPI?
local function API()
    local spf = ShortestPathForever
    local api = type(spf) == "table" and spf.API
    if type(api) == "table" and (api.version or 0) >= 1 and type(api.Navigate) == "function" then return api end
    return nil
end

local provider = { id = "spf", addon = "ShortestPathForever", order = 10 } --[[@as LibGoThereProvider]]

function provider:Usable()
    return API() ~= nil
end

---@param owner string
---@param map number
---@param x number
---@param y number
---@param label string?
---@return boolean
function provider:Navigate(owner, map, x, y, label)
    return (API() --[[@as SPFPublicAPI]]).Navigate(owner, map, x, y, label) == true
end

---@param owner string
---@return boolean
function provider:Cancel(owner)
    return (API() --[[@as SPFPublicAPI]]).Cancel(owner) == true
end

---@param fromMap number
---@param fromX number
---@param fromY number
---@param map number
---@param x number
---@param y number
---@return number?
function provider:TravelTime(fromMap, fromX, fromY, map, x, y)
    local seconds = (API() --[[@as SPFPublicAPI]]).Estimate(fromMap, fromX, fromY, map, x, y)
    return seconds
end

lib:RegisterProvider(provider)
