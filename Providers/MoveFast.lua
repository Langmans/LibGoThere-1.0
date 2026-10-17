-- MoveFast (MIT): a route with its steps and arrow, and travel times. MoveFast documents no API for
-- other addons; this file calls what its own code does, through the global MoveFast:
--   Map:Point(uiMapID, x, y)      a point from map coordinates in percent;
--   Router:Route(nil, dest, opts) a route from the player to the fastest-reached of dest.points:
--                                 { total = seconds, dest = { name = that point's label } }, or nil
--                                 and why; the router has nodes only after PLAYER_LOGIN;
--   Tracker:Start(route), Tracker:Stop();
--   Recorder:ScanKnown()          reads the known flight paths before a route is planned (optional).
-- Each is checked before use. Since one plan weighs several spots, Nearest asks once for all of
-- them. Planning takes a while, so a travel time is kept for a minute while the player stays on
-- the same map, or until ForgetTravelTimes.

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

---A route to the fastest-reached of several spots ({ uiMapID, x, y } each, 0 to 1), each spot
---labelled with `label` when there is one, else with its index, so the route's dest.name says
---which it chose. A spot on a map MoveFast has no data for (Map:Point gives nothing) is left out.
---Nil without a route, or without a spot MoveFast can place.
---@param spots LibGoTherePoint[]
---@param label string?
---@param opts table?
---@return MoveFastRoute?
local function Plan(spots, label, opts)
    local mf = MF() --[[@as MoveFastAddon]]
    ---@type table[]
    local points = {}
    for i, spot in ipairs(spots) do
        ---@type table?
        local point = mf.Map:Point(spot[1], spot[2] * 100, spot[3] * 100)
        if point then
            point.label = label or tostring(i)
            points[#points + 1] = point
        end
    end
    if #points == 0 then return nil end
    local dest = { kind = "point", name = points[1].label, points = points, radius = 15 }
    ---@type MoveFastRoute?
    local route = mf.Router:Route(nil, dest, opts)
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
    local route = Plan({ { map, x, y } } --[[@as LibGoTherePoint[] ]], label)
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

-- Answers per set of spots ("map:x:y" joined): seconds or false for no route, the chosen spot's
-- index, and when it was planned; for the player's map in keptMap, another map starts over.
---@type table<string, {seconds: number|false, index: integer, at: number}>
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
---@param spots LibGoTherePoint[]
---@return number? seconds
---@return integer? index
function provider:Nearest(fromMap, _, __, spots)
    if fromMap ~= keptMap then
        kept, keptMap = {}, fromMap
    end
    ---@type string[]
    local parts = {}
    for i, spot in ipairs(spots) do
        parts[i] = spot[1] .. ":" .. spot[2] .. ":" .. spot[3]
    end
    local key = table.concat(parts, ";")
    local hit = kept[key]
    if not hit or GetTime() - hit.at >= KEEP_SECONDS then
        -- noTips: no second plan for "faster without the hearthstone" and the like.
        local route = Plan(spots, nil, { noTips = true })
        local index = route and tonumber(route.dest and route.dest.name) or 1
        hit = { seconds = route and route.total or false, index = index, at = GetTime() }
        kept[key] = hit
    end
    if not hit.seconds then return nil end
    return hit.seconds, --[[@as number]]
        hit.index
end

---@param fromMap number
---@param fromX number
---@param fromY number
---@param map number
---@param x number
---@param y number
---@return number?
function provider:TravelTime(fromMap, fromX, fromY, map, x, y)
    local seconds = self:Nearest(fromMap, fromX, fromY, { { map, x, y } } --[[@as LibGoTherePoint[] ]])
    return seconds
end

lib:RegisterProvider(provider)
