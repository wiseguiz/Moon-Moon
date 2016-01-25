handlers:
	['CAP']: (prefix, args, trail)=>
		if args[2] == "DEL"
			for cap in trail\gmatch '%S+'
				@server.ircv3_caps[cap] = nil
		elseif args[2] == "NEW"
			@send_raw 'CAP LS' -- re-register all caps
