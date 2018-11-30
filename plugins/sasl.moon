import to_base64 from require 'basexx'
import IRCClient from require 'irc'

handlers =
	-- TODO abstract
	EXTERNAL: =>
		c = coroutine.create (auth)=>
			prefix, command, args = coroutine.yield "AUTHENTICATE EXTERNAL"
			assert args[1] == "+", "Unable to continue: #{args[#args]}"
			prefix, command, args = coroutine.yield "AUTHENTICATE +"
			assert command == "903" or command == "900", args[#args]

			@fire_hook 'CAP_ACK'
			@sasl_handler = nil
	PLAIN: =>
		c = coroutine.create (auth)=>
			prefix, command, args = coroutine.yield "AUTHENTICATE PLAIN"
			assert args[1] == "+", "Unable to continue: #{args[#args]}"
			payload = ""
			payload ..= "#{auth.identity or auth.username}\000"
			payload ..= "#{auth.username}\000#{auth.password}"
			payload = "AUTHENTICATE #{to_base64 payload}"
			prefix, command, args = coroutine.yield payload
			assert command == "903" or command == "900", args[#args]

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
	IRCClient\add_handler command, (prefix, args)=>
		return if not @sasl_handler
		ok, result = coroutine.resume @sasl_handler, prefix, command, args
		if not ok
			@sasl_handler = nil
			@fire_hook 'CAP_ACK' -- failed SASL, release lock on CAP END
			error "Error in SASL mechanism: #{result}"
		else
			@send_raw result
