local M = {}

-- with_io_open_mock(mapping, fn)
-- mapping: table where key = filename, value = function(mode) -> file-like table or nil
-- fn: function to run while io.open is mocked
function M.with_io_open_mock(mapping, fn)
    local orig_io_open = io.open
    io.open = function(fname, mode)
        local handler = mapping[fname]
        if handler then
            return handler(mode)
        end
        return orig_io_open(fname, mode)
    end
    local ok, err = pcall(fn)
    io.open = orig_io_open
    if not ok then error(err) end
end

return M
