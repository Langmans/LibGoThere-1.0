-- The MoveFast provider: MoveFast has no documented API, so it calls what MoveFast's own code does
-- (Map:Point, Router:Route, Tracker:Start and Stop, Recorder:ScanKnown), each checked first, and
-- keeps a travel time for a minute while the player stays on the same map.

local WESTFALL = 1436

describe("the MoveFast provider", function()
    it("comes after Shortest Path Forever and before TomTom", function()
        local client = NewClient({ spf = true, moveFast = true, tomTom = true })
        local ids = {}
        for i, provider in ipairs(client.lib:Providers()) do
            ids[i] = provider.id
        end
        assert.are.same({ "spf", "movefast", "tomtom", "waypoint", "pinlink" }, ids)
        assert.are.equal("spf", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6))
    end)

    it("starts a route in percent, after reading the known flight paths, and stops it", function()
        local client = NewClient({ moveFast = true })
        client.routeTimes[WESTFALL .. ":40:60"] = 120
        assert.are.equal("movefast", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6, "Fleshripper"))
        assert.are.equal(1, #client:called("mf.ScanKnown"))
        assert.are.same({ { "Fleshripper" } }, client:called("mf.Start"))
        assert.is_true(client.lib:Cancel("Kennel"))
        assert.are.equal(1, #client:called("mf.Stop"))
    end)

    it("hands on to the next provider when MoveFast has no route", function()
        local client = NewClient({ moveFast = true, tomTom = true })
        assert.are.equal("tomtom", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6))
        assert.are.same({}, client:called("mf.Start"))
    end)

    it("gives travel times, kept a minute on the same map, until forgotten", function()
        local client = NewClient({ moveFast = true })
        client.routeTimes[WESTFALL .. ":40:60"] = 120
        assert.are.same({ 120, "movefast" }, { client.lib:TravelTime(WESTFALL, 0.4, 0.6) })
        assert.is_true(client:called("mf.Route")[1][6], "a plan without tips")
        client.lib:TravelTime(WESTFALL, 0.4, 0.6)
        client.time = client.time + 59
        client.lib:TravelTime(WESTFALL, 0.4, 0.6)
        assert.are.equal(1, client.moveFastPlans, "still fresh")
        client.time = client.time + 2
        client.lib:TravelTime(WESTFALL, 0.4, 0.6)
        assert.are.equal(2, client.moveFastPlans, "a minute old")
        client.map = 1436
        client.lib:TravelTime(WESTFALL, 0.4, 0.6)
        assert.are.equal(3, client.moveFastPlans, "another map")
        client.lib:ForgetTravelTimes()
        client.lib:TravelTime(WESTFALL, 0.4, 0.6)
        assert.are.equal(4, client.moveFastPlans, "forgotten")
        assert.is_nil(client.lib:TravelTime(WESTFALL, 0.9, 0.9), "no route")
        client.lib:TravelTime(WESTFALL, 0.9, 0.9)
        assert.are.equal(5, client.moveFastPlans, "no route is kept too")
    end)

    it("is only used when every part it calls is there", function()
        for _, missing in ipairs({ "Router", "Map", "Tracker" }) do
            local client = NewClient({ moveFast = { [missing] = false } })
            assert.is_false(client.lib:Providers()[1].usable, missing)
        end
        local client = NewClient({ moveFast = { Router = { Route = function() end } } })
        assert.is_false(client.lib:Providers()[1].usable, "a router without nodes: before login")
        client = NewClient({ moveFast = { Recorder = false } })
        client.routeTimes[WESTFALL .. ":40:60"] = 120
        assert.are.equal("movefast", client.lib:Navigate("Kennel", WESTFALL, 0.4, 0.6), "the recorder is optional")
    end)
end)
