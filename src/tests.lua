local M = {}

local log = require("log")

function M.timekeeping()
    local memtools = require("memtools")
    local conf = require("conf")
    local webapi = require("webapi")
    local tz = require("tz")
    local node = require("node")

    log("Timekeeping test")

    if not tz.setzone(conf.time.timezone) then
        log(string.format("Can'time_cal find %s timezone file. Halting.", conf.time.timezone))
        do
            return
        end
    end

    local time = tz.get_local_time()
    local second_of_day = tz.get_second_of_day(time)
    log(
        string.format(
            "Local time is %s (tz: %s) - Seconds since midnight: %d",
            tz.time_to_string(time),
            conf.time.timezone,
            second_of_day
        )
    )

    local _, bootreason = node.bootreason()
    local clock_calibration_status = memtools.rtcmem_get_clock_calibration_status()
    if (time < 100) or (bootreason == 0 or clock_calibration_status == nil) then
        clock_calibration_status = 0
    end

    if clock_calibration_status < conf.time.calibration_cycles then
        clock_calibration_status = clock_calibration_status + 1
        log(
            string.format(
                "Clock calibration cycle: %d out of %d",
                clock_calibration_status,
                conf.time.calibration_cycles
            )
        )
        memtools.rtcmem_set_clock_calibration_status(clock_calibration_status)
        webapi.server_sync(true)
        do
            return
        end
    end

    log(string.format("Test completed. Current time should be %s", tz.time_to_string()))
end

function M.bitshift()
    local tmr = require("tmr")
    local memtools = require("memtools")
    local ax, bx, cx, dx, v

    log("Testing bitshifting on integer up to 2^32 (it's going to take a while)...")

    for d = 0, 255 do
        for c = 0, 255 do
            log(string.format("c=%d d=%d", c, d))
            for b = 0, 255 do
                for a = 0, 255 do
                    v = memtools.int8_to_32(a, b, c, d)
                    ax, bx, cx, dx = memtools.int32_to_8(v)
                    if not (ax == a and bx == b and cx == c and dx == d) then
                        log(
                            string.format(
                                "Error at %d -> a:%d->%d b:%d->%d c:%d->%d e:%d->%d",
                                v,
                                a,
                                ax,
                                b,
                                bx,
                                c,
                                cx,
                                d,
                                dx
                            )
                        )
                    end
                end
                tmr.wdclr()
            end
        end
    end
end

function M.rtcmem()
    local memtools = require("memtools")
    local tmr = require("tmr")

    memtools.rtcmem_erase()

    log("Testing rtcmem_set_clock_calibration_status")
    memtools.rtcmem_set_clock_calibration_status(128)
    if not memtools.rtcmem_get_clock_calibration_status() == 128 then
        log("Error.")
    else
        log("Ok.")
    end

    log("Writing log slots")
    local y = 0
    local sum = 0
    for i = 0, 7 do -- 8 Slots, 3 hour each = 24h...
        local data32 = {}
        local checksum = 64
        for j = 1, 9 do -- ...each has 10 32-bit integers...
            y = 128
            data32[j] = memtools.int8_to_32(y, y + 1, y + 2, y + 3)
            sum = sum + y + (y + 1) + (y + 2) + (y + 3)
            checksum = checksum + y + (y + 1) + (y + 2) + (y + 3)
            --y = (y + 4) % 256
        end

        -- Last byte of slot contains the checksum
        checksum = checksum + y + (y + 1) + (y + 2)
        data32[10] = memtools.int8_to_32(y, y + 1, y + 2, checksum % 256)
        sum = sum + y + (y + 1) + (y + 2) + (checksum % 256)

        memtools.rtcmem_write_log_slot(i, data32)
    end

    log("Comparing log slots")
    local testsum = 0
    for i = 0, 7 do -- 8 Slots, 3 hour each = 24h...
        local data32 = memtools.rtcmem_read_log_slot(i)
        local slot_dump = string.format("[%03d]", i)
        for j = 1, 10 do -- ...each has 10 32-bit integers...
            local a, b, c, d = memtools.int32_to_8(data32[j])
            testsum = testsum + a + b + c + d
            slot_dump = string.format("%s %02x %02x %02x %02x", slot_dump, a, b, c, d)
        end
        log(slot_dump)
    end

    if not sum == testsum then
        log(string.format("Failed: %d != %d", sum, testsum))
    end

    tmr.wdclr()
    memtools = nil
    tmr = nil

    log("OK.")
end

function M.post()
    local memtools = require("memtools")
    local content = memtools.rtcmem_read_log_json()
    memtools._unload()

    local webapi = require("webapi")
    webapi.server_sync(
        content,
        function(result, _) -- second parameter is the OTA update content from server
            if result then
                log("POST ok.")
            else
                log("POST failed (so no OTA performed)")
            end
        end
    )
end

function M.tinypoll()
    local tmr = require("tmr")
    local memtools = require("memtools")
    local j = 0
    local c = 60

    log("Contiuously polling TINY...")

    local t = tmr.create()
    t:alarm(
        1000,
        tmr.ALARM_SEMI,
        function()
            if c == 60 then
                log(string.format("Iteration ", j))
                memtools.tiny2rtc(0)
                local content = memtools.rtcmem_read_log_json()
                local webapi = require("webapi")
                webapi.server_sync(
                    content,
                    function(result, ota_update)
                        if result then
                            log("Post succesful")
                        else
                            log("Post failed")
                        end
                        j = j + 1
                        c = 1
                        t:start()
                    end
                )
            else
                log("Time: " .. c)
                c = c + 1
                t:start()
            end
        end
    )
end

function M.log()
    for i = 0, 1000, 1 do
        log(
            string.format(
                "%d Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
                i
            )
        )
    end
end

-- Proves https://github.com/nodemcu/nodemcu-firmware/issues/1472 has not been solved yet
function M.wifiresume()
    local memtools = require("memtools")
    local sleep = require("sleep")
    local tmr = require("tmr")

    log("Tests Wi-Fi resume after rtctime.dsleep() and power consumption.")

    if memtools.rtcmem_get_clock_calibration_status() == 65 then
        memtools.rtcmem_set_clock_calibration_status(66)
        log("Idling 10 seconds: Wi-Fi is now supposed to be on (consumption ~70mA)")
        tmr.create():alarm(
            10000,
            tmr.ALARM_SINGLE,
            function()
                sleep.seconds(1, false)
            end
        )
    else
        if memtools.rtcmem_get_clock_calibration_status() == 66 then
            memtools.rtcmem_set_clock_calibration_status(65)
            log("Idling 10 seconds: Wi-Fi is now supposed to be off (consumption ~12mA)")
            tmr.create():alarm(
                10000,
                tmr.ALARM_SINGLE,
                function()
                    sleep.seconds(1, true)
                end
            )
        else
            memtools.rtcmem_set_clock_calibration_status(65)
            sleep.seconds(1, true)
        end
    end
end

function M._unload()
    package.loaded["tests"] = nil
end

return M
