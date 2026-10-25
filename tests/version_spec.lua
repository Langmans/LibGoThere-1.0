-- The library's version: a release tag must be its MINOR.

local version = require("tests.version")

describe("LibGoThere's version", function()
    local minor = version.minor("LibGoThere-1.0.lua")

    it("is a whole number in the library file", function()
        assert.is_number(minor)
    end)

    it("takes only a release tag that is its MINOR", function()
        assert.is_true((version.checkTag(tostring(minor), minor)))
        local ok, message = version.checkTag(tostring(minor + 1), minor)
        assert.is_false(ok)
        assert.truthy(message:find("raise MINOR first", 1, true))
    end)
end)
