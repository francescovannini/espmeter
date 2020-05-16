local M = {}

local rtcmem = require("rtcmem")
local tmr = require("tmr")
local conf = require("conf")
local rtctime = require("rtctime")

local rtc_mem_log_address = 11
local rtc_mem_clock_cal_address = 10

function M.int32_to_8(value)
	local bit = require("bit")
	local a = bit.band(value, 255)

	value = bit.rshift(value, 8)
	local b = bit.band(value, 255)

	value = bit.rshift(value, 8)
	local c = bit.band(value, 255)

	value = bit.rshift(value, 8)
	local d = bit.band(value, 255)

	return a, b, c, d
end

function M.int8_to_32(a, b, c, d)
	local bit = require("bit")
	return bit.lshift(d, 24) + bit.lshift(c, 16) + bit.lshift(b, 8) + a
end

function M.rtcmem_get_clock_calibration_status()
	local status, status_a, status_b, status_c
	status, status_a, status_b, status_c = M.int32_to_8(rtcmem.read32(rtc_mem_clock_cal_address))
	if (status == status_a - 1) and (status == status_b - 2) and (status == status_c - 3) then
		return status
	else
		return nil
	end
end

function M.rtcmem_set_clock_calibration_status(cycle)
	rtcmem.write32(rtc_mem_clock_cal_address, M.int8_to_32(cycle, cycle + 1, cycle + 2, cycle + 3))
end

-- First slot is 0
function M.rtcmem_write_log_slot(slot, data32)
	local t = rtc_mem_log_address + (slot * 10)
	for i = 0, 9 do
		rtcmem.write32(t + i, data32[i + 1])
	end
end

-- First slot is 0
function M.rtcmem_read_log_slot(slot)
	local t = rtc_mem_log_address + (slot * 10)
	local data32 = {}
	for i = 0, 9 do
		data32[i + 1] = rtcmem.read32(t + i)
	end
	return data32
end

function M.rtcmem_clear_log()
	for i = 0, 79 do
		rtcmem.write32(rtc_mem_log_address + i, i)
	end
end

function M.rtcmem_erase()
	for i = 0, 127 do
		rtcmem.write32(i, 0)
	end
end

--[[
typedef struct pulse_log_t {
	uint8_t vcc;
	uint16_t ticks;
	uint8_t frames[LOG_FRAMES];
} pulse_log_t;
]]
function M.rtcmem_read_log_json()
	local cycles = {}

	local log = string.format('{"vrs":"%s","ts":%d,"dt":{', conf.ota.version, rtctime.get())
	local cycle_buf = {}

	local j = 0
	for i = 0, 79 do
		local a, b, c, d

		a, b, c, d = M.int32_to_8(rtcmem.read32(rtc_mem_log_address + i))
		table.insert(cycle_buf, a)
		table.insert(cycle_buf, b)
		table.insert(cycle_buf, c)
		table.insert(cycle_buf, d)

		tmr.wdclr()

		j = j + 4
		if j == 40 then
			table.insert(cycles, cycle_buf)
			cycle_buf = {}
			j = 0
		end
	end

	local valid_cycles = 0
	for cycle_idx, status in pairs(cycles) do
		local intbuf
		local checksum = 64
		local logbuf

		for byte_idx, byte in pairs(status) do
			if byte_idx < 40 then
				checksum = checksum + byte
			end

			if byte_idx == 1 then
				logbuf = '{"v":' .. tostring(byte)
			end

			-- First byte of the "ticks" uint16
			if byte_idx == 2 then
				intbuf = byte
			end

			if byte_idx == 3 then
				intbuf = intbuf + byte * 256
				logbuf = logbuf .. ',"t":' .. tostring(intbuf)
			end

			if byte_idx == 4 then
				logbuf = logbuf .. ',"f":[' .. tostring(byte)
			end

			if byte_idx > 4 and byte_idx < 39 then
				logbuf = logbuf .. "," .. tostring(byte)
			end

			if byte_idx == 39 then
				logbuf = logbuf .. "," .. tostring(byte) .. "]}"
			end

			if byte_idx == 40 then
				if checksum % 256 == byte then
					if valid_cycles > 0 then
						log = log .. ","
					end
					log = log .. '"' .. tostring(cycle_idx - 1) .. '":' .. logbuf
					valid_cycles = valid_cycles + 1
				end
			end
		end
	end

	log = log .. "}}"

	return log
end

function M.tiny2rtc(slot)
	-- Pin mapping between ESP and NodeMCU IO
	--  IO  ESP     IO  ESP
	--  0   GPIO16  7   GPIO13
	--  1   GPIO5   8   GPIO15
	--  2   GPIO4   9   GPIO3
	--  3   GPIO0   10  GPIO1
	--  4   GPIO2   11  GPIO9
	--  5   GPIO14  12  GPIO10
	--  6   GPIO12

	local id = 0
	local sda = 1
	local scl = 2
	local slv = 0x5d
	local data32 = {}

	local i2c = require("i2c")

	i2c.setup(id, sda, scl, i2c.SLOW)
	i2c.address(id, slv, i2c.RECEIVER)

	local rec = i2c.read(id, 40)
	local byte = 0
	local temp = 0

	-- Encodes the 40 bytes into 10 32-bit integers
	for i = 1, #rec do
		local b = string.byte(rec:sub(i, i))
		temp = temp + b * 2 ^ (8 * byte)
		byte = byte + 1

		if (byte == 4) then
			table.insert(data32, temp)
			temp = 0
			byte = 0
		end
	end

	if slot ~= nil then
		local t = rtc_mem_log_address + (slot * 10)
		for i = 0, 9 do
			rtcmem.write32(t + i, data32[i + 1])
		end
	end
end

function M._unload()
	package.loaded["memtools"] = nil
end

return M
