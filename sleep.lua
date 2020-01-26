local conf = require("conf")
local rtctime = require("rtctime")
local tmr = require("tmr")

local M = {}

function M.until_next_poll()
  local wifi_opt = 4 -- OFF by default
  local tz = require("tz")
  tz.setzone(conf.tz)
  local t = rtctime.epoch2cal(tz.get_local_time())

  local second_of_day = t["hour"] * 3600 + t["min"] * 60 + t["sec"]

  local sleep_secs = nil
  for k, v in pairs(conf.time.poll_avr_at) do
    if second_of_day < v then
      sleep_secs = v - second_of_day - 1
      break
    end
  end

  -- Last sleep before transmission
  if sleep_secs == nil then
    if second_of_day > conf.time.transmit_at then -- TODO remove this when verified doen't happen
      print(
        string.format(
          "Error: second_of_day=%d when transmit_at=%d. This should never happen!",
          second_of_day,
          conf.time.transmit_at
        )
      )
      do
        return
      end
    end

    sleep_secs = conf.time.transmit_at - second_of_day - 1
  end

  if wifi_opt == nil then
    print(string.format("Deep sleep %d seconds. Wi-Fi on resume: ON", sleep_secs))
  else
    print(string.format("Deep sleep %d seconds. Wi-Fi on resume: OFF", sleep_secs))
  end

  local tm = tmr.create()
  tm:alarm(
    1000,
    tmr.ALARM_SINGLE,
    function()
      rtctime.dsleep(1000000 * sleep_secs, wifi_opt)
    end
  )
end

return M
