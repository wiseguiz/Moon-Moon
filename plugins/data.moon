Logger = require 'logger'
print = Logger.debug

serve_self ==> setmetatable(@, {__call: ()=>pairs(@)})

handlers:
	['001']: =>
		-- Welcome
		@channels = serve_self {}
		@users    = serve_self {}
		@server   =            {
			caps: {}
		}
		print 'Resetting channels, users, and server'
	['005']: (prefix, args)=>
		-- Capabilities
		print 'Reading capabilities'
		for _, cap in pairs args
			if cap\find "="
				key, value = cap\match '^(.-)=(.+)'
				@server.caps[key] = value
				print ("%s: %s")\format(key, value)
			else
				@server.caps[cap] = true
				print cap
	['JOIN']: (prefix, args, trail)=>
		-- user JOINs a channel
		channel = trail or args[1]
		nick, username, host = prefix\match '^(.-)!(.-)@(.-)$'
		if prefix\match '^.-!.-@.-$'
			nick, username, host = prefix\match '^(.-)!(.-)@(.-)$'
			if not @users[nick] then
				print 'Registering user ' .. nick
				@users[nick] = {
					channels: {
						[channel]: {
							status: ""
						}
					},
					:username,
					:host
				}
			else
				@users[nick].channels = {
					[channel]: {
						status: ""
					}
				}
		if not @channels[channel]
			print 'Registering channel ' .. channel
			@channels[channel] = {
				users: {
					[nick]: @users[nick]
				}
			}
	['MODE']: (prefix, args)=>
		-- User or bot called /mode
		print 'Received mode change: ' .. table.concat(args, ", ")
		if prefix[1] == "#"
			@\send_raw ('NAMES')\format args[1]
	['353']: (prefix, args, trail)=>
		-- Result of NAMES
		channel = args[3]
		statuses = @server.caps.PREFIX and @server.caps.PREFIX\match '%(.-%)(.+)' or "+@"
		statuses = "^[" .. statuses\gsub("%[%]%(%)%.%+%-%*%?%^%$%%", "%%%1") .. "]"
		for text in trail\gmatch '%S+'
			local status, nick
			if text\match statuses
				status, nick = text\match '^(.)(.+)'
			else
				status, nick = '', text
			if @channels[channel].users[nick]
				if @users[nick].channels[channel]
					print ('Setting status of %s in %s to %s')\format nick, channel, status
					@users[nick].channels[channel].status = status
				else
					@users[nick].channels[channel] = :status
			else
				print ('Registering user %s of %s for status %s')\format nick, channel, status
				@channels[channel].users[nick] = {
					channels: {
						[channel]: :status
					}
				}
	['PART']: (prefix, args)=>
		-- User or bot parted channel, clear from lists
		channel = args[1]
		nick = prefix\match '^(.-)!'
		@users[nick].channels[channel] = nil
		if #@users[nick].channels == 0
			print ('Garbaging user %s')\format nick
			@users[nick] = nil -- User left network, garbagecollect
	['QUIT']: (prefix, args)=>
		-- User or bot parted network, nuke from lists
		channel = args[1]
		nick = prefix\match '^(.-)!'
		for channel in @users[nick].channels do
			print ('Removing %s from %s')\format nick, channel
			@channels[channel].users[nick] = nil
		print ('Garbaging user %s')\format nick
		@users[nick] = nil
