serve_self ==> setmetatable(@, {__call: ()=>pairs(@)})

handlers:
	['001']: =>
		-- Welcome
		@channels = serve_self {}
		@users    = serve_self {}
		@server   =            {
			caps: {}
		}
	['005']: (prefix, args)=>
		-- Capabilities
		for _, cap in pairs args
			if v\find "="
				key, value = cap\match '^(.-)=(.+)'
				@server.caps[key] = value
			else
				@server.caps[cap] = true
	['JOIN']: (prefix, args, trail)=>
		-- user JOINs a channel
		channel = trail or args[1]
		if prefix\match '^.-!.-@.-$'
			nick, username, host = prefix\match '^(.-)!(.-)@(.-)$'
			if not users[nick] then
				users[nick] = {
					channels: {
						[channel]: {
							status: ""
						}
					},
					:username,
					:host
				}
			else
				if users[nick].channels
					users[nick].channels[channel] = {
						status: ""
					}
				else
					users[nick].channels = {
						[channel]: {
							status: ""
						}
					}
		if not channels[channel]
			channels[channel] = {
				users: {
					[nick]: users[nick]
				}
			}
	['MODE']: (prefix, args)=>
		-- User or bot called /mode
		@\send_raw ('NAMES')\format args[1]
	['353']: (prefix, args, trail)=>
		-- Result of NAMES
		channel = args[3]
		statuses = @server.caps.PREFIX and @server.caps.PREFIX\match '%(.-%)(.+)' or "+@"
		statuses = "^[" .. statuses\gsub "%[%]%(%)%.%+%-%*%?%^%$%%", "%%%1" .. "]"
		for text in trail\gmatch '%S+'
			local status, nick
			if text\match statuses
				status, nick = text\match '^(.)(.+)'
			else
				status, nick = '', text
			if channels[channel].users[nick]
				if users[nick].channels[channel]
					users[nick].channels[channel].status = status
				else
					users[ncik].channels[channel] = :status
			else
				channels[channel].users[nick] = {
					channels: {
						[channel]: :status
					}
				}
	['PART']: (prefix, args)=>
		-- User or bot parted channel, clear from lists
	['QUIT']: (prefix, args)=>
		-- User or bot parted network, nuke from lists
