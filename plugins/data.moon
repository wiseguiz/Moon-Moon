import IRCClient from require 'irc'

unpack = unpack or table.unpack

IRCClient\add_hook 'CONNECT', =>
	@channels = {}
	@users    = {}
	@server   = {
		caps:       {}
		ircv3_caps: {}
		batches:    {}
	}

IRCClient\add_hook 'CONNECT', =>
	-- Welcome
	@data = {} if not @data
	@data.last_connect = os.time()
	@send_raw 'CAP LS 302'

IRCClient\add_handler 'BATCH', (prefix, args, tags)=>
	-- ::TODO:: add in hook system for BATCH
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

IRCClient\add_handler 'AWAY', (prefix, args)=>
	{:nick} = prefix
	@users[nick].away = args[#args]

IRCClient\add_handler 'ACCOUNT', (prefix, args)=>
	@users[nick].account = args[1] != "*" and args[1] or nil

IRCClient\add_handler 'RENAME', (prefix, args)=>
	{old, new} = args
	for _, user in pairs @channels[old].users
		user.channels[new] = user.channels[old]
		user.channels[old] = nil
	@channels[new] = @channels[old]
	@channels[old] = nil

IRCClient\add_handler 'JOIN', (prefix, args, tags={})=>
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
		channel = args[1]
	{:nick, :user, :host} = prefix
	if host
		if not @users[nick] then
			@users[nick] = {
				account: account
				channels: {
					[channel]: {
						status: ""
					}
				},
				:user,
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
		if @server.caps['WHOX']
			@send_raw "WHO #{channel} %nat,001"
		else @server.ircv3_caps['userhost-in-names']
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

IRCClient\add_hook 'WHOX_001', (nick, account)=>
	@users[nick].account = account if @users[nick] and account ~= '0'

IRCClient\add_handler 'NICK', (prefix, args)=>
	old = prefix.nick
	new = args[1]
	for channel_name in pairs @users[old].channels
		@channels[channel_name].users[new] = @channels[channel_name].users[old]
		@channels[channel_name].users[old] = nil
	@users[new] = @users[old]
	@users[old] = nil

IRCClient\add_handler 'MODE', (prefix, args)=>
	-- User or bot called /mode
	if args[1] and args[1]\sub(1,1) == "#"
		@send_raw ('NAMES %s')\format args[1]

IRCClient\add_handler '353', (prefix, args)=>
	-- Result of NAMES
	channel = args[3]
	statuses = @server.caps.PREFIX and @server.caps.PREFIX\match '%(.-%)(.+)' or "+@"
	statuses = "[" .. statuses\gsub("%p", "%%%1") .. "]"
	for text in args[#args]\gmatch '%S+'
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
	{:nick} = prefix
	@users[nick].user = args[1]
	@users[nick].host = args[2]

IRCClient\add_handler 'KICK', (prefix, args)=>
	channel = args[1]
	nick = args[2]
	@users[nick].channels[channel] = nil
	if not next @users[nick].channels
		@users[nick] = nil

IRCClient\add_handler 'PART', (prefix, args)=>
	-- User or bot parted channel, clear from lists
	channel = args[1]
	{:nick} = prefix
	@users[nick].channels[channel] = nil
	if not next @users[nick].channels
		@users[nick] = nil -- User left network, garbagecollect

IRCClient\add_handler 'QUIT', (prefix, args)=>
	-- User or bot parted network, nuke from lists
	{:nick} = prefix
	for channel in pairs @users[nick].channels
		@channels[channel].users[nick] = nil
	@users[nick] = nil
