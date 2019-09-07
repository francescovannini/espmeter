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

  print("Getting data from I2C bus...")
  
  i2c.setup(id, sda, scl, i2c.SLOW)
  i2c.address(id, slv, i2c.RECEIVER)
  rec = i2c.read(id, 40)

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
  rtcmem.write32(rtc_mem_log_address + (slot * 10), data32[1], data32[2], data32[3], data32[4], data32[5], data32[6], data32[7], data32[8], data32[9], data32[10])
end

function rtcmem_read_log()
  local i
  local data32 = ""

  for i = 0, 79 do   
    data32 = data32 .. rtcmem.read32(rtc_mem_log_address + i)
    if i < 79 then
       data32 = data32 .. ","
    end
  end
  return data32
end

function rtcmem_clear_log()
  print("Clearing RTC log.")
  local i
  for i = 0, 79 do   
    rtcmem.write32(rtc_mem_log_address + i, i)
  end  
end

function enter_sleep_cycle(cycle, cycle_length, wifiresume)
  if (wifiresume) then
	    print("Sleeping " .. cycle_length .. " seconds. Wi-Fi will turn on after wake up.")
    node.dsleep(1000000 * cycle_length)
  else
    print("Sleeping " .. cycle_length .. " seconds. Wi-Fi will stay off after wake up.")
    node.dsleep(1000000 * cycle_length, 4)
  end
end
