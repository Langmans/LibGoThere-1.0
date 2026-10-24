-- Waypoint UI and Carbonite: each takes a target before TomTom, since each does more than an arrow
-- in a straight line (Waypoint UI plans the way on WoW: Forever and retail, Carbonite has its own
-- map and arrow on every client), and gives it back on Cancel.

local WESTFALL = 1436

describe("Providers", function()
    it("come in order: SPF, Move Fast, Waypoint UI, Carbonite, TomTom, the game's waypoint, a pin link", function()
        local client = NewClient({ spf = true, moveFast = true, waypointUI = true, carbonite = true, tomTom = true })
        local ids = {}
        for i, provider in ipairs(client.lib:Providers()) do
            ids[i] = provider.id
        end
        assert.are.same({ "spf", "movefast", "waypointui", "carbonite", "tomtom", "waypoint", "pinlink" }, ids)
    end)

    describe("Waypoint UI", function()
        it("tracks the target with its label before TomTom", function()
            local client = NewClient({ waypointUI = true, tomTom = true })
            assert.are.equal("waypointui", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6, "Here"))
            assert.are.same({ { WESTFALL, 0.4, 0.6, "Here" } }, client:called("wui.NewUserNavigation"))
            assert.are.same({}, client:called("tt.AddWaypoint"))
        end)

        it("clears the target again, but not one the player set since", function()
            local client = NewClient({ waypointUI = true })
            client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6, "Here")
            assert.is_true(client.lib:Cancel("Kennel"))
            assert.are.same({ { "Here" } }, client:called("wui.ClearUserNavigation"))
            client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6, "Here")
            client.waypointUI.NewUserNavigation({ mapID = WESTFALL, x = 0.1, y = 0.1, name = "Mine" })
            assert.is_false(client.lib:Cancel("Kennel"))
            assert.are.equal(1, #client:called("wui.ClearUserNavigation"), "the player's own stays")
        end)

        it("goes on to TomTom when it takes no target", function()
            local client = NewClient({
                waypointUI = {
                    NewUserNavigation = function() end,
                },
                tomTom = true,
            })
            assert.are.equal("tomtom", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6, "Here"))
        end)
    end)

    describe("Carbonite", function()
        it("sets its target with the label before TomTom, and takes it back", function()
            local client = NewClient({ carbonite = true, tomTom = true })
            assert.are.equal("carbonite", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6, "Here"))
            assert.are.same({ { WESTFALL, 0.4, 0.6, "Here" } }, client:called("nx.TTAddWaypoint"))
            assert.is_true(client.lib:Cancel("Kennel"))
            assert.are.same({ { 1 } }, client:called("nx.TTRemoveWaypoint"))
        end)
    end)
end)
