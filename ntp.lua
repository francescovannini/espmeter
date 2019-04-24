sntp.sync(nil,
			function(sec, usec, server, info)
				tm = rtctime.epoch2cal(rtctime.get())
				print(string.format("NTP time is: %04d/%02d/%02d %02d:%02d:%02d", tm["year"], tm["mon"], tm["day"], tm["hour"], tm["min"], tm["sec"]))
				--rtctime.dsleep_aligned(30 * 1000000, 1000000, 4)
			end,
			function(errno, strerr)
				print("NTP sync failed: ", errno, strerr)
				--rtctime.dsleep(30 * 1000000, 4)
				--end
				deep_sleep()
			end
		)