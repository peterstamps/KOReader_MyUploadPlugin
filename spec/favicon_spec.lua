local favicon = require('bookdrop.favicon_svg')

describe('favicon_svg', function()
    it('returns an SVG string containing svg tags', function()
        assert.is_string(favicon)
        assert.is_true(favicon:find('<svg') ~= nil)
        assert.is_true(favicon:find('</svg>') ~= nil)
    end)

    it('contains expected elements (path or ellipse)', function()
        -- check for either path or ellipse in the SVG
        assert.is_true(favicon:find('<path') ~= nil or favicon:find('<ellipse') ~= nil)
    end)
end)
