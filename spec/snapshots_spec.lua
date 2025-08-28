-- ensure spec support is on package.path
package.path = package.path .. ";./spec/support/?.lua"

local html = require("bookdrop/html_templates")
local function read(path)
    local f = io.open(path, "rb")
    assert(f, "missing snapshot: " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

describe("HTML templates snapshots (.html)", function()
    it("header output matches snapshot", function()
        local got = html.header("Test")
        local want = read("spec/snapshots/header_Test.html")
        assert.are.equal(want, got)
    end)

    it("login page (not logged out) matches snapshot", function()
        local got = html.login_page(false)
        local want = read("spec/snapshots/login_false.html")
        assert.are.equal(want, got)
    end)

    it("login page (logged out) matches snapshot", function()
        local got = html.login_page(true)
        local want = read("spec/snapshots/login_true.html")
        assert.are.equal(want, got)
    end)

    it("shutdown page matches snapshot", function()
        local got = html.shutdown_page()
        local want = read("spec/snapshots/shutdown.html")
        assert.are.equal(want, got)
    end)

    it("clipping alert matches snapshot", function()
        local got = html.clipping_dir_not_set_alert()
        local want = read("spec/snapshots/clipping_alert.html")
        assert.are.equal(want, got)
    end)
end)
