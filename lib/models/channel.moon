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

return :Channel
