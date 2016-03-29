socket = require 'cqueues.socket'
Logger = require 'logger'

escapers =  {['s']: ' ', ['r']: '\r', ['n']: '\n', [';']: ';'}

class IRCClient
	msg: (channel, message)=>
		@sendf "PRIVMSG %s :%s", channel, message
	
	part: (channel, message="Leaving")=>
		@sendf "PART %s :%s", channel, message

	join: (channel)=>
		@sendf "JOIN %s", message
	
	quit: (message)=>
		@sendf "QUIT :%s", message

	nick: (new_nick)=>
		@sendf "NICK %s", new_nick

class IRCConnection extends IRCClient
	new: (server, port=6697, config={})=>
		assert(server)
		@config = :server, :port, :config, ssl: port == 6697
		for k, v in pairs(config)
			@config[k] = v

		@handlers = {}
		@senders  = {}
		@server   = {}
		@hooks    = {}

	add_hook: (id, hook)=>
		if not @hooks[id]
			@hooks[id] = {hook}
		else
			table.insert @hooks[id], hook
	
	add_handler: (id, handler)=>
		if not @handlers[id]
			@handlers[id] = {handler}
		else
			table.insert @handlers[id], handler
	
	add_sender: (id, sender)=>
		assert not @senders[id], "Sender already exists: " .. id
		@senders[id] = sender
	
	load_modules: (modules)=>
		if modules.senders
			for id, sender in pairs modules.senders
				@add_sender id, sender
		if modules.handlers
			for id, handler in pairs modules.handlers
				@add_handler id, handler
		if modules.hooks
			for id, hook in pairs modules.hooks
				@add_hook id, hook

	connect: ()=>
		if @socket
			@socket\shutdown!
		host = @config.server
		port = @config.port
		ssl  = @config.ssl
		debug_msg = ('Connecting... {host: "%s", port: "%s"}')\format host, port
		---
		@config.nick = 'Moon-Moon' if not @config.nick
		@config.username = 'Mooooon' if not @config.username
		@config.realname = 'Moon Moon: MoonScript IRC Bot' if not @config.realname
		---
		Logger.debug debug_msg, Logger.level.warn .. '--- Connecting...'
		@socket = assert socket.connect{:host, :port}
		if ssl
			Logger.debug 'Starting TLS exchange...'
			@socket\starttls!
			Logger.debug 'Started TLS exchange'
		Logger.print Logger.level.okay .. '--- Connected'
		@fire_hook 'CONNECT'
		nick = @config.nick
		user = @config.username
		real = @config.realname
		pass = @config.password
		Logger.print Logger.level.warn .. '--- Sending authentication data'
		@send_raw ('NICK %s')\format nick
		if pass and ssl
			Logger.debug '*** Sending password'
			@send_raw ('PASS :%s')\format pass
		elseif pass
			Logger.print Logger.level.error .. '*** Not sending password: TLS not enabled ***'
		@send_raw ('USER %s * * :%s')\format user, real
		debug_msg = ('Sent authentication data: {nickname: %s, username: %s, realname: %s}')\format nick, user, real
		Logger.debug debug_msg, Logger.level.okay .. '--- Sent authentication data'

	disconnect: ()=>
		@socket\shutdown! if @socket
		@fire_hook 'DISCONNECT'

	send_raw: (...)=>
		@socket\write table.concat({...}, ' ') .. '\n'
		Logger.debug '==> ' .. table.concat {...}, ' '
	
	sendf: (fmtstr, ...)=>
		@send_raw fmtstr\format ...

	date_pattern: "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+).(%d+)Z"

	parse_time: (datestring)=>
		year, month, day, hour, min, sec, mil = datestring\match @date_pattern
		return os.time(:year, :month, :day, :hour, :min, :sec) + tonumber(mil) / 1000

	parse_tags: (tag_message)=>
		local cur_name
		tags = {}
		charbuf = {}
		pos = 1
		while pos < #tag_message do
			if tag_message\match '^\\', pos
				lookahead = tag_message\sub pos+1, pos+1
				charbuf[#charbuf + 1] = escapers[lookahead] or lookahead
				pos += 2
			elseif cur_name
				if tag_message\match "^;", pos
					tags[cur_name] = table.concat charbuf
					cur_name = nil
					charbuf = {}
					pos += 1
				else
					charbuf[#charbuf + 1], pos = tag_message\match "([^\\;]+)()", pos
			else
				if tag_message\match "^=", pos
					if #charbuf > 0
						cur_name = table.concat charbuf
						charbuf = {}
					pos += 1
				elseif tag_message\match "^;", pos
					if #charbuf > 0
						tags[table.concat charbuf] = true
						charbuf = {}
					pos += 1
				else
					charbuf[#charbuf + 1], pos = tag_message\match "([^\\=;]+)()", pos
		return tags

	parse: (message_with_tags)=>
		local message, tags
		if message_with_tags\sub(1, 1) == '@'
			tags = @parse_tags message_with_tags\sub 2, message_with_tags\find(' ') - 1
			message = message_with_tags\sub((message_with_tags\find(' ') + 1))
		else
			message = message_with_tags
		prefix_end = 0
		prefix = nil
		if message\sub(1, 1) == ':'
			prefix_end = message\find ' '
			prefix = message\sub 2, message\find(' ') - 1

		trailing = nil
		tstart = message\find ' :'
		if tstart
			trailing = message\sub tstart + 2
		else
			tstart = #message

		rest = ((segment)->
			t = {}
			for word in segment\gmatch '%S+'
				table.insert t, word

			return t
		)(message\sub prefix_end + 1, tstart)

		command = rest[1]
		table.remove(rest, 1)
		return prefix, command, rest, trailing, tags

	fire_hook: (hook_name)=>
		if not @hooks[hook_name]
			return false
		for _, hook in pairs @hooks[hook_name]
			Logger.debug Logger.level.warn .. '--- Running hook: ' .. hook_name
			ok, err = pcall hook, @
			if not ok
				Logger.print Logger.level.error .. '*** ' .. err
		return true -- because it did fire off hooks

	process: (line)=>
		prefix, command, args, rest, tags = @parse line
		Logger.debug Logger.level.warn .. '--- | Line: ' .. line
		if not @handlers[command]
			return
		Logger.debug Logger.level.okay .. '--- |\\ Running trigger: ' .. Logger.level.warn .. command
		if prefix
			Logger.debug Logger.level.okay .. '--- |\\ Prefix: ' .. prefix
		if #args > 0
			Logger.debug Logger.level.okay .. '--- |\\ Arguments: ' .. table.concat(args, ', ')
		if rest
			Logger.debug Logger.level.okay .. '--- |\\ Trailing: ' .. rest
		for _, handler in pairs @handlers[command]
			ok, err = pcall handler, @, prefix, args, rest, tags
			if not ok
				Logger.print Logger.level.error .. '*** ' .. err
	
	loop: ()=>
		local line
		print_error =(err)->
			Logger.debug "Error: " .. err .. " (" .. line .. ")"

		for received_line in @socket\lines! do
			line = received_line
			xpcall @process, print_error, @, received_line

return IRCConnection
