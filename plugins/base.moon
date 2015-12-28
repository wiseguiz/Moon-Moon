handlers:
	PING: (bot, sender, args, last)->
		bot\send_raw ("PONG %s")\format last
