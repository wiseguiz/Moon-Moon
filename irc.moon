--- IRC client class
-- @classmod IRCClient

re = require "re"
socket = require 'cqueues.socket'
Logger = require 'logger'

moonscript = {
	errors: require 'moonscript.errors'
}

escapers =  {['s']: ' ', ['r']: '\r', ['n']: '\n', [';']: ';'}

local IRCClient, ContextTable, priority

priority = {
	HIGH: 1,
	DEFAULT: 2,
	LOW: 3,
}

class ContextTable
	-- ::TODO:: allow for multiple *and* index
	get: (name, opts = {})=>
		:multiple, :index, :uses_priority = opts
		multiple = true if multiple == nil
		uses_priority = true if uses_priority == nil

		local output
		output = {} if multiple
		for context, items in pairs(self)
			-- context
			if multiple
				-- add all that exist
				if uses_priority
					for p=priority.HIGH, priority.LOW
						if items[p][name]
							for element in *items[p][name]
								table.insert output, element
				else
					if items[name]
						for element in *items[name]
							table.insert output, element
			else
				-- return the singular if it exists
				if uses_priority
					for p=priority.HIGH, priority.LOW
						return items[p][name] if items[p][name] ~= nil
				else
					return items[name] if items[name] ~= nil

		if multiple
			output
		elseif index
			index\get name, :multiple, :uses_priority

	remove: (name)=>
		for context_name, tbl in pairs(self)
			tbl[name] = nil


