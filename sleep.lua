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