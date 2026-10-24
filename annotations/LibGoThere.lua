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
---@field ForgetTravelTimes fun(self: LibGoThere)
---@field TravelTimeNearest fun(self: LibGoThere, points: LibGoTherePoint[]): number?, integer?, string?
---@field HasTravelTimes fun(self: LibGoThere): boolean
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
---@field Forget (fun(self: LibGoThereProvider))? drops the travel times it keeps
---@field Nearest (fun(self: LibGoThereProvider, fromMap: number, fromX: number, fromY: number, points: LibGoTherePoint[]): number?, integer?)? weighs several spots at once: seconds and the index of the one reached first

---MoveFast's parts the provider calls (its own Map.lua, Router.lua, Tracker.lua, Recorder.lua).
---@class MoveFastAddon
---@field Map {Point: fun(self: table, map: number, x: number, y: number): table}
---@field Router {nodes: table, Route: fun(self: table, start: table?, dest: table, opts: table?): MoveFastRoute?, string?}
---@field Tracker {Start: fun(self: table, route: MoveFastRoute), Stop: fun(self: table)}
---@field Recorder {ScanKnown: fun(self: table)}?

---@class MoveFastRoute
---@field total number seconds
---@field dest {name: string?}? the point it chose, by its label

---MoveFast's global; nil when it is not loaded.
---@type MoveFastAddon?
MoveFast = nil

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

---A navigation Waypoint UI tracks.
---@class WaypointUINavigation
---@field mapID number
---@field x number
---@field y number
---@field name string?

---@class WaypointUINavigationAPI
---@field NewUserNavigation fun(options: {name: string?, mapID: number, x: number, y: number}): WaypointUINavigation?
---@field GetUserNavigation fun(): WaypointUINavigation?
---@field ClearUserNavigation fun(preserveWaypoint: boolean?, suppressAdvance: boolean?)

---Waypoint UI's public API; nil when it is not loaded.
---@type {Navigation: WaypointUINavigationAPI}?
WaypointUIAPI = nil

---@class CarboniteNx
---@field TTAddWaypoint fun(self: CarboniteNx, map: number, x: number, y: number, opts: {title: string?}): number
---@field TTRemoveWaypoint fun(self: CarboniteNx, id: number)

---Carbonite's addon object; nil when it is not loaded.
---@type CarboniteNx?
Nx = nil
