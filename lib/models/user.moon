import Map, Option from require 'lib.std'

class User
	new: (bot, nick, user, host, opts={})=>
		@_bot = assert bot
		@nick = assert nick
		@user = assert user
		@host = assert host
		@account = Option opts.account
		@away = Option opts.away
		@realname = Option opts.realname
		@is_self = opts.is_self or false
		@channels = Map opts.channels or {}

	--- Return whether or not the client is visible to the bot
	-- @treturn boolean
	is_visible: =>
		-- Add more as the bot "follows" more
		-- This is the bot itself, therefore it can always see itself
		return true if @is_self

		-- This is the amount of channels the bot can see the user in
		return true if #@channels == 0

		-- The bot can't see the user in any other fashion
		false

return :User
