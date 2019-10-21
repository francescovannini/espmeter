print("GasCounter node started!")

local cycle = rtcmem_get_sleep_cycle()

if node.bootreason() == 0 or cycle == nil then
	print("Syncronizing sleep plan with server...")	
	do_api_call(false)	
else	
	print("Completed sleep cycle #" .. cycle)	
	local log = tiny_read_log()
	print("Data from tiny:" .. dump(log))
	rtcmem_write_log_slot(cycle, log)

	if cycle == 7 then
		print("Sleeping plan completed! Posting content.")
		do_api_call(true)
	else 
		cycle = cycle + 1
		rtcmem_set_sleep_cycle(cycle)	
		print("Beginning sleep cycle #" .. cycle)
		enter_sleep_cycle(cycle, conf.sleep.cycle_length, cycle == 7)
	end
end

do return end
