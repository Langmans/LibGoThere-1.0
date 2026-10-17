-- LibGoThere-1.0: sends the player somewhere through the route or waypoint addon they have. The
-- caller names itself (owner), a map (uiMapID) and a spot on it (x and y from 0 to 1, as C_Map
-- takes them); the library hands that to the best provider present, best first: Shortest Path
-- Forever (a route, and travel times), TomTom (an arrow, which many other addons follow too), the
-- game's own waypoint (which the rest follow), and a map pin link in chat. Each provider lives in
-- Providers\ and registers itself; every call into another addon is made in pcall, so a provider
-- that changes or breaks only falls back to the next.
--
--   local GoThere = LibStub("LibGoThere-1.0")
--   GoThere:Navigate("MyAddon", 1436, 0.42, 0.61, "Greater Fleshripper")

-- MINOR goes up by one with every release, and the release tag is the same number (README).
local MAJOR, MINOR = "LibGoThere-1.0", 1

---@type LibGoThere?
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- Kept when a newer copy loads over an older one: the providers, best first, and per owner the
-- target it has out (which provider took it, and that provider's handle for it).
lib.providers = lib.providers or {}
lib.owned = lib.owned or {}

---Adds a provider, or replaces the one with its id, keeping them in their order.
---@param provider LibGoThereProvider
function lib:RegisterProvider(provider)
    local providers = self.providers
    for i, known in ipairs(providers) do
        if known.id == provider.id then
            providers[i] = provider
            return
        end
    end
    local at = #providers + 1
    for i, known in ipairs(providers) do
        if provider.order < known.order then
            at = i
            break
        end
    end
    table.insert(providers, at, provider)
end

---Calls a provider's method in pcall: its first result, or, when it errors, nil, the error going to
---the error handler.
---@param provider LibGoThereProvider
---@param method "Usable"|"Navigate"|"Cancel"|"TravelTime"|"Forget"
---@param ... string|LibGoThereResult
---@return LibGoThereResult
local function Try(provider, method, ...)
    local ok, result = pcall(provider[method], provider, ...)
    if ok then
        return result --[[@as LibGoThereResult]]
    end
    geterrorhandler()(result)
    return nil
end

---A spot the library takes: a map ID and x and y from 0 to 1.
---@param map number?
---@param x number?
---@param y number?
---@return boolean
local function Valid(map, x, y)
    return type(map) == "number"
        and map > 0
        and type(x) == "number"
        and type(y) == "number"
        and x >= 0
        and x <= 1
        and y >= 0
        and y <= 1
end

---Sends the player to a spot through the best provider that takes it. Returns the provider's id,
---or nil and "invalid" for a bad owner or spot.
---@param owner string the calling addon's name; Cancel takes back only its own target
---@param map number uiMapID
---@param x number 0 to 1
---@param y number 0 to 1
---@param label string? what is there, for the provider's arrow or tooltip
---@return string? providerID
---@return string? reason
function lib:Navigate(owner, map, x, y, label)
    if type(owner) ~= "string" or not owner:find("%S") or not Valid(map, x, y) then return nil, "invalid" end
    for _, provider in ipairs(self.providers) do
        local handle = Try(provider, "Usable") and Try(provider, "Navigate", owner, map, x, y, label)
        if handle then
            self.owned[owner] = { provider = provider, handle = handle }
            return provider.id
        end
    end
end

---Takes back the owner's target, through the provider that has it. Returns whether it did: false
---for an owner with none, a map pin link, or a target the player or another addon has replaced.
---@param owner string
---@return boolean
function lib:Cancel(owner)
    local own = self.owned[owner]
    if not own then return false end
    self.owned[owner] = nil
    return own.provider.Cancel ~= nil and Try(own.provider, "Cancel", owner, own.handle) == true
end

---Where the player stands: the map and the spot on it, or nil when the client does not say.
---@return number? map
---@return number x
---@return number y
local function Here()
    local map = C_Map.GetBestMapForUnit("player")
    local position = map and C_Map.GetPlayerMapPosition(map, "player")
    if not position then return nil, 0, 0 end
    local x, y = position:GetXY()
    return map, x, y
end

---Seconds to travel from where the player stands to a spot, and the provider that worked it out;
---nil when no provider has travel times, no route is known, or the player's position is not.
---@param map number
---@param x number
---@param y number
---@return number? seconds
---@return string? providerID
function lib:TravelTime(map, x, y)
    local here, fromX, fromY = Here()
    if not here or not Valid(map, x, y) then return nil end
    for _, provider in ipairs(self.providers) do
        if provider.TravelTime and Try(provider, "Usable") then
            local seconds = Try(provider, "TravelTime", here, fromX, fromY, map, x, y)
            if type(seconds) == "number" then return seconds, provider.id end
        end
    end
    return nil
end

---Drops the travel times providers keep, after something that changes them (a flight path
---learned, say).
function lib:ForgetTravelTimes()
    for _, provider in ipairs(self.providers) do
        if provider.Forget then Try(provider, "Forget") end
    end
end

---One provider's answer to "which of these spots is reached first": its own Nearest when it can
---weigh them all at once, else its TravelTime per spot. Seconds and the spot's index, or nil.
---@param provider LibGoThereProvider
---@param here number
---@param fromX number
---@param fromY number
---@param points LibGoTherePoint[]
---@return number? seconds
---@return integer? index
local function ProviderNearest(provider, here, fromX, fromY, points)
    if provider.Nearest then
        local ok, seconds, index = pcall(provider.Nearest, provider, here, fromX, fromY, points)
        if not ok then
            geterrorhandler()(seconds)
            return nil
        end
        if type(seconds) == "number" and type(index) == "number" then return seconds, index end
        return nil
    end
    ---@type number?, integer?
    local best, bestIndex
    for i, point in ipairs(points) do
        local seconds = Try(provider, "TravelTime", here, fromX, fromY, point[1], point[2], point[3])
        if type(seconds) == "number" and (not best or seconds < best) then
            best, bestIndex = seconds, i
        end
    end
    return best, bestIndex
end

---Seconds to the spot of several ({ uiMapID, x, y } each) that the player reaches first, its
---index and the provider that worked it out; nil when no provider has travel times, there is no
---route to any, or the player's position is not known.
---@param points LibGoTherePoint[]
---@return number? seconds
---@return integer? index
---@return string? providerID
function lib:TravelTimeNearest(points)
    local here, fromX, fromY = Here()
    if type(points) ~= "table" or #points == 0 or not here then return nil end
    for _, provider in ipairs(self.providers) do
        if (provider.Nearest or provider.TravelTime) and Try(provider, "Usable") then
            local seconds, index = ProviderNearest(provider, here, fromX, fromY, points)
            if seconds then return seconds, index, provider.id end
        end
    end
    return nil
end

---Which of several spots to go to: the one reached first; without travel times, the nearest on
---the player's own map; else the first.
---@param points LibGoTherePoint[]
---@return integer
local function Nearest(points)
    local _, index = lib:TravelTimeNearest(points)
    if index then return index end
    local here, fromX, fromY = Here()
    if not here then return 1 end
    local bestDistance
    local best = 1
    for i, point in ipairs(points) do
        if point[1] == here then
            local distance = (point[2] - fromX) ^ 2 + (point[3] - fromY) ^ 2
            if not bestDistance or distance < bestDistance then
                best, bestDistance = i, distance
            end
        end
    end
    return best
end

---Sends the player to the nearest of several spots ({ uiMapID, x, y, label } each). Returns the
---provider's id and the spot's index, or nil and a reason.
---@param owner string
---@param points LibGoTherePoint[]
---@return string? providerID
---@return integer|string|nil indexOrReason
function lib:NavigateNearest(owner, points)
    if type(points) ~= "table" or #points == 0 then return nil, "invalid" end
    local index = Nearest(points)
    local point = points[index]
    local id, reason = self:Navigate(owner, point[1], point[2], point[3], point[4])
    if not id then return nil, reason end
    return id, index
end

---Every provider the library knows, best first: its id, its addon (none for the game's own),
---whether that addon is in the AddOns folder and loaded, whether it can take a target now, and
---which one Navigate would use. For an options page, or to tell the player what to install.
---@return LibGoThereProviderInfo[]
function lib:Providers()
    ---@type LibGoThereProviderInfo[]
    local list = {}
    local chosen = false
    for i, provider in ipairs(self.providers) do
        local addon = provider.addon
        local usable = Try(provider, "Usable") == true
        list[i] = {
            id = provider.id,
            addon = addon,
            installed = not addon or C_AddOns.DoesAddOnExist(addon) == true,
            loaded = not addon or C_AddOns.IsAddOnLoaded(addon) == true,
            usable = usable,
            chosen = usable and not chosen,
        }
        chosen = chosen or usable
    end
    return list
end

---A chat link to a spot, as the game's own map pins write it: worldmap:<uiMapID>:<x>:<y>, x and
---y in hundredths of a percent. Clicking it sets the game's waypoint.
---@param map number
---@param x number 0 to 1
---@param y number 0 to 1
---@return string
function lib:PinLink(map, x, y)
    return ("|cffffff00|Hworldmap:%d:%d:%d|h[%s]|h|r"):format(
        map,
        math.floor(x * 10000 + 0.5),
        math.floor(y * 10000 + 0.5),
        MAP_PIN_HYPERLINK or "Map Pin"
    )
end
