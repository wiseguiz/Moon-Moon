Logger = require 'logger'

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
}

serve_self ==> setmetatable(@, {__call: ()=>pairs(@)})

{
	handlers:
		['JOIN']: (prefix, args, trail)=>
			-- user JOINs a channel
			channel = args[1] or trail
			Logger.print patterns.JOIN\format channel, prefix\match('^(.-)!') or prefix
		['NICK']: (prefix, args, trail)=>
			old = prefix\match('^(.-)!') or prefix
			new = args[1] or trail
			Logger.print ('%s \00309>>\003 %s')\format old, new
		['MODE']: (prefix, args, trailing)=>
			-- User or bot called /mode
			channel = args[1]
			table.remove(args, 1)
			if channel\sub(1,1) == "#"
				Logger.print patterns.MODE\format channel, table.concat(args, " "), prefix\match('^(.-)!') or prefix
		['KICK']: (prefix, args, trailing)=>
			channel = args[1]
			nick = args[2]
			kicker = prefix\match('^(.-)!') or prefix
			if trailing
				Logger.print patterns.KICK_2\format channel, kicker, nick, trailing
			else
				Logger.print patterns.KICK\format channel, kicker, nick
		['PART']: (prefix, args, trailing)=>
			-- User or bot parted channel, clear from lists
			channel = args[1]
			nick = prefix\match('^(.-)!') or prefix
			if trailing
				Logger.print patterns.PART_2\format channel, nick, trailing
			else
				Logger.print patterns.PART\format channel, nick
		['QUIT']: (prefix, args, trailing)=>
			-- User or bot parted network, nuke from lists
			nick = prefix\match('^(.-)!') or prefix
			if trailing
				Logger.print patterns.QUIT_2\format nick, trailing
			else
				Logger.print patterns.QUIT\format nick
		['PRIVMSG']: (prefix, args, trailing)=>
			nick = prefix\match('^(.-)!') or prefix
			if not args[1]\sub(1, 1) == '#'
				if trailing\match "^\001ACTION .-\001$"
					Logger.print patterns.ACTION_2\format nick, trailing\match('^%S+%s+(.+)')
				elseif not trailing\match '^\001'
					Logger.print patterns.PRIVMSG_2\format nick, trailing
			else
				ch = args[1]
				if trailing\match "^\001ACTION .-\001$"
					Logger.print patterns.ACTION\format ch, nick, trailing\match('^%S+%s+(.+)')
				elseif not trailing\match '^\001'
					Logger.print patterns.PRIVMSG\format ch, nick, trailing
		['NOTICE']: (prefix, args, trailing)=>
			return if trailing\sub(1, 1) == '\001' -- CTCP
			nick = prefix\match('^(.-)!') or prefix
			if args[1]\sub(1, 1) == '#'
				Logger.print patterns.NOTICE\format args[1], nick, trailing
			else
				Logger.print patterns.NOTICE_2\format nick, trailing
		['INVITE']: (prefix, args, trailing)=>
			nick = prefix\match('^(.-)!') or prefix
			Logger.print patterns.INVITE\format args[2], nick, args[1]
		['CAP']: (prefix, args, trailing)=>
			caps = {'echo-message', 'invite-notify'}
			for cap in *caps
				if args[2] == 'LS'
					for item in trailing\gmatch '%S+'
						if item == cap
							@send_raw 'CAP REQ ' .. item
							@fire_hook 'REQ_CAP'
				elseif args[2] == 'ACK' or args[2] == 'NAK'
					local has_cap
					for item in trailing\gmatch '%S+'
						if item == cap
							has_cap = true
					@server.ircv3_caps[cap] = true if has_cap and args[2] == 'ACK'
					@fire_hook 'ACK_CAP' if has_cap
}
