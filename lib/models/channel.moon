import Map, Option from require 'lib.std'

class Channel
	new: (input)=>
		@status = Option input.status -- Bot's status in that channel
		@users = Map input.users or {}
		@statuses = Map input.statuses or {}

return :Channel
