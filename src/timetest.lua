local M = {}

local rtctime = require("rtctime")
local conf = require("conf")
local net = require("net")
local tmr = require("tmr")
local wifi = require("wifi")
local sntp = require("sntp")

function M.main()
    if conf.net.dns_primary_server then
        net.dns.setdnsserver(conf.net.dns_primary_server, 0)
    end

    if conf.net.dns_secondary_server then
        net.dns.setdnsserver(conf.net.dns_secondary_server, 1)
    end

    local wifi_timeout_timer = tmr.create()
    wifi_timeout_timer:alarm(
        10000,
        tmr.ALARM_SINGLE,
        function()
            print("Wi-Fi connection can't be established. Giving up.")
            do
                return
            end
        end
    )

    wifi.setmode(wifi.STATION)
    wifi.sta.config(conf.wifi)
    wifi.sta.setip(conf.net)
    wifi.sta.connect(
        function()
            print("Wi-Fi connected.")
            local localsec, _, _ = rtctime.get()
            local rtc_local = rtctime.epoch2cal(localsec)
            print(
                string.format(
                    "Time from rtc clock before SNTP: %02d:%02d:%02d",
                    rtc_local["hour"],
                    rtc_local["min"],
                    rtc_local["sec"]
                )
            )
            wifi_timeout_timer:stop()
            if conf.net.ntp.enabled then
                print("Attempting SNTP time sync.")
                sntp.sync(
                    conf.net.ntp.server,
                    function(ssec, _, server, _)

                        local server_tm = rtctime.epoch2cal(ssec)
                        print(
                            string.format(
                                "Time from SNTP server %s: %02d:%02d:%02d",
                                server,
                                server_tm["hour"],
                                server_tm["min"],
                                server_tm["sec"]
                            )
                        )

                        local newsec, _, _ = rtctime.get()
                        local rtc_new = rtctime.epoch2cal(newsec)
                        print(
                            string.format(
                                "Time from RTC clock after SNTP: %02d:%02d:%02d",
                                rtc_new["hour"],
                                rtc_new["min"],
                                rtc_new["sec"]
                            )
                        )

                        print(string.format("RTC ran %d seconds ahead", localsec - ssec))

                        local sleep_time = 10
                        print(string.format("Sleep %d minutes", sleep_time))

                        local tms = tmr.create()
                        tms:alarm(
                            1000,
                            tmr.ALARM_SINGLE,
                            function()
                                rtctime.dsleep(1000000 * 60 * sleep_time, 0)
                            end
                        )
                        do
                            return
                        end
                    end,
                    function(reason, _)
                        print("SNTP sync failed: " .. tostring(reason) .. ". Giving up.")
                        do
                            return
                        end
                    end
                )
            end
        end
    )
end

return M
