-- TomTom: a waypoint with its arrow, which many other addons follow as well (Waypoint Tracker,
-- Jazkyr's Northstar, ...). TomTom:AddWaypoint(map, x, y, { title, from }) gives the waypoint's
-- uid, TomTom:RemoveWaypoint(uid) takes it back. Coordinates 0 to 1.

local lib = LibStub("LibGoThere-1.0") --[[@as LibGoThere]]

local provider = { id = "tomtom", addon = "TomTom", order = 30 } --[[@as LibGoThereProvider]]

function provider:Usable()
    return type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function"
end

---@param owner string
---@param map number
---@param x number
---@param y number
---@param label string?
---@return table? uid
function provider:Navigate(owner, map, x, y, label)
    return (TomTom --[[@as TomTomAddon]]):AddWaypoint(map, x, y, { title = label, from = owner })
end

---@param _ string the owner
---@param uid table
---@return boolean
function provider:Cancel(_, uid)
    (TomTom --[[@as TomTomAddon]]):RemoveWaypoint(uid)
    return true
end

lib:RegisterProvider(provider)
