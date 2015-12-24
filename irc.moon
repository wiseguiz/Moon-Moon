cqueues = require 'cqueues'
socket  = require 'socket'

export IRCConnection

class IRCConnection
	new: (server, port=6667, config)=>
		assert(server)
		@config = :server, :port, :config
		for k, v in pairs(config)
			@config[k] = v

		@plugins  = {}
		@senders  = {}
		@handlers = {}

	connect: ()=>
		if @socket
			@socket\shutdown!
		host = @config.server
		port = @config.port
		@socket = assert socket.connect{:host, :port}
		if @config.ssl
			@socket\starttls!

	send: (...)=>
		@socket\send(...)

	parse: (line)=>
		prefix_end = 0
		prefix = nil
		if message\sub(1, 1) == ":"
			 prefix_end = message\find " "
			 prefix = message\sub 2, message\find(" ") - 1

		trailing = nil
		tstart = message\find ":"
		if tstart
			trailing = message\sub tstart + 2
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

		for name, handler in pairs @handlers
			pcall handler, @, prefix, command, args, rest

		for name, plugin in pairs @plugins
			ok, err = coroutine.resume(plugin)
			if coroutine.status(plugin) == "dead" then
				@plugins[command][name] = nil
