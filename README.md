# LibGoThere-1.0

[![CI](https://github.com/Langmans/LibGoThere-1.0/actions/workflows/ci.yml/badge.svg)](https://github.com/Langmans/LibGoThere-1.0/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/Langmans/LibGoThere-1.0?include_prereleases)](https://github.com/Langmans/LibGoThere-1.0/releases)
![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)
![WoW: Forever](https://img.shields.io/badge/WoW-Forever%20%2816001%29-c79c6e)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow)](https://github.com/Langmans/LibGoThere-1.0/blob/main/LICENSE)

A library that sends the player somewhere through whichever route or waypoint
addon they have. The calling addon names itself, a map and a spot on it; the
library hands that to the best provider present:

| Provider | Needs | What the player gets |
|---|---|---|
| `spf` | [Shortest Path Forever](https://www.curseforge.com/wow/addons/shortest-path-forever) | a route by foot, flight path, boat and hearthstone; travel times |
| `movefast` | [Move Fast](https://www.curseforge.com/wow/addons/move-fast-travel-guide-item-finder) | a route with steps and an arrow; travel times, the nearest of many spots in one plan (kept a minute on the same map) |
| `tomtom` | [TomTom](https://www.curseforge.com/wow/addons/tomtom) | a waypoint with TomTom's arrow, which many other addons follow too |
| `waypoint` | the game (Forever, Retail) | the game's own map pin, tracked; AzerothGPS, Waypoint UI, Northstar and most arrows follow it |
| `pinlink` | nothing | a map pin link in chat; clicking it sets the game's waypoint |

Every call into another addon goes through `pcall`, so a provider that changes
or breaks only falls back to the next; its error goes to the error handler.

## Use

Coordinates are 0 to 1, as `C_Map` takes them.

```lua
local GoThere = LibStub("LibGoThere-1.0")

-- To one spot. Returns the provider's id ("spf", "tomtom", ...), or nil and "invalid".
GoThere:Navigate("MyAddon", 1436, 0.42, 0.61, "Greater Fleshripper")

-- To the nearest of several: by travel time where a provider has it, else the nearest on
-- the player's own map, else the first. Returns the provider's id and the spot's index.
GoThere:NavigateNearest("MyAddon", {
    { 1436, 0.42, 0.61, "Westfall" },
    { 1429, 0.33, 0.70, "Elwynn Forest" },
})

-- Takes back MyAddon's own target (not another addon's, not one the player replaced).
GoThere:Cancel("MyAddon")

-- Seconds from where the player stands, and which provider worked it out; nil without one.
local seconds, by = GoThere:TravelTime(1436, 0.42, 0.61)

-- Seconds to whichever of several spots the player reaches first, its index, and the provider.
local seconds, index, by = GoThere:TravelTimeNearest({ { 1436, 0.42, 0.61 }, { 1429, 0.33, 0.70 } })

-- After something that changes travel times (a flight path learned): drop the ones kept.
GoThere:ForgetTravelTimes()

-- What the player has, for an options page or to say what to install:
-- { id, addon, installed, loaded, usable, chosen } per provider, best first.
for _, p in ipairs(GoThere:Providers()) do print(p.id, p.usable, p.chosen) end

-- A map pin link as the game writes it.
print(GoThere:PinLink(1436, 0.42, 0.61))
```

The owner (your addon's name) goes to the provider where it takes one (SPF's
owner, TomTom's `from`), and lets `Cancel` touch only your own target.

### Your own provider

Another addon can add a provider: a table with an `id`, an `order` (lower is
tried first; the built-in ones use 10, 20, 30, 40 and 50), and `Usable` and
`Navigate` methods; `Cancel`, `TravelTime`, `Nearest` (weigh several spots at
once: seconds and the index of the one reached first, for a router that plans
to the nearest of many in one go, as Move Fast does) and `Forget` (drop kept
travel times) are optional. `Navigate` returns
a handle (anything but nil or false) that `Cancel` gets back.

```lua
GoThere:RegisterProvider({
    id = "myrouter", addon = "MyRouter", order = 20,
    Usable = function(self) return MyRouter ~= nil end,
    Navigate = function(self, owner, map, x, y, label) return MyRouter.Go(map, x, y, label) end,
    Cancel = function(self, owner, handle) return MyRouter.Stop(handle) end,
    TravelTime = function(self, fromMap, fromX, fromY, map, x, y) return MyRouter.Seconds(fromMap, fromX, fromY, map, x, y) end,
})
```

## Embedding

List it as an external in your `.pkgmeta`, pinned to a tag or commit:

```yaml
externals:
  Libs/LibGoThere-1.0:
    url: https://github.com/Langmans/LibGoThere-1.0.git
    tag: "1"
```

and include `Libs\LibGoThere-1.0\lib.xml` after LibStub (in `embeds.xml` or the
`.toc`). Several addons may embed it; LibStub keeps the newest copy, and a
newer copy keeps what an older one knew. The `.toc` also lets it load on its
own, from the AddOns folder.

## Versions

The major version is in the name: `LibGoThere-1.0` keeps its API; a change
that breaks it becomes `LibGoThere-2.0`, a library of its own. Within it, the
minor version (`MINOR` in `LibGoThere-1.0.lua`) is a whole number that goes up
by one with every release, and the release tag is that same number (`1`, `2`,
...). When several addons embed the library, LibStub keeps the copy with the
highest minor.

## Development

The same setup as [Kennel](https://github.com/Langmans/Kennel): busted and
luacov on Lua 5.1, StyLua, WoW Lua LS, all through `tests/check.lua`
(`tests\setup-lua.ps1` builds the tools on Windows). Line and type coverage are
held at 100%. `tests/wow.lua` simulates the client and each provider addon,
recording every call a provider receives.

## License

MIT, see [LICENSE](https://github.com/Langmans/LibGoThere-1.0/blob/main/LICENSE).
Shortest Path Forever (GPL-3), Move Fast and TomTom are only called, never
copied. Move Fast documents no API; the provider calls what Move Fast's own
code does, each part checked first.
