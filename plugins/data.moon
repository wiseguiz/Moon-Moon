import IRCClient from require 'irc'

serve_self = (new_table)-> setmetatable(new_table, {__call: =>pairs(@)})
unpack = unpack or table.unpack

caps = {'extended-join', 'multi-prefix', 'away-notify', 'account-notify',
	'chghost', 'server-time', 'echo-message', 'invite-notify'}

IRCClient\add_handler 'CONNECT', =>
	@channels = serve_self {}
	@users    = serve_self {}
	@server   =            {
		caps:       serve_self {}
		ircv3_caps: serve_self {}
		batches:    serve_self {}
	}

IRCClient\add_handler 'LS_CAP', =>
	-- Welcome

	for i=1, #caps
		@fire_hook 'REQ_CAP'

IRCClient\add_handler 'BATCH', (prefix, args, trail, tags)=>
	tag_type, tag = args[1]\match '(.)(.+)'
	if tag_type == '+'
		@server.batches[tag] = {unpack(args, 2)}
	elseif tag_type == '-'
		@server.batches[tag] = nil

IRCClient\add_handler '005', (prefix, args)=>
	-- Capabilities
	isupport_caps = {select 2, unpack args}
	for cap in *isupport_caps
		if cap\sub(1, 1) == "-"
			-- remove support
			if cap\find "=" then
				@server.caps[cap\match "^%-(.+)="] = nil
			else
				@server.caps[cap\sub 2] = nil
		elseif cap\find "="
			key, value = cap\match '^(.-)=(.+)'
			@server.caps[key] = value
		else
			@server.caps[cap] = true

IRCClient\add_handler 'AWAY', (prefix, args, trail)=>
	nick = prefix\match '^(.-)!'
	@users[nick].away = trail

IRCClient\add_handler 'ACCOUNT', (prefix, args, trail)=>
	nick = prefix\match '^(.-)!'
	@users[nick].account = args[1] != "*" and args[1] or nil

IRCClient\add_handler 'JOIN', (prefix, args, trail, tags={})=>
	-- user JOINs a channel
	local channel
	local account
	if @server.ircv3_caps['extended-join']
		account = args[2] if args[2] != '*'
		channel = args[1]
	elseif @server.ircv3_caps['account-tag'] and tags.account
		account = tags.account
		channel = args[1]
	else
		channel = args[1] or trail
	nick, username, host = prefix\match '^(.-)!(.-)@(.-)$'
	if prefix\match '^.-!.-@.-$'
		if not @users[nick] then
			@users[nick] = {
				account: account
				channels: {
					[channel]: {
						status: ""
					}
				},
				:username,
				:host
			}
		else
			if not @users[nick].channels
				@users[nick].channels = {
					[channel]: {
						status: ""
					}
				}
			else
				@users[nick].channels[channel] = status: ""
		@users[nick].account = account if account
	if not @channels[channel]
		if @server.ircv3_caps['userhost-in-names']
			@send_raw ('NAMES %s')\format channel
		else
			@send_raw ('WHO %s')\format channel
		@channels[channel] = {
			users: {
				[nick]: @users[nick]
			}
		}
	else
		@channels[channel].users[nick] = @users[nick]

IRCClient\add_handler 'NICK', (prefix, args, trail)=>
	old = prefix\match('^(.-)!') or prefix
	new = args[1] or trail
	for channel_name in pairs @users[old].channels
		@channels[channel_name].users[new] = @channels[channel_name].users[old]
		@channels[channel_name].users[old] = nil
	@users[new] = @users[old]
	@users[old] = nil

IRCClient\add_handler 'MODE', (prefix, args)=>
	-- User or bot called /mode
	if args[1] and args[1]\sub(1,1) == "#"
		@send_raw ('NAMES %s')\format args[1]

IRCClient\add_handler '353', (prefix, args, trail)=>
	-- Result of NAMES
	channel = args[3]
	statuses = @server.caps.PREFIX and @server.caps.PREFIX\match '%(.-%)(.+)' or "+@"
	statuses = "[" .. statuses\gsub("%p", "%%%1") .. "]"
	for text in trail\gmatch '%S+'
		local status, pre, nick, user, host
		if text\match statuses
			status, pre = text\match ('^(%s+)(.+)')\format statuses
		else
			status, pre = '', text
		if @server.ircv3_caps['userhost-in-names']
			nick, user, host = pre\match '^(.-)!(.-)@(.-)$'
		else
			nick = pre
		if not @users[nick]
			@users[nick] = {channels: {}}
		@users[nick].user = user if user
		@users[nick].host = host if host
		if @channels[channel].users[nick]
			if @users[nick].channels[channel]
				@users[nick].channels[channel].status = status
			else
				@users[nick].channels[channel] = :status
		else
			@channels[channel].users[nick] = @users[nick]
			@users[nick].channels[channel] = :status

IRCClient\add_handler '352', (prefix, args)=>
	_, user, host, _, nick, away = unpack args
	@users[nick] = {channels: {}} if not @users[nick]
	@users[nick].user = user
	@users[nick].host = host
	@users[nick].away = away\sub(1, 1) == "G"

IRCClient\add_handler 'CHGHOST', (prefix, args)=>
	nick = prefix\match '^(.-)!'
	@users[nick].user = args[1]
	@users[nick].host = args[2]

IRCClient\add_handler 'KICK', (prefix, args)=>
	channel = args[1]
	nick = args[2]
	@users[nick].channels[channel] = nil
	if #@users[nick].channels == 0
		@users[nick] = nil

IRCClient\add_handler 'PART', (prefix, args)=>
	-- User or bot parted channel, clear from lists
	channel = args[1]
	nick = prefix\match '^(.-)!'
	@users[nick].channels[channel] = nil
	if #@users[nick].channels == 0
		@users[nick] = nil -- User left network, garbagecollect

IRCClient\add_handler 'QUIT', (prefix, args)=>
	-- User or bot parted network, nuke from lists
	nick = prefix\match '^(.-)!'
	for channel in pairs @users[nick].channels
		@channels[channel].users[nick] = nil
	@users[nick] = nil

IRCClient\add_handler 'CAP', (prefix, args, trailing)=>
	to_process = {} if args[2] == 'LS' or args[2] == 'ACK' or args[2] == 'NAK'
	if args[2] == 'LS' or args[2] == 'ACK' or args[2] == 'NEW' or args[2] == 'DEL'
		for item in trailing\gmatch '%S+'
			for cap in *caps
				if item == cap
					to_process[#to_process + 1] = cap
	if args[2] == 'LS'
		if #to_process > 0
			@send_raw ('CAP REQ :%s')\format table.concat(to_process, ' ')
		for i=#to_process + 1, #caps
			@fire_hook 'ACK_CAP'
	elseif args[2] == 'NEW'
		to_send = {}
		for item in trailing\gmatch '%S+'
			for cap in *caps
				if item == cap
					to_send[#to_send + 1] = item
		@send_raw ('CAP REQ :%s')\format table.concat(to_send, ' ')
	elseif args[2] == 'DEL'
		for item in trailing\gmatch '%S+'
			@ircv3_caps[item] = nil
	elseif args[2] == 'ACK'
		for cap in *to_process
			key, value = cap\match '^(.-)=(.+)'
			if value
				@server.ircv3_caps[key] = value
			else
				@server.ircv3_caps[cap] = true
			@fire_hook 'ACK_CAP'