class IRCClient
	commands: ContextTable!
	hooks: ContextTable!
	handlers: ContextTable!
	senders: ContextTable!

	__tostring: => "IRCClient"

	default_config = {
		prefix: "!"
	}

	line_pattern = re.compile [[
		-- tags, command, args
		line <- {|
			{:tags: {| (tags sp)? |} :}
			{:prefix: {| (prefix sp)? |} :}
			{:command: (command / numeric) :}
			{:args: {| (sp arg)* |} :} |}
		tags <- '@' tag (';' tag)*
		tag <- {|
			{:is_client: {'+'} :}? -- check: if tag.is_client
			{:vendor: {[^/]+} '/' :}?
			{:key: {[^=; ]+} -> esc_tag :}
			{:value: ('=' {[^; ]+} -> esc_tag) :}?
		|}
		prefix <- ':' (
			{:nick: {[^ !]+} :} '!'
			{:user: {[^ @]+} :} '@'
			{:host: {[^ ]+} :} /
			{:nick: {[^ ]+} :})
		command <- [A-Za-z]+
		numeric <- %d^+3^-4 -- at most four digits, at least three
		arg <- ':' {.+} / {%S+}
		sp <- %s
	]], esc_tag: (tag)-> tag\gsub "\\(.)", setmetatable({
		[":"]: ";"
		s: " "
		r: "\r"
		n: "\n"
	}, __index: (t, k) -> k)

	--- Get a tag based on search parameters (is_client IS NOT matched by key)
	-- @tparam table tags Tag from IRC parser
	-- @tparam table opts Options to search for (is_client: bool, key: string)
	get_tag: (tags, opts)=>
		:is_client, :key = opts
		for tag in *tags
			continue if is_client ~= nil and tag.is_client ~= is_client
			if key ~= nil
				continue if tag.vendor ~= nil and key ~= "#{tag.vendor}/#{tag.key}"
				continue if tag.vendor == nil and key ~= tag.key
			return tag

		return {}


	--- Generate a new IRCClient
	-- @tparam string server IRC server name
	-- @tparam number port IRC port number
	-- @tparam table config Default configuration
	new: (server, port=6697, config)=>
		assert server
		@config = :server, :port, :config, ssl: port == 6697
		for k, v in pairs default_config
			@config[k] = v
		if config
			for k, v in pairs config
				@config[k] = v

		@commands = ContextTable!
		@hooks    = ContextTable!
		@handlers = ContextTable!
		@senders  = ContextTable!
		@server   = {}

	unpack = unpack or table.unpack

	get_priority = (options, fn)->
		return fn and options.priority or priority.DEFAULT

	handle_options: (options, fn)=>
		unless fn
			fn = options
			options = {}

		if options.async
			return (...)->
				args = {...}
				require("queue")\wrap ->
					@pcall_bare fn, unpack args

		if options.wrap_iter
			tmp_fn = coroutine.wrap fn
			tmp_fn!
			return tmp_fn

		fn

	assert_context: (context_table)=>
		assert @context, "Missing @with_context"
		return context_table[assert @context, "Missing @with_context"]

	--- Change the module context for the current command
	-- @tparam string context module context (typically, the name)
	-- @tparam function fn code to run under context
	with_context: (context, fn)=>
		assert @context == nil, "Already in context: #{@context}"
		@context = context

		self["senders"][context] = {} -- no priority for senders, only one
		for key in *{"hooks", "handlers", "commands"}
			self[key][context] = [{} for p=priority.HIGH, priority.LOW]

		fn self, context
		@context = nil

	--- Add an IRC bot command
	-- @tparam string name Bot command name
	-- @tparam table options [Optional] async: bool, wraps in cqueues
	-- @tparam function command Function for handling command
	add_command: (name, options, command)=>
		final_command = command
		commands = @assert_context @commands

		-- `options` is passed, which fills in `command`
		if command
			-- is async, send typing until completed
			if options.async
				-- async, send @+draft/typing 
				final_command = (prefix, target, line, ...)=>
					@send 'TAGMSG', target, "+draft/typing": "active"
					@pcall command, prefix, target, line, ...
					@send 'TAGMSG', target, "+draft/typing": "done"

		p = get_priority options, final_command
		commands[p][name] = @handle_options options, final_command

	--- Add a client processing hook
	-- @tparam string name Name of event to hook into
	-- @tparam table options [Optional] async: bool, wraps in cqueues
	-- @tparam function hook Processor for hook event
	add_hook: (name, options, hook)=>
		hooks = @assert_context @hooks

		p = get_priority options, hook

		unless hooks[p][name]
			hooks[p][name] = {@handle_options options, hook}
		else
			table.insert hooks[p][name], @handle_options(options, hook)

	--- Add an IRC command handler
	-- @tparam string id IRC command ID (numerics MUST be strings)
	-- @tparam table options [Optional] async: bool, wraps in cqueues
	-- @tparam function handler IRC command processor
	add_handler: (id, options, handler)=>
		handlers = @assert_context @handlers

		p = get_priority options, handler

		unless handlers[p][id]
			handlers[p][id] = {@handle_options options, handler}
		else
			table.insert hooks[p][name], @handle_options(options, handler)

	--- Add an IRC command sending handler, does NOT take a priority
	-- @tparam string id IRC command ID ("PRIVMSG", "JOIN", etc.)
	-- @tparam table options [Optional] async: bool, wraps in cqueues
	-- @tparam function sender Function to handle message to be sent
	add_sender: (id, options, sender)=>
		senders = @assert_context @senders
		senders[id] = @handle_options(options, sender)

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
		@send_raw 'NICK', nick
		if pass and ssl
			Logger.debug '*** Sending password'
			@send_raw 'PASS', pass
		elseif pass
			Logger.print Logger.level.error .. '*** Not sending password: TLS not enabled ***'
		@send_raw 'USER', user, '*', '*', real
		debug_msg = ('Sent authentication data: {nickname: %s, username: %s, realname: %s}')\format nick, user, real
		Logger.debug debug_msg, Logger.level.okay .. '--- Sent authentication data'

	--- Disconnect from the current IRC server
	disconnect: ()=>
		@socket\shutdown! if @socket
		@fire_hook 'DISCONNECT'

	tag_escapes = {
		";": ":"
		" ": "s"
		"\r": "r"
		"\n": "n"
	}

	--- Serialize a value for being sent in a tag
	serialize_tag_string = (key, value)->
		return key if type(value) == "boolean"
		return key .. "=" .. value\gsub "([: \r\n])", (value)-> "\\#{tbl[value]}"

	--- Serialize client->client tags for sending to the server
	-- @param tags Table of tags to serialize
	serialize_tags = (tags)->
		output = [serialize_tag_string(k, v) for k, v in pairs tags]
		return "@#{table.concat output, ';'}"

	--- Send a raw line to the currently connected IRC server
	-- @param ... List of strings, concatenated using spaces
	send_raw: (...)=>
		output = {...}
		arg_count = select("#", ...)
		opts_table = select(arg_count, ...)
		if type(opts_table) == "table"
			-- we have tags, server accepts tags
			if opts_table.tags and next(opts_table.tags) and @server.ircv3_caps["message-tags"]
				table.insert output, 1, serialize_tags opts_table.tags
			-- remove opts_table regardless of caps
			table.remove output, #output
		arg_count = #output
		if output[arg_count]\find " "
			output[arg_count] = ":#{output[arg_count]}"
		@socket\write table.concat(output, ' ') .. '\n'
		Logger.debug '==> ' .. table.concat output, ' '

	--- Send a command using a builtin sender configured with @add_sender
	-- @tparam string name Name of sender to use
	-- @param ... List of arguments to be passed to sender
	-- @see IRCClient\add_sender
	send: (name, ...)=>
		sender = @senders\get name, multiple: false, index: IRCClient.senders, uses_priority: false
		input = sender self, ...
		@socket\write input if input

	date_pattern: "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+).(%d+)Z"

	--- Parse the time of an ISO 8601 compliant string
	-- @tparam string date ISO 8601 compliant YYYY-MM-DDThh:mm:ssZ date
	-- @treturn number Seconds from Epoch from configured date
	parse_time: (date)=>
		year, month, day, hour, min, sec, mil = date\match @date_pattern
		return os.time(:year, :month, :day, :hour, :min, :sec) + tonumber(mil) / 1000

	--- parse an IRC command using line_pattern
	parse: (line)=> line_pattern\match line

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
			ok, err = @pcall hook, ...
			if not ok
				has_errors = true if not has_errors
				table.insert(errors, err)
		for _, hook in pairs @hooks\get hook_name
			has_run = true unless has_run
			Logger.debug Logger.level.warn .. '--- Running hook: ' .. hook_name
			ok, err = @pcall hook, ...
			if not ok
				has_errors = true if not has_errors
				table.insert(errors, err)

		Logger.debug Logger.level.error .. "*** Hook not found for #{command}" unless has_run

		return has_errors, errors, has_run

	process_line: (line, opts={})=>
		{:tags, :prefix, :command, :args} = @parse line
		opts.line = line
		@process prefix, command, args, tags, opts

	--- Run handlers for an unparsed command
	-- @tparam table prefix Prefix argument from server (nick, user, host)
	-- @tparam table args Argument list from server, including trailing
	-- @tparam table tags Tags list from server
	-- @tparam table opts Optional arguments, in_batch: IRCv3 batching
	process: (prefix, command, args, tags, opts={})=>
		{:in_batch} = opts
		{:nick, :user, :host} = prefix
		if opts.line
			Logger.debug Logger.level.warn .. '--- | Line: ' .. opts.line
			Logger.debug Logger.level.okay .. '--- |\\ Running trigger: ' .. Logger.level.warn .. command
			if nick and user and host
				Logger.debug "#{Logger.level.okay}--- |\\ User: #{nick}!#{user}@#{host}"
			elseif nick
				Logger.debug "#{Logger.level.okay}--- |\\ Nick: #{nick}"
			if #args > 0
				Logger.debug "#{Logger.level.okay}--- |\\ Arguments: #{table.concat args, ' '}"

		has_run = false

		if not in_batch and tags.batch
			-- will return _, _, true if a hook run; this is necessary because
			-- the protocol might send batches even if we don't support them.
			return unless select(2, @fire_hook "BATCH.#{tags.batch}", prefix,
				args, tags, opts)

		for handler in *IRCClient.handlers\get command
			has_run = true unless has_run
			@pcall handler, prefix, args, tags, opts

		for handler in *@handlers\get command
			has_run = true unless has_run
			@pcall handler, prefix, args, tags, opts

		Logger.debug Logger.level.error .. "*** Handler not found for #{command}" unless has_run

	--- Iterate over lines from a server and handle errors appropriately
	loop: ()=>
		for received_line in @socket\lines! do
			@pcall @process_line, received_line, in_batch: false

	--- Call a function and, when failed, print debug information
	-- @tparam function fn Function to be called
	-- @param ... vararg list to pass to function
	pcall: (fn, ...)=>
		ok, err = xpcall fn, self\log_traceback, self, ...
		if not ok
			Logger.debug "Arguments:"
			for arg in *{...}
				Logger.debug tostring arg
		return ok, err

	--- Call a function without self and, when failed, print debug information
	-- @tparam function fn Function to be called
	-- @param ... vararg list to pass to function
	pcall_bare: (fn, ...)=>
		ok, err = xpcall fn, self\log_traceback, ...
		if not ok
			Logger.debug "Arguments:"
			Logger.debug tostring arg for arg in *{...}
		return ok, err

	--- Print a traceback using the internal logging mechanism
	-- @see IRCClient\log
	log_traceback: (err)=>
		err = tostring err
		Logger.debug moonscript.errors.rewrite_traceback debug.traceback!, err
		Logger.debug "#{Logger.level.error} ---"
		return err

	--- Log message from IRC server (used in plugins)
	-- @tparam string input Line to print, IRC color formatted
	-- @see logger
	log: (input)=>
		for line in input\gmatch "[^\r\n]+"
			Logger.print '\00311(\003' .. (@server.caps and
				@server.caps['NETWORK'] or @config.server) ..
				"\00311)\003 #{line}"

return {:IRCClient, :priority}
