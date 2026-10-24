-- Waypoint UI (WoW: Forever and retail): a waypoint shown in the world, which it routes itself
-- through FarstriderLib or Mapzeroth when either is there. WaypointUIAPI.Navigation's
-- NewUserNavigation{ name, mapID, x, y } gives the navigation it now tracks; ClearUserNavigation
-- takes the tracked one away, so Cancel does that only while ours is still the one tracked.
-- Coordinates 0 to 1.

local lib = LibStub("LibGoThere-1.0") --[[@as LibGoThere]]

local provider = { id = "waypointui", addon = "WaypointUI", order = 24 } --[[@as LibGoThereProvider]]

---Waypoint UI's navigation API, nil without it.
---@return WaypointUINavigationAPI?
local function API()
    if type(WaypointUIAPI) ~= "table" then return nil end
    ---@type WaypointUINavigationAPI?
    local api = (WaypointUIAPI --[[@as {Navigation: WaypointUINavigationAPI?}]]).Navigation
    if type(api) == "table" and type(api.NewUserNavigation) == "function" then return api end
end

function provider:Usable()
    return API() ~= nil
end

---@param _ string the owner
---@param map number
---@param x number
---@param y number
---@param label string?
---@return WaypointUINavigation? navigation
function provider:Navigate(_, map, x, y, label)
    return (API() --[[@as WaypointUINavigationAPI]]).NewUserNavigation({ name = label, mapID = map, x = x, y = y })
end

---@param _ string the owner
---@param navigation WaypointUINavigation
---@return boolean
function provider:Cancel(_, navigation)
    local api = API() --[[@as WaypointUINavigationAPI]]
    if api.GetUserNavigation() ~= navigation then return false end
    api.ClearUserNavigation()
    return true
end

lib:RegisterProvider(provider)
