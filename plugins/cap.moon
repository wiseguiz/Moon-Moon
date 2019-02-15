import IRCClient from require 'irc'

caps = {'extended-join', 'multi-prefix', 'away-notify', 'account-notify',
	    'chghost', 'server-time', 'echo-message', 'invite-notify'
	    'draft/rename', 'sasl', 'draft/message-tags-0.2'}

for cap in *caps
	caps[cap] = true -- allow index-based lookup

IRCClient\add_hook 'CONNECT', =>
	@ircv3_caps = {}
	@set_caps = 0

IRCClient\add_hook 'CAP_ACK', =>
	@set_caps -= 1
	if @set_caps <= 0
		@send_raw 'CAP END'

PROCESS_OPTS = {LS: true, ACK: true, NAK: true, DEL: true, NEW: true}

IRCClient\add_handler 'CAP', (prefix, args)=>
	to_process = {} if PROCESS_OPTS[args[2]]

	-- Take all trailing caps and put into list if supported
	if PROCESS_OPTS[args[2]]
		for item in args[#args]\gmatch '%S+'
			if caps[item]
				table.insert to_process, item

	-- Request all supported
	if args[2] == 'LS'
		if #to_process > 0
			@send_raw "CAP REQ :#{table.concat to_process, ' '}"
			@set_caps += #to_process

	-- Request new caps if supported
	elseif args[2] == 'NEW'
		@send_raw ('CAP REQ :%s')\format table.concat(to_process, ' ')

	-- Delete cap, server no longer supports (SASL, etc. if services go down)
	elseif args[2] == 'DEL'
		-- don't use to_process in case of custom added caps?
		for item in args[#args]\gmatch '%S+'
			@ircv3_caps[item] = nil

	-- Run CAP_ACK hook for all succeeding caps
	elseif args[2] == 'ACK'
		for cap in *to_process
			key, value = cap\match '^(.-)=(.+)'
			cap_name = key or cap
			if value
				@server.ircv3_caps[key] = value
			else
				@server.ircv3_caps[cap] = true
			-- THIS ORDERING IS IMPORTANT in case something relying on a target
			-- capability adds a new CAP_ACK waiter
			@fire_hook "CAP_ACK.#{cap_name}", value
			@fire_hook 'CAP_ACK'

	-- Run CAP_ACK hook for NAK'd caps
	elseif args[2] == 'NAK'
		@fire_hook 'CAP_ACK' for i=1, #to_process

IRCClient\add_command "list-caps", (prefix, channel)=>
	caps = [k for k in pairs(@server.ircv3_caps)]
	@send "COMMAND_OK", channel, "list-caps", "Caps: #{table.concat(caps, ', ')}"
