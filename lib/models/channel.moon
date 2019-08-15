import Map from require 'lib.std'

class Channel
	new: (input)=>
		@status = input.status or ""
		@users = Map input.users or {}
		@statuses = Map input.statuses or {}

return :Channel
