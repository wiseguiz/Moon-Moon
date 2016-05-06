import IRCClient from require 'irc'

patterns = {
	JOIN: "\00308[\003%s\00308]\003 \00309>\003 %s"
	MODE: "\00308[\003%s\00308]\003 Mode %s by %s"
	KICK: "\00308[\003%s\00308]\003 %s kicked %s"
	KICK_2: "\00308[\003%s\00308]\003 %s kicked %s \00315(%s)"
	PART: "\00308[\003%s\00308]\003 \00304<\003 %s"
	PART_2: "\00308[\003%s\00308]\003 \00304<\003 %s \00315(%s)"
	QUIT: "\00311<\003%s\00311>\003 \00304<\003"
	QUIT_2: "\00311<\003%s\00311>\003 \00304<\003 \00315(%s)"
	ACTION: "\00308[\003%s\00308]\003 * %s %s"
	ACTION_2: "* %s %s"
	PRIVMSG: "\00311<\00308[\003%s\00308]\003%s\00311>\003 %s"
	PRIVMSG_2: "\00311<\003%s\00311>\003 %s"
	NOTICE: "\00311-\00308[\003%s\00308]\003%s\00311-\003 %s"
	NOTICE_2: "\00311-\003%s\00311-\003 %s"
	INVITE: "\00308[\003%s\00308]\003 %s invited %s"
	NETJOIN: "\00308[\003%s\00308]\003 \00309>\003 (%s)"
	NETSPLIT: "\00304<\003 (%s)"
}

serve_self = (new_table)-> setmetatable(new_table, {__call: ()=>pairs(@)})

IRCClient\add_handler 'JOIN', (prefix, args, trail, tags={})=>
	-- user JOINs a channel
	channel = args[1] or trail
	@log patterns.JOIN\format channel, prefix\match('^(.-)!') or prefix

IRCClient\add_handler 'NICK', (prefix, args, trail)=>
	old = prefix\match('^(.-)!') or prefix
	new = args[1] or trail
	@log ('%s \00309>>\003 %s')\format old, new

IRCClient\add_handler 'MODE', (prefix, args, trailing)=>
	-- User or bot called /mode
	channel = args[1]
	table.remove(args, 1)
	if channel\sub(1,1) == "#"
		@log patterns.MODE\format channel, table.concat(args, " "), prefix\match('^(.-)!') or prefix

IRCClient\add_handler 'KICK', (prefix, args, trailing)=>
	channel = args[1]
	nick = args[2]
	kicker = prefix\match('^(.-)!') or prefix
	if trailing
		@log patterns.KICK_2\format channel, kicker, nick, trailing
	else
		@log patterns.KICK\format channel, kicker, nick

IRCClient\add_handler 'PART', (prefix, args, trailing)=>
	-- User or bot parted channel, clear from lists
	channel = args[1]
	nick = prefix\match('^(.-)!') or prefix
	if trailing
		@log patterns.PART_2\format channel, nick, trailing
	else
		@log patterns.PART\format channel, nick

IRCClient\add_handler 'QUIT', (prefix, args, trailing, tags = {})=>
	-- User or bot parted network, nuke from lists
	nick = prefix\match('^(.-)!') or prefix
	if trailing
		@log patterns.QUIT_2\format nick, trailing
	else
		@log patterns.QUIT\format nick

IRCClient\add_handler 'PRIVMSG', (prefix, args, trailing)=>
	nick = prefix\match('^(.-)!') or prefix
	if not args[1]\sub(1, 1) == '#'
		if trailing\match "^\001ACTION .-\001$"
			@log patterns.ACTION_2\format nick, trailing\match('^%S+%s+(.+)')
		elseif not trailing\match '^\001'
			@log patterns.PRIVMSG_2\format nick, trailing
	else
		ch = args[1]
		if trailing\match "^\001ACTION .-\001$"
			@log patterns.ACTION\format ch, nick, trailing\match('^%S+%s+(.+)')
		elseif not trailing\match '^\001'
			@log patterns.PRIVMSG\format ch, nick, trailing

IRCClient\add_handler 'NOTICE', (prefix, args, trailing)=>
	return if trailing\sub(1, 1) == '\001' -- CTCP
	nick = prefix\match('^(.-)!') or prefix
	if args[1]\sub(1, 1) == '#'
		@log patterns.NOTICE\format args[1], nick, trailing
	else
		@log patterns.NOTICE_2\format nick, trailing

IRCClient\add_handler 'INVITE', (prefix, args, trailing)=>
	nick = prefix\match('^(.-)!') or prefix
	channel = args[2]
	@log patterns.INVITE\format channel, nick, args[1]
