import IRCClient, priority from require 'lib.irc'
import Map, Option from require 'lib.std'
import Channel, User from require 'lib.models'

unpack = unpack or table.unpack

missing_nick_for = (command, nick)-> "Couldn't see nick for #{command}: #{nick}"
missing_channel_for = (command, channel)-> "Couldn't see channel for #{command}: #{channel}"

IRCClient\add_handler '005', (prefix, args)=>
	-- Capabilities
	isupport_caps = {select 2, unpack args}
	for cap in *isupport_caps
		local cap_name
		if cap\sub(1, 1) == "-"
			cap_name = cap\match "^%-([^=]*)"
			cap_value = @server.caps[cap_name]
			@server.caps[cap_name] = nil
			@fire_hook "ISUPPORT.#{cap_name}.DEL", cap_value
		else
			cap_name = cap\match "^([^=]*)"
			cap_value = cap\find"=" and cap\match"=(.+)$" or true
			@server.caps[cap_name] = cap_value
			@fire_hook "ISUPPORT.#{cap_name}.ADD", cap_value
		@fire_hook "ISUPPORT.#{cap_name}", cap_value

IRCClient\add_handler 'AWAY', (prefix, args)=>
	{:nick} = prefix
	user = @users\expect nick, missing_nick_for "AWAY", nick
	if args[1]
		user.away = Option args[1]
		@fire_hook "USER.AWAY", user, user.away
	else
		user.away = Option!

IRCClient\add_handler 'ACCOUNT', (prefix, args)=>
	{:nick} = prefix
	user = @users\expect nick missing_nick_for "ACCOUNT", nick
	if args[1] == "*"
		user.account = Option!
		@fire_hook "USER.SIGNOUT", user
	else
		user.account = Option args[1]
		@fire_hook "USER.SIGNIN", user, args[1]

IRCClient\add_handler 'RENAME', (prefix, args)=>
	{old, new} = args
	old_channel = @channels\expect old, missing_channel_for "RENAME", old
	old_channel.name = new_channel
	for _, user in old_channel.users\iter!
		users.channels\set new, old_channel
		users.channels\remove old
	@channels\set new, old_channel
	@channels\remove old

	@fire_hook "CHANNEL.RENAME", old_channel, old, new

IRCClient\add_handler 'JOIN', (prefix, args, tags)=>
	local account, realname
	{:nick, :user, :host} = prefix
	channel = args[1]
	if @server.ircv3_caps['extended-join']
		account = args[2] != '*' and args[2] or nil
		realname = args[3]
	elseif @server.ircv3_caps['account-tag']
		account = tags.account

	-- Make sure user exists
	joined_user = @users\entry(nick)\or_insert_with ->
		User self, nick, user, host, :account, :realname

	-- Make sure channel exists
	unless @channels\contains_key channel -- Bot has just joined the channel
		-- Get a list of accounts for all channel users
		if @server.caps['WHOX'] and not @server.ircv3_caps['account-tag']
			@send_raw 'WHO', channel, '%nat,001'

		-- Get user and host for all channel users
		unless @server.ircv3_caps['userhost-in-names']
			@send_raw 'WHO', channel

		@channels\set channel, Channel self, channel, {
			users: {
				[nick]: joined_user
			}
		}
	else
		@channels\unwrap(channel).users\set nick, joined_user

	channel_object = @channels\unwrap channel

	-- Add this channel to the joined user's channel list
	joined_user.channels\set channel, channel_object
	@fire_hook "CHANNEL.JOIN", channel_object, joined_user
	@fire_hook "USER.JOIN", joined_user, channel_object

IRCClient\add_hook 'WHOX_001', (nick, account)=>
	@users\expect(nick, missing_nick_for "WHOX_001", nick).account = Option(account) if account != '0'

