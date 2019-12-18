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

function tiny_read_log()

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
  local i
  local data32 = {}
  
  i2c.setup(id, sda, scl, i2c.SLOW)
  i2c.address(id, slv, i2c.RECEIVER)
  rec = i2c.read(id, 40)

  local byte = 0
  local temp = 0
  local checksum_calculated = 64
  local checksum_received

  -- Encodes the 40 bytes into 10 32-bit integers
  for i = 1, #rec do
    local b = string.byte(rec:sub(i, i))
    
    if b < 40 then
      checksum_calculated = checksum_calculated + b
    end
    
    --print("I2C byte " .. (i - 1) .. ":" .. b)

    temp = temp + b * 2 ^ (8 * byte)
    byte = byte + 1

    if (byte == 4) then       
      table.insert(data32, temp)
      temp = 0
      byte = 0
    end
  end
  
  checksum_calculated = checksum_calculated % 256
  checksum_received = string.byte(rec:sub(#rec, #rec))

  if not (checksum_received == checksum_calculated) then
    print("CHECKSUM ERROR! Calculated: " .. checksum_calculated .. " - Received:" .. checksum_received)
  end

  return data32

end

function tiny_read_log_fake() 
  local i
  local data32 = {}

  for i = 1, 10 do
    table.insert(data32, i * 1000)
  end

  return data32

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

function deep_sleep(cycle, cycle_length, wifiresume, clear_log)

  rtcmem_set_sleep_cycle(cycle)

  if (clear_log) then
    rtcmem_clear_log()
  end

  if (wifiresume) then
    print("Enter deep sleep cycle " .. tostring(cycle) .. " (" .. tostring(cycle_length) .. " s). Wi-Fi will be turned on at wake-up.")
    opt = nil
  else
    print("Enter deep sleep cycle " .. tostring(cycle) .. " (" .. tostring(cycle_length) .. " s).")
    opt = 4
  end

  local t = tmr.create()
	t:alarm(1000, tmr.ALARM_SINGLE, function()
    rtctime.dsleep(1000000 * cycle_length, opt)
  end)
  
  do return end

end
