socket  = require 'cqueues.socket'

export IRCConnection, Logger

serve_self ==> setmetatable(@, {__call: ()=>pairs(@)})

class IRCConnection
	new: (server, port=6667, config={})=>
		assert(server)
		@config = :server, :port, :config
		for k, v in pairs(config)
			@config[k] = v

		@channels = serve_self({})
		@users    = serve_self({})

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
		@socket = assert socket.connect{:host, :port}
		if @config.ssl
			@socket\starttls!

	send_raw: (...)=>
		@socket\send(...)

	send: (name, pattern, ...)=>
		@senders[name] pattern\format ...

	parse: (message)=>
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
	
colors = {
	[0]: 15, -- white
	0,  -- black
	4,  -- blue
	2,  -- green
	1,  -- red
	3,  -- brown
	5,  -- purple
	3,  -- orange
	11, -- yellow
	10, -- light green
	6,  -- teal
	14, -- cyan
	12, -- light blue
	13, -- pink
	8,  -- gray
	7  -- light gray
}
class Logger
	print_bare: (line)->
		print(line\gsub('\003(%d%d?),(%d%d?)', (fg, bg)->
			fg, bg = tonumber(fg), tonumber(bg)
			if colors[fg] and colors[bg]
				return '\27[38;5;' .. colors[fg] .. ';48;5;' .. colors[bg] .. 'm'
		)\gsub('\003(%d%d?)', (fg)->
			fg = tonumber(fg)
			if colors[fg]
				return '\27[38;5;' .. colors[fg] .. 'm'
		)\gsub('\003', ()->
			return '\27[0m'
		) .. '\27[0m')
	log: (line, color)->
		if color == false
			Logger.print_bare os.date('[%X] ' .. line)
		else
			Logger.print_bare os.date('[%X]')\gsub('.', (ch)->
				if ch\match '[%[%]:]'
					return '\00311' .. ch .. '\003'
				else
					return '\00315' .. ch .. '\003'
			) .. ' ' .. line