IRCClient\add_handler '353', (prefix, args)=>
	-- Result of NAMES, for JOIN
	target = args[3]
	statuses = @server.caps.PREFIX and @server.caps.PREFIX\match '%(.-%)(.+)' or "+@"
	statuses = "[" .. statuses\gsub("%p", "%%%1") .. "]"

	channel = @channels\expect target

	for text in args[#args]\gmatch '%S+'
		local status, pre, nick, ident, host
		if text\match statuses
			status, pre = text\match "^(#{statuses}*)(.-)$"
		else
			status, pre = nil, text
		if @server.ircv3_caps['userhost-in-names']
			nick, ident, host = pre\match '^(.-)!(.-)@(.-)$'
		else
			nick = pre

		channel.statuses\set nick, status

		if @users\contains_key nick -- NAMES not triggered from JOIN
			user = @users\expect nick
			user.user = ident if ident
			user.host = host if host
		else
			@users\set nick, User(self, nick, ident or "", host or "")

		-- Make sure channels and users both have links to each other
		channel.users\set nick, @users\expect nick
		@users\expect(nick).channels\set target, channel

IRCClient\add_handler '352', (prefix, args)=>
	-- Result of WHO, for JOIN
	_, user, host, _, nick, away = unpack args
	client = @users\entry(nick)\or_insert_with -> User self, nick, user, host
	client.user = user
	client.host = host
	client.away = Option away\sub(1, 1) == "G" and "No value set" or nil -- "H"ere or "G"one

IRCClient\add_handler 'NICK', (prefix, args)=>
	{nick: old} = prefix
	{new} = args
	user = @users\expect old, missing_nick_for "NICK", old
	for _, channel in user.channels\iter!
		channel.users\set new, user
		channel.users\remove old
	@users\set new, user
	@users\remove old
	@fire_hook "USER.NICK", user, old, new
	-- Tempted to put in a USER.RENAME here but it could be used further down
	-- the line for some other reason.

IRCClient\add_handler 'MODE', (prefix, args)=>
	-- User or bot called /mode
	-- This should be managed further down the line with events such as
	-- CHANNEL.OP, CHANNEL.DEOP, CHANNEL.MODE, etc. but it's not something
	-- I have all the stuff for right now. For now, we're just going to fire
	-- a generic CHANNEL.MODE or USER.MODE event.
	target = args[1]
	table.remove(args, 1)
	if target\match "^#"
		@send_raw "NAMES", target
		channel = @channels\expect target, missing_channel_for "MODE", target
		@fire_hook "CHANNEL.MODE", channel, unpack args
	else
		user = @users\expect target, missing_nick_for "MODE", target
		@fire_hook "USER.MODE", user, unpack args

IRCClient\add_handler 'CHGHOST', (prefix, args)=>
	{:nick} = prefix
	client = @users\expect nick, missing_nick_for "CHGHOST", nick
	client.user, client.host = unpack args
	@fire_hook "USER.CHGHOST", client, unpack args

IRCClient\add_handler 'KICK', (prefix, args)=>
	{channel, target, message} = args
	client = @users\expect target, missing_nick_for "KICK", target
	channel = @chanenls\expect channel, missing_channel_for "KICK", channel
	channel\remove client.nick
	client.channels\remove channel.name
	@users\remove client.nick unles client\is_visible!
	@fire_hook "CHANNEL.KICK", channel, client, message

IRCClient\add_handler 'PART', (prefix, args)=>
	{channel, target, message} = args
	client = @users\expect target, missing_nick_for "PART", target
	channel = @chanenls\expect channel, missing_channel_for "PART", channel
	channel\remove client.nick
	client.channels\remove channel.name
	@users\remove client.nick unles client\is_visible!
	@fire_hook "CHANNEL.PART", channel, client, message
	@fire_hook "USER.PART", client, channel, message

IRCClient\add_handler 'QUIT', (prefix, args)=>
	{:nick} = prefix
	user = @users\expect nick, missing_nick_for "QUIT", nick
	for _, channel in user.channels\iter!
		channel\remove nick
	@users\remove nick
