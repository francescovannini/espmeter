return function(s)
    local file = require("file")
    local conf = require("conf")

    if not conf.log then
        return
    end

    if not conf.log.enabled then
        return
    end

    -- find lowest id that doesn't correspond to a full file
    local min
    for i = 0, conf.log.maxfiles - 1, 1 do
        local nm = string.format("log.%d.f", i)
        if min == nil and not file.exists(nm) then
            min = i
        end
    end

    if min == nil then
        min = 0
    end

    local filename = string.format("log.%d", min)

    local f = file.open(filename, "a+")
    local tz = require("tz")
    local buf = string.format("[%s] %s", tz.time_to_string(), s)
    f:write(buf .. "\n")
    f:close()
    print(buf)
    tz._unload()

    local stats = file.stat(filename)
    if stats.size > conf.log.maxsize then
        if file.exists(filename .. ".f") then
            file.remove(filename .. ".f")
        end
        file.rename(filename, filename .. ".f")
        local next = string.format("log.%d", (min + 1) % conf.log.maxfiles)
        if file.exists(next) then
            file.remove(next)
        end
        if file.exists(next .. ".f") then
            file.remove(next .. ".f")
        end
    end
end
