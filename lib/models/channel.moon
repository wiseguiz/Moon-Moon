import Map, Option from require 'lib.std'

class Channel
	new: (bot, channel_name, input={})=>
		@_bot = assert bot
		@name = assert channel_name
		@status = Option input.status -- Bot's status in that channel
		@users = Map input.users or {}
		@statuses = Map input.statuses or {}

	send: (message)=>
		@_bot\send "PRIVMSG", @name, message

	-- Channel Operations
	part: (channel, message)=>
		if message
			@_bot\send_raw "PART", channel, message
		else
			@_bot\send_raw "PART", channel

	-- Mode changing commands

	-- ::TODO:: optimize for multiple targets
	op: (target)=>
		@_bot\send "MODE", channel, "+o", target

	deop: (target)=>
		@_bot\send "MODE", channel, "-o", target

	voice: (target)=>
		@_bot\send "MODE", channel, "+v", target

	devoice: (target)=>
		@_bot\send "MODE", channel, "-v", target

	-- ::TODO:: invite

return :Channel
