print("GasCounter node started!")

local tm = rtctime.epoch2cal(tz.gettime())
print(string.format("Current time: %04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))

local cycle = rtcmem_get_sleep_cycle()

if node.bootreason() == 0 or cycle == nil then
	print("Fresh boot, syncing with server...")	
	do_api_call(false)	
else	
	print("Completed sleep cycle: " .. cycle)

	local log = tiny_read_log()	
	rtcmem_write_log_slot(cycle, log)

	if cycle == 7 then		
		do_api_call(true)
	else 
		cycle = cycle + 1
		deep_sleep(cycle, conf.sleep.cycle_length, cycle == 7, false)
	end
end

do return end
