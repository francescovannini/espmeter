local M = {}

function M.timekeeping()
    local memtools = require("memtools")
    local conf = require("conf")
    local webapi = require("webapi")
    local tz = require("tz")
    local node = require("node")

    print("Timekeeping test")

    if not tz.setzone(conf.time.timezone) then
        print(string.format("Can'time_cal find %s timezone file. Halting.", conf.time.timezone))
        do
            return
        end
    end

    local time = tz.get_local_time()
    local second_of_day = tz.get_second_of_day(time)
    print(
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
        print(
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

    print(string.format("Test completed. Current time should be %s", tz.time_to_string()))
end

function M.bitshift()
    local tmr = require("tmr")
    local memtools = require("memtools")
    local ax, bx, cx, dx, v

    print("Testing bitshifting on integer up to 2^32 (it's going to take a while)...")

    for d = 0, 255 do
        for c = 0, 255 do
            print(string.format("c=%d d=%d", c, d))
            for b = 0, 255 do
                for a = 0, 255 do
                    v = memtools.int8_to_32(a, b, c, d)
                    ax, bx, cx, dx = memtools.int32_to_8(v)
                    if not (ax == a and bx == b and cx == c and dx == d) then
                        print(
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

    print("Testing rtcmem_set_clock_calibration_status")
    memtools.rtcmem_set_clock_calibration_status(128)
    if not memtools.rtcmem_get_clock_calibration_status() == 128 then
        print("Error.")
    else
        print("Ok.")
    end

    print("Writing log slots")
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

    print("Comparing log slots")
    local testsum = 0
    for i = 0, 7 do -- 8 Slots, 3 hour each = 24h...
        local data32 = memtools.rtcmem_read_log_slot(i)
        local slot_dump = string.format("[%03d]", i)
        for j = 1, 10 do -- ...each has 10 32-bit integers...
            local a, b, c, d = memtools.int32_to_8(data32[j])
            testsum = testsum + a + b + c + d
            slot_dump = string.format("%s %02x %02x %02x %02x", slot_dump, a, b, c, d)
        end
        print(slot_dump)
    end

    if not sum == testsum then
        print(string.format("Failed: %d != %d", sum, testsum))
    end

    tmr.wdclr()

    print("OK.")
end

function M.post()
    local memtools = require("memtools")
    local content = memtools.rtcmem_read_log_json()
    memtools = nil

    local webapi = require("webapi")
    webapi.server_sync(
        content,
        function(result, ota_update)
            if result then
                print("Post succesful")
            else
                print("Post failed")
            end
        end
    )
end

function M.tinypoll()
    local tmr = require("tmr")
    local memtools = require("memtools")
    local j = 0
    local c = 60

    print("Contiuously polling TINY...")

    local t = tmr.create()
    t:alarm(
        1000,
        tmr.ALARM_SEMI,
        function()
            if c == 60 then
                print(string.format("Iteration ", j))
                memtools.rtcmem_write_log_slot(0, memtools.tiny_read_log())
                local content = memtools.rtcmem_read_log_json()
                local webapi = require("webapi")
                webapi.server_sync(
                    content,
                    function(result, ota_update)
                        if result then
                            print("Post succesful")
                        else
                            print("Post failed")
                        end
                        j = j + 1
                        c = 1
                        t:start()
                    end
                )
            else
                print("Time: " .. c)
                c = c + 1
                t:start()
            end
        end
    )
end

function M.ota_update()
    print("Testing OTA")

    local webapi = require("webapi")
    webapi.server_sync(
        nil,
        function(result, ota_content)
            if result and ota_content ~= nil then
                webapi.ota_update(
                    ota_content,
                    function(ota_result)
                        if ota_result then
                            print("OTA update OK!")
                        else
                            print("OTA failed")
                        end
                    end
                )
            else
                print("Post failed or no OTA update available")
            end
        end
    )
end

return M
