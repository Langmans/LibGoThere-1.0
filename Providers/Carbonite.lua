-- Carbonite (every client): a target on its own map with its arrow. Nx:TTAddWaypoint(map, x, y,
-- { title }) gives the target's id, Nx:TTRemoveWaypoint(id) takes it back; the same calls its
-- TomTom stand-in makes when TomTom itself is missing. Coordinates 0 to 1.

local lib = LibStub("LibGoThere-1.0") --[[@as LibGoThere]]

local provider = { id = "carbonite", addon = "Carbonite", order = 27 } --[[@as LibGoThereProvider]]

function provider:Usable()
    return type(Nx) == "table" and type(Nx.TTAddWaypoint) == "function" and type(Nx.TTRemoveWaypoint) == "function"
end

---@param _ string the owner
---@param map number
---@param x number
---@param y number
---@param label string?
---@return number id
function provider:Navigate(_, map, x, y, label)
    return (Nx --[[@as CarboniteNx]]):TTAddWaypoint(map, x, y, { title = label })
end

---@param _ string the owner
---@param id number
---@return boolean
function provider:Cancel(_, id)
    (Nx --[[@as CarboniteNx]]):TTRemoveWaypoint(id)
    return true
end

lib:RegisterProvider(provider)
