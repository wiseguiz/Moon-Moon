import Map, Option from require 'lib.std'

class User
	new: (user, host, opts)=>
		@user = input.user
		@host = input.host
		@account = Option opts.account
		@away = opts.away == true
		@channels = Map opts.channels or {}

	is_visible: =>
		-- Add more as the bot "follows" more
		return true if #@channels == 0
		false

return :User
