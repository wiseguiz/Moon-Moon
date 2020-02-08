import Map, Option from require 'lib.std'

class User
	new: (bot, nick, user, host, opts={})=>
		@_bot = assert bot
		@nick = assert nick
		@user = assert user
		@host = assert host
		@account = Option opts.account
		@away = opts.away == true
		@channels = Map opts.channels or {}

	is_visible: =>
		-- Add more as the bot "follows" more
		return true if #@channels == 0
		false

return :User
