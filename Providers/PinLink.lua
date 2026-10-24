-- The last resort, always there: a map pin link in chat, with the owner and the label. Clicking it
-- sets the game's waypoint. A client without the waypoint API (Classic Era) cannot open such a
-- link, so there it writes the zone and coordinates as text. A line in chat cannot be taken back,
-- so there is no Cancel.

local lib = LibStub("LibGoThere-1.0") --[[@as LibGoThere]]

local provider = { id = "pinlink", order = 50 } --[[@as LibGoThereProvider]]

function provider:Usable()
    return true
end

---"Westfall 40.0, 60.5": the map's name, when the client has one, and the coordinates in percent.
---@param map number
---@param x number
---@param y number
---@return string
local function Place(map, x, y)
    local info = C_Map.GetMapInfo(map)
    local coords = ("%.1f, %.1f"):format(x * 100, y * 100)
    return info and info.name and info.name .. " " .. coords or coords
end

---@param owner string
---@param map number
---@param x number
---@param y number
---@param label string?
---@return boolean
function provider:Navigate(owner, map, x, y, label)
    if type(C_Map.SetUserWaypoint) == "function" then
        DEFAULT_CHAT_FRAME:AddMessage(owner .. ": " .. (label and label .. " " or "") .. lib:PinLink(map, x, y))
    else
        DEFAULT_CHAT_FRAME:AddMessage(owner .. ": " .. (label and label .. ", " or "") .. Place(map, x, y))
    end
    return true
end

lib:RegisterProvider(provider)
