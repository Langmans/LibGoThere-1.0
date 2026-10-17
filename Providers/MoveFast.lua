-- MoveFast (MIT): a route with its steps and arrow, and travel times. MoveFast documents no API for
-- other addons; this file calls what its own code does, through the global MoveFast:
--   Map:Point(uiMapID, x, y)      a point from map coordinates in percent;
--   Router:Route(nil, dest, opts) a route from the player to dest.points: { total = seconds, ... },
--                                 or nil and why; the router has nodes only after PLAYER_LOGIN;
--   Tracker:Start(route), Tracker:Stop();
--   Recorder:ScanKnown()          reads the known flight paths before a route is planned (optional).
-- Each is checked before use. Planning takes a while, so a travel time is kept for a minute while
-- the player stays on the same map, or until ForgetTravelTimes.

local lib = LibStub("LibGoThere-1.0") --[[@as LibGoThere]]

local KEEP_SECONDS = 60

---MoveFast, when it is loaded, initialised and has every part this file uses.
---@return MoveFastAddon?
local function MF()
    local mf = MoveFast
    if type(mf) ~= "table" then return nil end
    local router, map, tracker = mf.Router, mf.Map, mf.Tracker
    if type(router) ~= "table" or type(router.Route) ~= "function" or type(router.nodes) ~= "table" then return nil end
    if type(map) ~= "table" or type(map.Point) ~= "function" then return nil end
    if type(tracker) ~= "table" or type(tracker.Start) ~= "function" then return nil end
    return mf
end

---A route to a spot (coordinates 0 to 1), or nil.
---@param mf MoveFastAddon
---@param map number
---@param x number
---@param y number
---@param label string?
---@param opts table?
---@return MoveFastRoute?
local function Plan(mf, map, x, y, label, opts)
    ---@type table
    local point = mf.Map:Point(map, x * 100, y * 100)
    point.label = label
    ---@type MoveFastRoute?
    local route = mf.Router:Route(nil, { kind = "point", name = label, points = { point }, radius = 15 }, opts)
    return type(route) == "table" and type(route.total) == "number" and route or nil
end

local provider = { id = "movefast", addon = "MoveFast", order = 20 } --[[@as LibGoThereProvider]]

function provider:Usable()
    return MF() ~= nil
end

---@param _ string the owner
---@param map number
---@param x number
---@param y number
---@param label string?
---@return MoveFastRoute?
function provider:Navigate(_, map, x, y, label)
    local mf = MF() --[[@as MoveFastAddon]]
    local recorder = mf.Recorder
    if type(recorder) == "table" and type(recorder.ScanKnown) == "function" then recorder:ScanKnown() end
    local route = Plan(mf, map, x, y, label)
    if not route then return nil end
    mf.Tracker:Start(route)
    return route
end

---@return boolean
function provider:Cancel()
    local tracker = (MF() --[[@as MoveFastAddon]]).Tracker
    tracker:Stop()
    return true
end

-- Travel times per "map:x:y" target: seconds, or false for no route, and when they were planned;
-- for the player's map in keptMap, another map starts over.
---@type table<string, {seconds: number|false, at: number}>
local kept = {}
---@type number?
local keptMap

function provider:Forget()
    kept = {}
end

---MoveFast plans from where the player stands, so only the player's map matters here.
---@param fromMap number
---@param _ number the player's x
---@param __ number the player's y
---@param map number
---@param x number
---@param y number
---@return number?
function provider:TravelTime(fromMap, _, __, map, x, y)
    if fromMap ~= keptMap then
        kept, keptMap = {}, fromMap
    end
    local key = map .. ":" .. x .. ":" .. y
    local hit = kept[key]
    if not hit or GetTime() - hit.at >= KEEP_SECONDS then
        -- noTips: no second plan for "faster without the hearthstone" and the like.
        local route = Plan(MF() --[[@as MoveFastAddon]], map, x, y, nil, { noTips = true })
        hit = { seconds = route and route.total or false, at = GetTime() }
        kept[key] = hit
    end
    return hit.seconds or nil
end

lib:RegisterProvider(provider)
