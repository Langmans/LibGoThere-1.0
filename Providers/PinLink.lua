-- The last resort, always there: a map pin link in chat, with the owner and the label. Clicking it
-- sets the game's waypoint. A link in chat cannot be taken back, so there is no Cancel.

local lib = LibStub("LibGoThere-1.0") --[[@as LibGoThere]]

local provider = { id = "pinlink", order = 50 } --[[@as LibGoThereProvider]]

function provider:Usable()
    return true
end

---@param owner string
---@param map number
---@param x number
---@param y number
---@param label string?
---@return boolean
function provider:Navigate(owner, map, x, y, label)
    local link = lib:PinLink(map, x, y)
    DEFAULT_CHAT_FRAME:AddMessage(owner .. ": " .. (label and label .. " " or "") .. link)
    return true
end

lib:RegisterProvider(provider)
