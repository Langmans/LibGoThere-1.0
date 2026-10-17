-- LibGoThere-1.0: sends the player somewhere through the best route or waypoint addon they have,
-- best first: Shortest Path Forever, TomTom, the game's own waypoint, a map pin link in chat.
-- Coordinates are 0 to 1, as C_Map takes them.

local WESTFALL, BARRENS, UNKNOWN_MAP = 1436, 1413, 9999

describe("LibGoThere-1.0", function()
    describe("Navigate", function()
        it("hands the target to Shortest Path Forever first, with the owner and the label", function()
            local client = NewClient({ spf = true, tomTom = true })
            assert.are.equal("spf", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6, "Greater Fleshripper"))
            assert.are.same({ { "Kennel", WESTFALL, 0.4, 0.6, "Greater Fleshripper" } }, client:called("spf.Navigate"))
            assert.are.same({}, client:called("tt.AddWaypoint"))
        end)

        it("goes on to TomTom when SPF refuses or fails", function()
            local client = NewClient({
                spf = {
                    Navigate = function()
                        return false -- in combat, journeys off, ...
                    end,
                },
                tomTom = true,
            })
            assert.are.equal("tomtom", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6, "Here"))
            assert.are.same({ { WESTFALL, 0.4, 0.6, "Here", "Kennel" } }, client:called("tt.AddWaypoint"))
            client = NewClient({
                spf = {
                    Navigate = function()
                        error("SPF broke")
                    end,
                },
                tomTom = true,
            })
            assert.are.equal("tomtom", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6, "Here"))
            assert.are.equal(1, #client.errors, "the failure goes to the error handler")
        end)

        it("sets the game's own waypoint without a route addon, and tracks it", function()
            local client = NewClient()
            assert.are.equal("waypoint", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6, "Here"))
            assert.are.same({ { WESTFALL, 0.4, 0.6 } }, client:called("SetUserWaypoint"))
            assert.are.same({ { true } }, client:called("SetSuperTrackedUserWaypoint"))
        end)

        it("prints a map pin link where no waypoint can go", function()
            local client = NewClient()
            assert.are.equal("pinlink", client.lib:Navigate("Kennel", UNKNOWN_MAP, 0.4, 0.6, "Somewhere"))
            assert.is_true(client:printedContains("|Hworldmap:9999:4000:6000|h[Map Pin Location]|h"))
            assert.is_true(client:printedContains("Somewhere"))
            assert.are.equal("pinlink", NewClient({ noWaypoint = true }).lib:Navigate("Kennel", WESTFALL, 0.4, 0.6))
        end)

        it("refuses a target off the map or without an owner", function()
            local lib = NewClient({ spf = true }).lib
            assert.are.same({ nil, "invalid" }, { lib:Navigate("Kennel", WESTFALL, 1.5, 0.5) })
            assert.are.same({ nil, "invalid" }, { lib:Navigate("Kennel", nil, 0.5, 0.5) })
            assert.are.same({ nil, "invalid" }, { lib:Navigate("", WESTFALL, 0.5, 0.5) })
        end)
    end)

    describe("Cancel", function()
        it("takes back only the owner's own target, through the provider that has it", function()
            local client = NewClient({ spf = true })
            client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6)
            assert.is_false(client.lib:Cancel("Other"))
            assert.is_true(client.lib:Cancel("Kennel"))
            assert.are.same({ { "Kennel" } }, client:called("spf.Cancel"))
            assert.is_false(client.lib:Cancel("Kennel"), "nothing left")

            client = NewClient({ tomTom = true })
            client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6, "Here")
            assert.is_true(client.lib:Cancel("Kennel"))
            assert.are.same({ { "Here" } }, client:called("tt.RemoveWaypoint"))

            client = NewClient()
            client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6)
            assert.is_true(client.lib:Cancel("Kennel"))
            assert.are.equal(1, #client:called("ClearUserWaypoint"))
            client.lib:Navigate("Kennel", UNKNOWN_MAP, 0.4, 0.6)
            assert.is_false(client.lib:Cancel("Kennel"), "a link in chat cannot be taken back")
        end)

        it("leaves the game's waypoint alone once someone else moved it", function()
            local client = NewClient()
            client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6)
            client.userWaypoint = { uiMapID = BARRENS, position = { x = 0.1, y = 0.1 } }
            assert.is_false(client.lib:Cancel("Kennel"))
            client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6)
            client.userWaypoint = nil -- the player cleared it
            assert.is_false(client.lib:Cancel("Kennel"))
            assert.are.equal(0, #client:called("ClearUserWaypoint"))
        end)
    end)

    describe("TravelTime", function()
        it("asks Shortest Path Forever from where the player stands", function()
            local client = NewClient({ spf = true })
            client.estimates[WESTFALL .. ":0.4:0.6"] = 95
            assert.are.same({ 95, "spf" }, { client.lib:TravelTime(WESTFALL, 0.4, 0.6) })
            assert.are.same({ { 1429, 0.5, 0.5, WESTFALL, 0.4, 0.6 } }, client:called("spf.Estimate"))
            assert.is_nil(client.lib:TravelTime(BARRENS, 0.5, 0.5), "no route there")
        end)

        it("has none without SPF, or without the player's position", function()
            assert.is_nil(NewClient({ tomTom = true }).lib:TravelTime(WESTFALL, 0.4, 0.6))
            local client = NewClient({ spf = true })
            client.x = nil
            assert.is_nil(client.lib:TravelTime(WESTFALL, 0.4, 0.6))
        end)
    end)

    describe("NavigateNearest", function()
        local points = {
            { WESTFALL, 0.4, 0.6, "far" },
            { 1429, 0.6, 0.5, "close by" },
            { 1429, 0.9, 0.9, "across the forest" },
        }

        it("picks the point SPF reaches first", function()
            local client = NewClient({ spf = true })
            client.estimates[WESTFALL .. ":0.4:0.6"] = 60
            client.estimates["1429:0.6:0.5"] = 90
            assert.are.same({ "spf", 1 }, { client.lib:NavigateNearest("Kennel", points) })
            assert.are.same("far", client:called("spf.Navigate")[1][5])
        end)

        it("without travel times, the nearest point on the player's map, else the first", function()
            local client = NewClient({ tomTom = true })
            assert.are.same({ "tomtom", 2 }, { client.lib:NavigateNearest("Kennel", points) })
            client = NewClient()
            assert.are.same({ "waypoint", 1 }, { client.lib:NavigateNearest("Kennel", { points[1] }) })
            assert.are.same({ nil, "invalid" }, { client.lib:NavigateNearest("Kennel", {}) })
        end)
    end)

    it("lists the providers it knows: installed, loaded, usable, and which Navigate picks", function()
        local client = NewClient({ tomTom = true, installed = { "ShortestPathForever" } })
        assert.are.same({
            {
                id = "spf",
                addon = "ShortestPathForever",
                installed = true,
                loaded = false,
                usable = false,
                chosen = false,
            },
            { id = "tomtom", addon = "TomTom", installed = true, loaded = true, usable = true, chosen = true },
            { id = "waypoint", installed = true, loaded = true, usable = true, chosen = false },
            { id = "pinlink", installed = true, loaded = true, usable = true, chosen = false },
        }, client.lib:Providers())
    end)

    it("writes a map pin link as the game does", function()
        local lib = NewClient().lib
        assert.are.equal(
            "|cffffff00|Hworldmap:1436:4000:6050|h[Map Pin Location]|h|r",
            lib:PinLink(WESTFALL, 0.4, 0.605)
        )
    end)

    it("keeps one copy when a second addon embeds the same version", function()
        local client = NewClient({ spf = true })
        client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6)
        local again = client:loadAgain()
        assert.are.equal(client.lib, again)
        assert.is_true(again:Cancel("Kennel"), "what the first copy knew stays")
        assert.are.equal(4, #again:Providers(), "providers are not registered twice")
    end)

    it("takes a provider another addon registers, in its place by order", function()
        local client = NewClient({ tomTom = true })
        client.lib:RegisterProvider({
            id = "mine",
            order = 20,
            Usable = function()
                return true
            end,
            Navigate = function()
                return true
            end,
        })
        assert.are.same({ "spf", "mine", "tomtom" }, {
            client.lib:Providers()[1].id,
            client.lib:Providers()[2].id,
            client.lib:Providers()[3].id,
        })
        assert.are.equal("mine", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6))
    end)
end)
