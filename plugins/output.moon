import IRCClient from require 'irc'

colors = {3, 4, 6, 8, 9, 10, 11, 13} -- "bright" pallet of IRC colors

hash = (input)->
	out_hash = 5381
	
	for char in input\gmatch "."
		out_hash = ((out_hash << 5) + out_hash) + char\byte!

	return out_hash

color = (input)-> "\003#{colors[hash(input) % #colors + 1]}#{input}\003"

patterns = {
	RENAME: "%s \00309=>\003 %s \00314(\00315%s\00314)\003"
	RENAME_2: "%s \00309=>\003 %s \00314(\00315%s\00314|\00315%s\00314)\003"
	JOIN: "\00308[\003%s\00308]\003 \00309>\003 %s"
	MODE: "\00308[\003%s\00308]\003 Mode %s by %s"
	KICK: "\00308[\003%s\00308]\003 %s kicked %s"
	KICK_2: "\00308[\003%s\00308]\003 %s kicked %s \00314(\00315%s\00314)\003"
	PART: "\00308[\003%s\00308]\003 \00304<\003 %s"
	PART_2: "\00308[\003%s\00308]\003 \00304<\003 %s \00314(\00315%s\00314)\003"
	QUIT: "\00311<\003%s\00311>\003 \00304<\003"
	QUIT_2: "\00311<\003%s\00311>\003 \00304<\003 \00315(\00314%s\00315)\003"
	ACTION: "\00308[\003%s\00308]\003 * %s %s"
	ACTION_2: "* %s %s"
	PRIVMSG: "\00311<\00308[\003%s\00308]\003%s\00311>\003 %s"
	PRIVMSG_2: "\00311<\003%s\00311>\003 %s"
	NOTICE: "\00311-\00308[\003%s\00308]\003%s\00311-\003 %s"
	NOTICE_2: "\00311-\003%s\00311-\003 %s"
	INVITE: "\00308[\003%s\00308]\003 %s invited %s"
	NETJOIN: "\00308[\003%s\00308]\003 \00309>\003 \00314(\00315%s\00314)\003"
	NETSPLIT: "\00304<\003 \00314(\00315%s\00314)\003"
}

serve_self = (new_table)-> setmetatable(new_table, {__call: ()=>pairs(@)})

IRCClient\add_handler '372', (prefix, args, trail)=>
	@log "\00305" .. trail

IRCClient\add_handler 'RENAME', (prefix, args, trail)=>
	nick = prefix\match("^[^!]+")
	if trail == "" or trail == nil
		@log patterns.RENAME\format args[1], args[2], nick
	else
		@log patterns.RENAME_2\format args[1], args[2], nick, trail

IRCClient\add_handler 'JOIN', (prefix, args, trail, tags={})=>
	-- user JOINs a channel
	channel = args[1] or trail
	@log patterns.JOIN\format channel, color(prefix\match('^(.-)!') or prefix)

IRCClient\add_handler 'NICK', (prefix, args, trail)=>
	old = color(prefix\match('^(.-)!') or prefix)
	new = color(args[1] or trail)
	@log ('%s \00309>>\003 %s')\format old, new

IRCClient\add_handler 'MODE', (prefix, args, trailing)=>
	-- User or bot called /mode
	channel = args[1]
	if channel\sub(1,1) == "#"
		@log patterns.MODE\format channel, table.concat(args, " ", 2),
			color(prefix\match('^(.-)!') or prefix)

IRCClient\add_handler 'KICK', (prefix, args, trailing)=>
	channel = args[1]
	nick = color(args[2])
	kicker = color(prefix\match('^(.-)!') or prefix)
	if trailing
		@log patterns.KICK_2\format channel, kicker, nick, trailing
	else
		@log patterns.KICK\format channel, kicker, nick

IRCClient\add_handler 'PART', (prefix, args, trailing)=>
	-- User or bot parted channel, clear from lists
	channel = args[1]
	nick = color(prefix\match('^(.-)!') or prefix)
	if trailing
		@log patterns.PART_2\format channel, nick, trailing
	else
		@log patterns.PART\format channel, nick

IRCClient\add_handler 'QUIT', (prefix, args, trailing, tags = {})=>
	-- User or bot parted network, nuke from lists
	nick = color(prefix\match('^(.-)!') or prefix)
	if trailing
		@log patterns.QUIT_2\format nick, trailing
	else
		@log patterns.QUIT\format nick

IRCClient\add_handler 'PRIVMSG', (prefix, args, trailing)=>
	nick = prefix\match('^(.-)!') or prefix
	if not args[1]\sub(1, 1) == '#'
		if trailing\match "^\001ACTION .-\001$"
			@log patterns.ACTION_2\format color(nick),
				trailing\match('^%S+%s+(.+)')
		elseif not trailing\match '^\001'
			@log patterns.PRIVMSG_2\format color(nick), trailing
	else
		ch = args[1]
		prefix = ""
		if @users[nick] and @users[nick].channels[ch]
			prefix = @users[nick].channels[ch].status\sub(1, 1) or ""
		if prefix != ""
			prefix = color(prefix)
		user = prefix .. color(nick)
		if trailing\match "^\001ACTION .-\001$"
			@log patterns.ACTION\format ch, user, trailing\match('^%S+%s+(.+)')
		elseif not trailing\match '^\001'
			@log patterns.PRIVMSG\format ch, user, trailing

IRCClient\add_handler 'NOTICE', (prefix, args, trailing)=>
	return if trailing\sub(1, 1) == '\001' -- CTCP
	nick = prefix\match('^(.-)!') or prefix
	if args[1]\sub(1, 1) == '#'
		prefix = ""
		if @users[nick] and @users[nick].channels[ch]
			prefix = @users[nick].channels[ch].status\sub(1, 1) or ""
		if prefix != ""
			prefix = color(prefix)
		user = prefix .. color(nick)
		@log patterns.NOTICE\format args[1], user, trailing
	else
		@log patterns.NOTICE_2\format color(nick), trailing

IRCClient\add_handler 'INVITE', (prefix, args, trailing)=>
	nick = color(prefix\match('^(.-)!') or prefix)
	channel = args[2]
	@log patterns.INVITE\format channel, nick, args[1]
