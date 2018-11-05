import to_base64 from require 'basexx'
import IRCClient from require 'irc'

handlers =
	PLAIN: =>
		c = coroutine.create (auth)=>
			prefix, command, args, trail = coroutine.yield "AUTHENTICATE PLAIN"
			assert args[#args] == "+", "Unable to continue: #{table.concat(args)}"
			payload = ""
			payload ..= "#{auth.identity or auth.username}\000"
			payload ..= "#{auth.username}\000#{auth.password}"
			payload = "AUTHENTICATE #{to_base64 payload}"
			prefix, command, args, trail = coroutine.yield payload
			print command
			assert command == "903" or command == "900", trail

			-- destroy self on finish
			@fire_hook 'CAP_ACK' -- finished SASL, release lock on CAP END
			@sasl_handler = nil

		@send_raw select(2, assert(coroutine.resume c, self, @config.auth))
		return c
	

IRCClient\add_hook 'CAP_ACK.sasl', (values = 'PLAIN')=>
	return unless @config.auth
	methods = [w for w in values\gmatch "[^,]+"]
	for method in *methods
		if handlers[method] and @config.auth.mechanism == method
			-- found usable method
			@set_caps += 1
			@sasl_handler = handlers[method] self, @config.auth

for command in *{"AUTHENTICATE", "900", "901", "903", "904", "905", "906"}
	IRCClient\add_handler command, (prefix, args, trail)=>
		return if not @sasl_handler
		ok, result = coroutine.resume @sasl_handler, prefix, command, args, trail
		if not ok
			@sasl_handler = nil
			@fire_hook 'CAP_ACK' -- failed SASL, release lock on CAP END
			error "Error in SASL mechanism: #{result}"
		else
			@send_raw result
