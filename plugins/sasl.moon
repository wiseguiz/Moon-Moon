import to_base64 from require 'basexx'
import IRCClient from require 'irc'


scram_hmac_methods = {
	SHA: {
		"256": "sha256"
		"1": "sha1"
	}
}

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

		@send_raw select(2, assert(coroutine.resume c, self, @config.auth))
		return c

	"SCRAM": =>
		c = coroutine.create (auth)=>
			_type, algo = @sasl_method\match "[^%-]+%-([^%-]+)-([^%-]+)"
			hmac_method = scram_hmac_methods[_type][algo]
			hmac_object = error! -- ::TODO:: finish

		@send_raw select(2, assert(coroutine.resume c, self, @config.auth))
		return c

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
	

IRCClient\add_hook 'CAP_ACK.sasl', (values='SCRAM-SHA-256,PLAIN')=>
	return unless @config.auth
	methods = [w for w in values\gmatch "[^,]+"]
	if @config.auth.mechanism
		for method in *methods
			index = method\match "[^%-]+"
			if handlers[index] and @config.auth.mechanism == method
				@set_caps += 1
				@sasl_method = method
				@sasl_handler = handlers[index] self, @config.auth
				return
	else
		for method in *methods
			index = method\match "[^%-]+"
			if handlers[index]
				@set_caps += 1
				@sasl_method = method
				@sasl_handler = handlers[index] self, @config.auth
				return

IRCClient\add_handler "908", (_, args)=>
	@fire_hook 'CAP_ACK'
	@sasl_method = nil
	@sasl_handler = nil
	@fire_hook 'CAP_ACK.sasl', args[2]

for cmd in *{"AUTHENTICATE", "900", "901", "903", "904", "905", "906", "907"}
	IRCClient\add_handler cmd, (prefix, args)=>
		return if not @sasl_handler
		ok, result = coroutine.resume @sasl_handler, prefix, cmd, args
		if not ok
			@sasl_handler = nil
			@sasl_method = nil
			@fire_hook 'CAP_ACK' -- failed SASL, release lock on CAP END
			error "Error in SASL mechanism: #{result}"
		else
			@send_raw line for line in result\gmatch "[^\r\n]+"
