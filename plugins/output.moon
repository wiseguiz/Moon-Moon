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
	NETJOIN: "\00308[\003%s\00308]\003 \00309>\003 (%s)"
	NETSPLIT: "\00304<\003 (%s)"
}

serve_self ==> setmetatable(@, {__call: ()=>pairs(@)})

{
	hooks:
		['CONNECT']: =>
			@batches = {
				netjoin:  {}
				netsplit: {}
			}

		['NETJOIN']: =>
			channels = {}
			for user in *batches.netjoin
				channel, prefix = next user
				channels[channel] = {} if not channels[channel]
				table.insert channels[channel], prefix\match('^(.-)!') or prefix
			for channel, channel_user_list in pairs channels
				Logger.log patterns.NETJOIN\format channel, table.concat(channel_user_list, ', ')
		['NETSPLIT']: =>
			Logger.log patterns.NETSPLIT\format table.concat(batches.netsplit, ', ')
	handlers:
		['JOIN']: (prefix, args, trail, tags={})=>
			-- user JOINs a channel
			channel = args[1] or trail
			if not tags.batch then
				Logger.print patterns.JOIN\format channel, prefix\match('^(.-)!') or prefix
			else
				for name, batch in *@server.batches
					if name == tags.batch and batch[1] == 'netjoin'
						if #@server.batches[name].gc > 0
							table.insert @server.batches[batch].gc, ->
								@fire_hook 'NETJOIN'
								batches.netjoin = {}
						batches.netjoin[#batches.netjoin + 1] = {[channel]: prefix}
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
		['QUIT']: (prefix, args, trailing, tags = {})=>
			-- User or bot parted network, nuke from lists
			nick = prefix\match('^(.-)!') or prefix
			if tags.batch
				for name, batch in pairs @server.batches
					if name == tags.batch and tags.batch[1] == 'netsplit'
						if #@server.batches[name].gc > 0
							table.insert @server.batches[batch].gc, ->
								@fire_hook 'NETSPLIT'
								batches.netsplit = {}
						batches.netsplit[#batches.netsplit + 1] = nick
				
			else
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
			channel = args[2]
			Logger.print patterns.INVITE\format channel, nick, args[1]
}
