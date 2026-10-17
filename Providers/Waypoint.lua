-- The game's own waypoint (a map pin), tracked, so its marker shows on the screen. AzerothGPS, Waypoint
-- UI, Jazkyr's Northstar and most arrows pick it up. Only on a map that takes one
-- (C_Map.CanSetUserWaypointOnMap); there is one waypoint, so Cancel leaves it alone once someone
-- else has moved it.

-- The waypoint API is missing on Classic Era clients; Usable checks for it before anything is called.
---@diagnostic disable: wrong-flavor-api

local lib = LibStub("LibGoThere-1.0") --[[@as LibGoThere]]

local provider = { id = "waypoint", order = 40 } --[[@as LibGoThereProvider]]

function provider:Usable()
    return type(C_Map.SetUserWaypoint) == "function" and type(UiMapPoint) == "table"
end

---@param _ string the owner
---@param map number
---@param x number
---@param y number
---@return UiMapPoint? point
function provider:Navigate(_, map, x, y)
    if not C_Map.CanSetUserWaypointOnMap(map) then return nil end
    local point = UiMapPoint.CreateFromCoordinates(map, x, y)
    if not C_Map.SetUserWaypoint(point) then return nil end
    C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    return point
end

---A waypoint as text, to compare: the game hands out a new table each time.
---@param point UiMapPoint
---@return string
local function Key(point)
    return point.uiMapID .. ":" .. point.position.x .. ":" .. point.position.y
end

---@param _ string the owner
---@param point UiMapPoint
---@return boolean
function provider:Cancel(_, point)
    local current = C_Map.GetUserWaypoint()
    if not current or Key(current) ~= Key(point) then return false end
    C_Map.ClearUserWaypoint()
    return true
end

lib:RegisterProvider(provider)
