-- A simulated WoW client for the library: the game's map and waypoint API, chat, and the route
-- addons the library hands a target to (Shortest Path Forever, MoveFast, TomTom), each only when a
-- test asks for it. Every value a test may vary is on the client object, and every call a provider
-- receives is recorded in client.calls. NewClient() resets the globals and loads the .toc's files
-- (LibStub included) into a fresh state, so tests never share it.

---@class TestClientOptions
---@field spf boolean|table? Shortest Path Forever loaded; a table overrides API functions
---@field moveFast boolean|table? MoveFast loaded and initialised; a table overrides parts
---@field tomTom boolean|table? TomTom loaded; a table overrides methods
---@field noWaypoint boolean? no C_Map.SetUserWaypoint (an old client)
---@field installed string[]? addons in the AddOns folder but not loaded

---Loads every file of the .toc into the current globals.
local function LoadToc()
    for _, file in ipairs(TOC_FILES) do
        assert(loadfile(file))("LibGoThere-1.0", {})
    end
end

---@param opts TestClientOptions?
function NewClient(opts)
    opts = opts or {}
    local client = { calls = {}, printed = {}, inCombat = false, time = 100 }
    -- Where the player stands: Elwynn Forest, in the middle.
    client.map, client.x, client.y = 1429, 0.5, 0.5

    ---Records a call to a provider: { name, args... }.
    local function record(name, ...)
        client.calls[#client.calls + 1] = { name, ... }
    end

    ---The recorded calls with this name, each as its argument list.
    function client:called(name)
        local found = {}
        for _, call in ipairs(self.calls) do
            if call[1] == name then found[#found + 1] = { unpack(call, 2) } end
        end
        return found
    end

    function GetTime()
        return client.time
    end
    function InCombatLockdown()
        return client.inCombat
    end
    MAP_PIN_HYPERLINK = "Map Pin Location"
    DEFAULT_CHAT_FRAME = {
        AddMessage = function(_, text)
            client.printed[#client.printed + 1] = text
        end,
    }

    -- The map: the player's position, map names, the game's own waypoint.
    local MAP_NAMES = { [1429] = "Elwynn Forest", [1436] = "Westfall", [1413] = "The Barrens" }
    client.userWaypoint = nil
    C_Map = {
        GetBestMapForUnit = function(unit)
            return unit == "player" and client.map or nil
        end,
        GetPlayerMapPosition = function(map, unit)
            if unit ~= "player" or map ~= client.map or not client.x then return nil end
            return {
                GetXY = function()
                    return client.x, client.y
                end,
            }
        end,
        GetMapInfo = function(map)
            return MAP_NAMES[map] and { mapID = map, name = MAP_NAMES[map] } or nil
        end,
        CanSetUserWaypointOnMap = function(map)
            return MAP_NAMES[map] ~= nil
        end,
        GetUserWaypoint = function()
            local point = client.userWaypoint
            -- The game hands out a new table each time.
            return point and { uiMapID = point.uiMapID, position = { x = point.position.x, y = point.position.y } }
        end,
        ClearUserWaypoint = function()
            record("ClearUserWaypoint")
            client.userWaypoint = nil
        end,
    }
    if not opts.noWaypoint then
        C_Map.SetUserWaypoint = function(point)
            record("SetUserWaypoint", point.uiMapID, point.position.x, point.position.y)
            client.userWaypoint = point
            return true
        end
    end
    C_SuperTrack = {
        SetSuperTrackedUserWaypoint = function(on)
            record("SetSuperTrackedUserWaypoint", on)
        end,
    }
    UiMapPoint = {
        CreateFromCoordinates = function(map, x, y)
            return { uiMapID = map, position = { x = x, y = y } }
        end,
    }

    -- Which addons are in the AddOns folder and which are loaded.
    local loaded, installed = {}, {}
    C_AddOns = {
        DoesAddOnExist = function(name)
            return installed[name] == true
        end,
        IsAddOnLoaded = function(name)
            return loaded[name] == true
        end,
    }
    for _, name in ipairs(opts.installed or {}) do
        installed[name] = true
    end
    local function present(name)
        installed[name], loaded[name] = true, true
    end

    ---@param overrides boolean|table?
    ---@param target table
    local function override(overrides, target)
        if type(overrides) ~= "table" then return end
        for key, value in pairs(overrides) do
            target[key] = value
        end
    end

    -- Shortest Path Forever: ShortestPathForever.API, version 1.1. client.estimates: seconds per
    -- "map:x:y" target, else no route.
    ShortestPathForever = nil
    client.estimates = {}
    if opts.spf then
        present("ShortestPathForever")
        local api = {
            version = 1,
            minor = 1,
            Navigate = function(owner, map, x, y, title)
                record("spf.Navigate", owner, map, x, y, title)
                return true
            end,
            Cancel = function(owner)
                record("spf.Cancel", owner)
                return true
            end,
            Estimate = function(fromMap, fromX, fromY, toMap, toX, toY)
                record("spf.Estimate", fromMap, fromX, fromY, toMap, toX, toY)
                local seconds = client.estimates[toMap .. ":" .. toX .. ":" .. toY]
                if seconds then return seconds end
                return nil, "unreachable"
            end,
        }
        override(opts.spf, api)
        ShortestPathForever = { API = api }
    end

    -- MoveFast: the global with Router (nodes filled after login), Map, Tracker and Recorder, as
    -- its own code has them. Coordinates in percent. client.routeTimes: seconds per "map:x:y"
    -- target in percent, else no route. client.moveFastPlans counts the routes planned.
    MoveFast = nil
    client.routeTimes, client.moveFastPlans = {}, 0
    if opts.moveFast then
        present("MoveFast")
        MoveFast = {
            Router = {
                nodes = {},
                -- Plans to the fastest-reached of dest.points, as Move Fast does.
                Route = function(_, start, dest, routeOpts)
                    client.moveFastPlans = client.moveFastPlans + 1
                    local p = dest.points[1]
                    record("mf.Route", start, p.map, p.x, p.y, p.label, routeOpts and routeOpts.noTips)
                    local best
                    for _, point in ipairs(dest.points) do
                        local total = client.routeTimes[point.map .. ":" .. point.x .. ":" .. point.y]
                        if total and (not best or total < best.total) then
                            best = { total = total, dest = { name = point.label } }
                        end
                    end
                    if not best then return nil, "no way there" end
                    return best
                end,
            },
            Map = {
                Point = function(_, map, x, y)
                    return { map = map, x = x, y = y }
                end,
            },
            Tracker = {
                Start = function(_, route)
                    record("mf.Start", route.dest.name)
                end,
                Stop = function()
                    record("mf.Stop")
                end,
            },
            Recorder = {
                ScanKnown = function()
                    record("mf.ScanKnown")
                end,
            },
        }
        override(opts.moveFast, MoveFast)
    end

    -- TomTom: AddWaypoint gives a uid table, RemoveWaypoint takes it back.
    TomTom = nil
    if opts.tomTom then
        present("TomTom")
        TomTom = {
            AddWaypoint = function(_, map, x, y, wpOpts)
                record("tt.AddWaypoint", map, x, y, wpOpts.title, wpOpts.from)
                return { map, x, y, title = wpOpts.title }
            end,
            RemoveWaypoint = function(_, uid)
                record("tt.RemoveWaypoint", uid.title)
            end,
        }
        override(opts.tomTom, TomTom)
    end

    -- Errors the library reports instead of raising (a provider that fails).
    client.errors = {}
    function geterrorhandler()
        return function(message)
            client.errors[#client.errors + 1] = message
        end
    end

    -- LibStub keeps its libraries in a global; a fresh client starts without one.
    LibStub = nil
    LoadToc()
    client.lib = LibStub("LibGoThere-1.0")

    ---Loads the library's files again, as a second addon embedding the same version would.
    function client:loadAgain()
        LoadToc()
        return LibStub("LibGoThere-1.0")
    end

    ---Whether a printed line contains text.
    function client:printedContains(text)
        for _, line in ipairs(self.printed) do
            if line:find(text, 1, true) then return true end
        end
        return false
    end

    return client
end
