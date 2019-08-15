import Map from require 'lib.std'

class User
	new: (input)=>
		@user = input.user or "" -- ::TODO:: assert?
		@host = input.host or "" -- ::TODO:: assert?
		@account = input.account or ""
		@away = input.away == true
		@channels = Map input.channels or {}

	is_visible: =>
		-- Add more as the bot "follows" more
		return true if #@channels == 0
		false

return :User
