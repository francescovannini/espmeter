local module_name = "tz"

local M = {}
local tstart = 0
local tend = 0
local toffset = 0
local zone = "brussels.zone"
local rtctime = require("rtctime")
local file = require("file")

local function load(t)
  local struct = require("struct")
  local z = file.open(zone, "r")

  local hdr = z:read(20)
  local magic = struct.unpack("c4 B", hdr)

  if magic == "TZif" then
    local lens = z:read(24)
    local _, _, _, timecnt, typecnt, _ = struct.unpack("> LLLLLL", lens)

    local times = z:read(4 * timecnt)
    local typeindex = z:read(timecnt)
    local ttinfos = z:read(6 * typecnt)

    z:close()

    local offset = 1
    local tt
    for i = 1, timecnt do
      tt = struct.unpack(">l", times, (i - 1) * 4 + 1)
      if t < tt then
        offset = (i - 2)
        tend = tt
        break
      end
      tstart = tt
    end

    local tindex = struct.unpack("B", typeindex, offset + 1)
    toffset = struct.unpack(">l", ttinfos, tindex * 6 + 1)
  else
    tend = 0x7fffffff
    tstart = 0
  end
end

function M.setzone(z)
  zone = z
  return file.exists(zone)
end

function M.get_local_time()
  local sec, usec, rate = rtctime.get()

  if sec == 0 then
    return 0, 0, nil
  end

  if sec < tstart or sec >= tend then
    pcall(
      function()
        load(sec)
      end
    )
  end
  return toffset + sec, usec, rate
end

function M.get_second_of_day(time)
  if time == nil then
    time = M.get_local_time()
  end

  local t = rtctime.epoch2cal(time)
  return t["hour"] * 3600 + t["min"] * 60 + t["sec"]
end

function M.time_to_string(time)
  if time == nil then
    time = M.get_local_time()
  end
  local t = rtctime.epoch2cal(time)
  return string.format("%04d/%02d/%02d %02d:%02d:%02d", t["year"], t["mon"], t["day"], t["hour"], t["min"], t["sec"])
end

function M._unload()
  package.loaded["tz"] = nil
end

return M
