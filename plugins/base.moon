handlers:
	['001']: =>
		if @config.autojoin
			for channel in @config.autojoin\gmatch "[^,]+"
				@\send_raw ("JOIN %s")\format channel
	PING: (bot, sender, args, last)->
		bot\send_raw ("PONG %s")\format last
