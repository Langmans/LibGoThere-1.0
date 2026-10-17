---@meta
-- Editor-only types for the library and for the parts of the provider addons it calls, as their
-- own code defines them. Not listed in the .toc, not in releases.

---@class LibGoThere
---@field providers LibGoThereProvider[] best first
---@field owned table<string, {provider: LibGoThereProvider, handle: LibGoThereResult}> per owner, the target it has out
---@field RegisterProvider fun(self: LibGoThere, provider: LibGoThereProvider)
---@field Navigate fun(self: LibGoThere, owner: string, map: number, x: number, y: number, label: string?): string?, string?
---@field NavigateNearest fun(self: LibGoThere, owner: string, points: LibGoTherePoint[]): string?, integer|string|nil
---@field Cancel fun(self: LibGoThere, owner: string): boolean
---@field TravelTime fun(self: LibGoThere, map: number, x: number, y: number): number?, string?
---@field Providers fun(self: LibGoThere): LibGoThereProviderInfo[]
---@field PinLink fun(self: LibGoThere, map: number, x: number, y: number): string

---A spot for NavigateNearest: { uiMapID, x, y, label }, x and y 0 to 1.
---@class LibGoTherePoint
---@field [1] number
---@field [2] number
---@field [3] number
---@field [4] string?

---@class LibGoThereProviderInfo
---@field id string
---@field addon string? none for the game's own
---@field installed boolean
---@field loaded boolean
---@field usable boolean
---@field chosen boolean the one Navigate would use

---What a provider's method gives back: Usable a boolean, Navigate a handle for Cancel (or nil or
---false when it did not take the target), Cancel a boolean, TravelTime seconds.
---@alias LibGoThereResult boolean|number|table|nil

---A provider (Providers\): what the library calls, each in pcall.
---@class LibGoThereProvider
---@field id string
---@field addon string? the addon it needs
---@field order number lower is tried first
---@field Usable fun(self: LibGoThereProvider): boolean
---@field Navigate fun(self: LibGoThereProvider, owner: string, map: number, x: number, y: number, label: string?): LibGoThereResult
---@field Cancel (fun(self: LibGoThereProvider, owner: string, handle: LibGoThereResult): boolean)?
---@field TravelTime (fun(self: LibGoThereProvider, fromMap: number, fromX: number, fromY: number, map: number, x: number, y: number): number?)?

---Shortest Path Forever's API (Core\API.lua there).
---@class SPFPublicAPI
---@field version number
---@field minor number
---@field Navigate fun(owner: string, map: number, x: number, y: number, title: string?, kind: string?): boolean
---@field Cancel fun(owner: string): boolean
---@field Estimate fun(fromMap: number, fromX: number, fromY: number, toMap: number, toX: number, toY: number): number?, string?

---@class SPFGlobal
---@field API SPFPublicAPI?

---Shortest Path Forever's global; nil when it is not loaded.
---@type SPFGlobal?
ShortestPathForever = nil

---@class TomTomAddon
---@field AddWaypoint fun(self: TomTomAddon, map: number, x: number, y: number, opts: {title: string?, from: string?}): table
---@field RemoveWaypoint fun(self: TomTomAddon, uid: table)

---TomTom's addon object; nil when it is not loaded.
---@type TomTomAddon?
TomTom = nil
