--- IRC client class
-- @classmod IRCClient

socket = require 'cqueues.socket'
Logger = require 'logger'

escapers =  {['s']: ' ', ['r']: '\r', ['n']: '\n', [';']: ';'}

local IRCClient, ContextTable

class ContextTable
	-- ::TODO:: allow for multiple *and* index
	get: (name, opts = {})=>
		:multiple, :index = opts
		multiple = true if multiple == nil

		local output
		output = {} if multiple
		for context, items in pairs(self)
			-- context
			unless multiple
				-- return the singular if it exists
				return items[name] if items[name] ~= nil
			elseif items[name]
				-- add all that exist
				for element in *items[name]
					table.insert output, element

		if multiple
			output
		elseif index
			index\get name, :multiple

class IRCClient
	commands: ContextTable!
	hooks: ContextTable!
	handlers: ContextTable!
	senders: ContextTable!

	default_config = {
		prefix: "!"
	}

	--- Generate a new IRCClient
	-- @tparam string server IRC server name
	-- @tparam number port IRC port number
	-- @tparam table config Default configuration
	new: (server, port=6697, config)=>
		assert(server)
		@config = :server, :port, :config, ssl: port == 6697
		for k, v in pairs(default_config)
			@config[k] = v
		if config
			for k, v in pairs(config)
				@config[k] = v

		@commands = ContextTable!
		@hooks    = ContextTable!
		@handlers = ContextTable!
		@senders  = ContextTable!
		@server   = {}

	unpack = unpack or table.unpack

	handle_options = (options, fn)->
		unless fn
			fn = options
			options = {}

		if options.async
			return (...)->
				args = {...}
				require("queue")\wrap ->
					fn(unpack(args))

		fn

	assert_context = ()=> assert @context, "Missing context"

	--- Change the module context for the current command
	-- @tparam string context module context (typically, the name)
	-- @tparam function fn code to run under context
	with_context: (context, fn)=>
		assert @context == nil, "Already in context: #{@context}"
		@context = context

		for key in *{"hooks", "handlers", "commands", "senders"}
			self[key][context] = {}

		fn self, context
		@context = nil

	--- Add an IRC bot command
	-- @tparam string name Bot command name
	-- @tparam table options [Optional] async: bool, wraps in cqueues
	-- @tparam function command Function for handling command
	add_command: (name, options, command)=>
		context = assert_context self
		@commands[context][name] = handle_options(options, command)

	--- Add a client processing hook
	-- @tparam string name Name of event to hook into
	-- @tparam table options [Optional] async: bool, wraps in cqueues
	-- @tparam function hook Processor for hook event
	add_hook: (name, options, hook)=>
		context = assert_context self

		hooks = @hooks[context]

		if not hooks[name]
			hooks[name] = {handle_options(options, hook)}
		else
			table.insert hooks[name], handle_options(options, hook)

	--- Add an IRC command handler
	-- @tparam string id IRC command ID (numerics MUST be strings)
	-- @tparam table options [Optional] async: bool, wraps in cqueues
	-- @tparam function handler IRC command processor
	add_handler: (id, options, handler)=>
		context = assert_context self

		handlers = @handlers[context]

		unless handlers[id]
			handlers[id] = {handle_options(options, handler)}
		else
			table.insert handlers[id], handle_options(options, handler)

	--- Add an IRC command sending handler
	-- @tparam string id IRC command ID ("PRIVMSG", "JOIN", etc.)
	-- @tparam table options [Optional] async: bool, wraps in cqueues
	-- @tparam function sender Function to handle message to be sent
	add_sender: (id, options, sender)=>
		context = assert_context self
		@senders[context][id] = handle_options(options, sender)

	--- Reset all modules in the IRCClient
	clear_modules: ()=>
		@senders = {}
		@handlers = {}
		@hooks = {}
		@commands = {}

	--- Connect to the IRC server specified in the configuration
	connect: ()=>
		if @socket
			Logger.debug "Shutting down socket: #{tostring(@socket)}"
			@socket\shutdown!
		host = @config.server
		port = @config.port
		ssl  = @config.ssl
		debug_msg = ('Connecting... {host: "%s", port: "%s"}')\format host, port

		@config.nick = 'Moon-Moon' if not @config.nick
		@config.username = 'Mooooon' if not @config.username
		@config.realname = 'Moon Moon: MoonScript IRC Bot' if not @config.realname

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

	--- Disconnect from the current IRC server
	disconnect: ()=>
		@socket\shutdown! if @socket
		@fire_hook 'DISCONNECT'

	--- Send a raw line to the currently connected IRC server
	-- @param ... List of strings, concatenated using spaces
	send_raw: (...)=>
		@socket\write table.concat({...}, ' ') .. '\n'
		Logger.debug '==> ' .. table.concat {...}, ' '

	--- Send a command using a builtin sender configured with @add_sender
	-- @tparam string name Name of sender to use
	-- @param ... List of arguments to be passed to sender
	-- @see IRCClient\add_sender
	send: (name, ...)=>
		sender = @senders\get name, multiple: false, index: IRCClient.senders
		@send_raw sender(self, ...)

	date_pattern: "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+).(%d+)Z"

	--- Parse the time of an ISO 8601 compliant string
	-- @tparam string date ISO 8601 compliant YYYY-MM-DDThh:mm:ssZ date
	-- @treturn number Seconds from Epoch from configured date
	parse_time: (date)=>
		year, month, day, hour, min, sec, mil = date\match @date_pattern
		return os.time(:year, :month, :day, :hour, :min, :sec) + tonumber(mil) / 1000

	--- Grab tags from an IRCv3 message
	-- @tparam string tag_message Message containing IRCv3 tags
	-- @treturn table Table containing tags, client tags preceded with a "+"
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

	--- Parse an IRCv3 compatible wire-format string
	-- @tparam string message_with_tags IRCv3 compliant wire-format command
	-- @treturn table User prefix, if sent by a user or server
	-- @treturn string Command sent to client
	-- @treturn table List of arguments, trailing argument not included
	-- @treturn string Trailing possibly space-inclusive message
	-- @treturn table IRCv3 compatible tag list
	-- @see IRCClient\parse_tags
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

	--- Activate hooks configured for the event name
	-- @tparam string hook_name Name of event to "fire"
	-- @treturn boolean True if no errors were encountered, false otherwise
	-- @treturn table Table containing list of errors from hooks
	fire_hook: (hook_name, ...)=>
		Logger.debug "#{Logger.level.warn}--- Running hooks for #{hook_name}"
		has_run = false
		has_errors = false
		errors = {}

		for _, hook in pairs IRCClient.hooks\get hook_name
			has_run = true unless has_run
			Logger.debug Logger.level.warn .. '--- Running global hook: ' .. hook_name
			ok, err = pcall hook, @, ...
			if not ok
				has_errors = true if not has_errors
				table.insert(errors, err)
				Logger.print Logger.level.error .. '*** ' .. err
		for _, hook in pairs @hooks\get hook_name
			has_run = true unless has_run
			Logger.debug Logger.level.warn .. '--- Running hook: ' .. hook_name
			ok, err = pcall hook, @, ...
			if not ok
				has_errors = true if not has_errors
				table.insert(errors, err)
				Logger.print Logger.level.error .. '*** ' .. err

		Logger.debug Logger.level.error .. "*** Handler not found for #{command}" unless has_run

		return has_errors, errors

	--- Run handlers for an unparsed command
	-- @tparam string line Incoming wire-string formatted line from IRC server
	process: (line)=>
		prefix, command, args, rest, tags = @parse line
		Logger.debug Logger.level.warn .. '--- | Line: ' .. line
		Logger.debug Logger.level.okay .. '--- |\\ Running trigger: ' .. Logger.level.warn .. command
		if prefix
			Logger.debug Logger.level.okay .. '--- |\\ Prefix: ' .. prefix
		if #args > 0
			Logger.debug Logger.level.okay .. '--- |\\ Arguments: ' .. table.concat(args, ', ')
		if rest
			Logger.debug Logger.level.okay .. '--- |\\ Trailing: ' .. rest

		has_run = false

		for handler in *IRCClient.handlers\get command
			has_run = true unless has_run
			ok, err, tb = xpcall handler, self\log_traceback, self,
				prefix, args, rest, tags
			if not ok
				@log tb
				@log Logger.level.error .. '*** ' .. err

		for handler in *@handlers\get command
			has_run = true unless has_run
			ok, err = xpcall handler, (()-> @log_traceback!), @,
				prefix, args, rest, tags
			if not ok
				Logger.print Logger.level.error .. '*** ' .. err

		Logger.debug Logger.level.error .. "*** Handler not found for #{command}" unless has_run

	--- Iterate over lines from a server and handle errors appropriately
	loop: ()=>
		local line
		print_error = (err)->
			Logger.debug "Error: " .. err .. " (" .. line .. ")"

		for received_line in @socket\lines! do
			line = received_line
			xpcall @process, print_error, @, received_line

	--- Print a traceback using the internal logging mechanism
	-- @see IRCClient\log
	log_traceback: (err)=>
		@log Logger.level.error .. '*** ' .. err
		@log debug.traceback()
		@log Logger.level.error .. '---'

	--- Log message from IRC server (used in plugins)
	-- @tparam string input Line to print, IRC color formatted
	-- @see logger
	log: (input)=>
		for line in input\gmatch "[^\r\n]+"
			Logger.print '\00311(\003' .. (@server.caps and
				@server.caps['NETWORK'] or @config.server) ..
				"\00311)\003 #{line}"

return {:IRCClient}
