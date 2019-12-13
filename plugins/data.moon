import IRCClient, priority from require 'lib.irc'
import Map, Option from require 'lib.std'
import Channel, User from require 'lib.models'

unpack = unpack or table.unpack

IRCClient\add_hook 'CONNECT', =>
	@channels = Map!
	@users    = Map!
	@server   = {
		caps:       {}
		ircv3_caps: {}
		batches:    {}
	}
	@vars = {}

IRCClient\add_hook 'CONNECT', =>
	-- Welcome
	@data = {} if not @data
	@data.last_connect = os.time()
	@send_raw 'CAP', 'LS', '302'

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
	@users\expect(nick).away = args[#args]

IRCClient\add_handler 'ACCOUNT', (prefix, args)=>
	@users\expect(nick).account = args[1] != "*" and args[1] or nil

IRCClient\add_handler 'RENAME', (prefix, args)=>
	{old, new} = args
	for _, user in @channels\expect(old).users\iter!
		user.channels\set new, user.channels\expect old
		user.channels\remove old
	@channels\set new, @channels\expect old
	@channels\remove old

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

	new_user = User user, host, :account

	-- Make sure channel exists
	-- Confirm channel exists in bot object
	channel_entry = @channels\entry channel
	unless channel_entry\exists!
		-- Bot has joined channel
		if @server.caps['WHOX']
			@send_raw 'WHO', channel, '%nat,001'
		elseif @server.ircv3_caps['userhost-in-names']
			@send_raw 'NAMES', channel
		else
			@send_raw 'WHO', channel

		channel_entry\or_insert Channel {
			users: {
				[nick]: new_user
			}
		}
	else
		-- Bot is already in channels, shuffle over user
		@channels\expect(channel).users[nick] = new_user

	-- Confirm channel exists in user object
	new_user.channels\set channel, @channels\expect channel
	@users\set nick, new_user

IRCClient\add_hook 'WHOX_001', (nick, account)=>
	@users\expect(nick).account = account if account != '0'

IRCClient\add_handler 'NICK', (prefix, args)=>
	old = prefix.nick
	new = args[1]
	for channel_name in @users\expect(old).channels\iter!
		channel = @channels\expect channel_name
		channel.users\set new, channel.users\expect old
		channel.users\remove old
	@users\set new, @users\expect old
	@users\remove old

IRCClient\add_handler 'MODE', (prefix, args)=>
	-- User or bot called /mode
	if args[1] and args[1]\sub(1,1) == "#"
		@send_raw 'NAMES', args[1]

IRCClient\add_handler '353', (prefix, args)=>
	-- Result of NAMES
	target = args[3]
	statuses = @server.caps.PREFIX and @server.caps.PREFIX\match '%(.-%)(.+)' or "+@"
	statuses = "[" .. statuses\gsub("%p", "%%%1") .. "]"

	channel = @channels\expect target

	for text in args[#args]\gmatch '%S+'
		local status, pre, nick, user, host
		if text\match statuses
			status, pre = text\match "^(#{statuses}*)(.-)$"
		else
			status, pre = nil, text
		if @server.ircv3_caps['userhost-in-names']
			nick, ident, host = pre\match '^(.-)!(.-)@(.-)$'
		else
			nick = pre

		channel.statuses\set nick, Option status

		if @users\contains_key nick -- NAMES not triggered from JOIN
			user = @users\expect nick
			user.user = ident
			user.host = host
		else
			@users\set nick, User(ident, host)

		-- Make sure channels and users both have links to each other
		channel.users\set nick, @users\expect nick
		@users\expect(nick).channels\set target, channel

IRCClient\add_handler '352', (prefix, args)=>
	-- Result of WHO
	_, user, host, _, nick, away = unpack args
	client = @users\entry(nick)\or_insert_with -> User :user, :host
	client.away = away\sub(1, 1) == "G" -- "H"ere or "G"one

IRCClient\add_handler 'CHGHOST', (prefix, args)=>
	{:nick} = prefix
	client = @users\expect nick
	client.user, client.host = unpack args

IRCClient\add_handler 'KICK', (prefix, args)=>
	channel = args[1]
	nick = args[2]
	client = @users\expect nick
	client.channels\remove channel
	@users\remove nick unless client\is_visible!

IRCClient\add_handler 'PART', (prefix, args)=>
	-- User or bot parted channel, clear from lists
	channel = args[1]
	{:nick} = prefix
	client = @users\expect nick
	client.channels\remove channel
	@users\remove nick unless client\is_visible!

IRCClient\add_handler 'QUIT', (prefix, args)=>
	-- User or bot parted network, nuke from lists
	{:nick} = prefix
	for channel in @users\expect(nick).channels\iter!
		@channels\expect(channel).users\remove nick
	@users\remove nick

IRCClient\add_handler 'PRIVMSG', priority: priority.HIGH, (prefix, args, tags={})=>
	account_tag = @get_tag tags, key: "account"
	if account_tag and prefix.nick and @users\contains_key prefix.nick
		@users\expect(prefix.nick).account = account_tag.value
