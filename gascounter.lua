print("GasCounter node started!")

local cycle = rtcmem_get_sleep_cycle()

if cycle == nil then
	print("Sleep cycle uninitialized, getting it from server.")	
	do_api_call(false)	
else	
	print("Completed sleep cycle #" .. cycle)	
	local log = tiny_read_log()
	print(dump(log))
	rtcmem_write_log_slot(cycle, log)

	if cycle == 7 then
		print("Sleeping plan completed! Posting content.")
		do_api_call(true)
	else 
		cycle = cycle + 1
		rtcmem_set_sleep_cycle(cycle)	
		print("Beginning sleep cycle #" .. cycle)
		enter_sleep_cycle(cycle, conf.sleep.sleep_seconds, cycle == 7)
	end
end

do return end
