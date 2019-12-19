rtc_mem_cycle_addres = 127
rtc_mem_log_address = 46

function dump(o)
	if type(o) == 'table' then
			local s = '{'
			for k, v in pairs(o) do
				if type(k) ~= 'number' then
					k = '"'..k..'"' 
				end
				s = s .. '[' .. k .. '] = ' .. dump(v) .. ', '
			end
			return s .. '}'
	 else
			return '"' .. tostring(o) ..'"'
	 end
end

function int32_to_8(value)
	local a = value % 256
	local b = math.floor(value / 256 + 0.5) % 256
	local c = math.floor(value / 65536 + 0.5) % 256
	local d = math.floor(value / 16777216 + 0.5) % 256
	return a, b, c, d
end

function int8_to_32(a, b, c, d)
	local v = a + b * 256 + c * 65536 + d * 16777216
	return v
end

function rtcmem_get_sleep_cycle()
	local cycle, cs_a, cs_b, cs_c
	cycle, cs_a, cs_b, cs_c = int32_to_8(rtcmem.read32(rtc_mem_cycle_addres))
	if not ((cycle == cs_a - 1) and (cs_a == cs_b - 1) and (cs_b == cs_c - 1)) then
		return nil
	else
		if cycle > 8 then
			return nil
		else
			return cycle
		end
	end
end

function rtcmem_set_sleep_cycle(cycle)
	rtcmem.write32(rtc_mem_cycle_addres, int8_to_32(cycle, cycle + 1, cycle + 2, cycle + 3))
end

function rtcmem_write_log_slot(slot, data32)
	local i
	local t
	for i = 1, 10 do 
		t = rtc_mem_log_address + (slot * 10) + (i - 1)
		--print("Writing " .. data32[i] .. " at RTC memory location " .. t)
		rtcmem.write32(t, data32[i])
	end
end

function rtcmem_clear_log()
	print("Clearing RTC log.")
	local i
	for i = 0, 79 do   
		rtcmem.write32(rtc_mem_log_address + i, i)
	end  
end

function rtcmem_read_log_json()
	local i
	local t
	local v
	local log = '{"log":['

	for i = 0, 79 do
		t = rtc_mem_log_address + i
		v = rtcmem.read32(t)
		
		log = log .. v
		if i < 79 then
			 log = log .. ','
		end
	end

	log = log .. ']}'

	--print("Generated log: " .. log)

	return log 
end

--[[
typedef struct pulse_log_t {
	uint8_t vcc;
	uint16_t ticks;
	uint8_t frames[LOG_FRAMES];
} pulse_log_t;
]]

function rtcmem_read_log_json()
	local i, j, a, b, c, d
	local cycles = {}
	local cycle_buf = {}
	local log = "{"

	j = 0
	for i = 0, 79 do    
				
		a, b, c, d = int32_to_8(rtcmem.read32(rtc_mem_log_address + i))
		table.insert(cycle_buf, a)
		table.insert(cycle_buf, b)
		table.insert(cycle_buf, c)
		table.insert(cycle_buf, d)
		
		j = j + 4
		if j == 40 then
			table.insert(cycles, cycle_buf)
			cycle_buf = {}
			j = 0
		end

	end

	local cycle
	local cycle_idx
	local valid_cycles = 0

	for cycle_idx, cycle in pairs(cycles) do

		local byte_idx
		local byte
		local intbuf
		local checksum = 64
		local logbuf

		for byte_idx, byte in pairs(cycle) do

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
				logbuf = logbuf .. ',"f": [' .. tostring(byte)
			end

			if byte_idx > 4 and byte_idx < 39 then
				logbuf = logbuf .. ',' .. tostring(byte)
			end

			if byte_idx == 39 then
				logbuf = logbuf .. ',' .. tostring(byte) .. ']}'
			end

			if byte_idx == 40 then
				if checksum % 256 == byte then
					if valid_cycles > 0 then
						log = log .. ','
					end
					log = log .. '"' .. tostring(cycle_idx - 1) .. '": ' .. logbuf
					valid_cycles = valid_cycles + 1
				end
			end
		end
	end

	log = log .. '}'

	return log 
end
