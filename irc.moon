socket = require 'cqueues.socket'
Logger = require 'logger'

class IRCConnection
	new: (server, port=6667, config={})=>
		assert(server)
		@config = :server, :port, :config
		for k, v in pairs(config)
			@config[k] = v

		@handlers = {}
		@senders  = {}
		@server   = {}
	
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
				@\add_sender id, sender
		if modules.handlers
			for id, handler in pairs modules.handlers
				@\add_handler id, handler

	connect: ()=>
		if @socket
			@socket\shutdown!
		host = @config.server
		port = @config.port
		debug_msg = ('Connecting... {host: "%s", port: "%s"}')\format host, port
		Logger.debug debug_msg, Logger.level.warn .. '--- Connecting...'
		@socket = assert socket.connect{:host, :port}
		Logger.print Logger.level.okay .. '--- Connected'
		if @config.ssl
			Logger.debug 'Starting TLS exchange...'
			@socket\starttls!
			Logger.debug 'Started TLS exchange'
		nick = @config.nick or 'Moonmoon'
		user = @config.username or 'moon'
		real = @config.realname or 'Moon Moon: MoonScript IRC Bot'
		@\send_raw ('NICK %s')\format nick
		@\send_raw ('USER %s * * :%s')\format user, real
		debug_msg = ('Sent authentication data: {nickname: %s, username: %s, realname: %s}')\format nick, user, real
		Logger.debug debug_msg, Logger.level.okay .. '--- Sent authentication data'

	send_raw: (...)=>
		@socket\write table.concat({...}, ' ') .. '\n'

	send: (name, pattern, ...)=>
		@senders[name] pattern\format ...

	parse: (message)=>
		prefix_end = 0
		prefix = nil
		if message\sub(1, 1) == ":"
			prefix_end = message\find " "
			prefix = message\sub 2, message\find(" ") - 1

		trailing = nil
		tstart = message\find " :"
		if tstart
			trailing = message\sub tstart + 1
		else
			tstart = #message

		rest = ((segment)->
			t = {}
			for word in segment\gmatch "%S+"
				table.insert t, word

			return t
		)(message\sub prefix_end + 1, tstart)

		command = rest[1]
		table.remove(rest, 1)
		return prefix, command, rest, trailing

	process: (line)=>
		prefix, command, args, rest = @\parse line
		if not @handlers[command]
			return
		Logger.debug Logger.level.okay .. ' --- | Running trigger: ' .. Logger.level.warn .. command
		Logger.debug Logger.level.okay .. ' --- |\\ Line: ' .. line
		if prefix
			Logger.debug Logger.level.okay .. ' --- |\\ Prefix: ' .. prefix
		if #args > 0
			Logger.debug Logger.level.okay .. ' --- |\\ Arguments: ' .. table.concat(args, ', ')
		if rest
			Logger.debug Logger.level.okay .. ' ---  \\ Trailing: ' .. rest
		for _, handler in pairs @handlers[command]
			ok, err = pcall handler, @, prefix, args, rest
			if not ok
				Logger.debug Logger.level.warn .. ' *** ' .. err
	
	loop: ()=>
		local line
		print_error =(err)->
			Logger.debug "Error: " .. err .. " (" .. line .. ")"

		for received_line in @socket\lines! do
			line = received_line
			xpcall @process, print_error, @, received_line

return IRCConnection
