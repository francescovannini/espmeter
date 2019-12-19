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
	
		-- Encodes the 40 bytes into 10 32-bit integers
		for i = 1, #rec do
			local b = string.byte(rec:sub(i, i))
			
			--[print("I2C byte " .. (i - 1) .. ":" .. b)]]--
	
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

