rtc_mem_cycle_addres = 127
rtc_mem_log_address = 46

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ', '
      end
      return s .. '} '
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

function rtcmem_read_log_json()
  local i
  local t
  local v
  local log = '{"log":['

  for i = 0, 79 do
    t = rtc_mem_log_address + i
    v = rtcmem.read32(t)
    --print("Read " .. v .. " at RTC memory location " .. t)
    log = log .. v
    if i < 79 then
       log = log .. ','
    end
  end

  log = log .. ']}'

  --print("Generated log: " .. log)

  return log 
end

function rtcmem_clear_log()
  print("Clearing RTC log.")
  local i
  for i = 0, 79 do   
    rtcmem.write32(rtc_mem_log_address + i, i)
  end  
end


