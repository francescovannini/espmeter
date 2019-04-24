print("GasCounter node started!")

--[[

	Sleep cycle 0 begins at midnight. End of cycle 7 ends also at midnight.
	Each cycle lasts 3 hours; at the end of each cycle, data from the AVR is 
	dumped into the RTC memory.
	At the end of cycle 7, which should occur around midnight, all RTC
	memory is transferred to server and the sleep cycle is synchronized.

	Sleep cycle information is stored in RTC memory slot 0.
	Data logged by AVR is stored from slots 1-80 totalling 320 bytes per day.	

]]--

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
