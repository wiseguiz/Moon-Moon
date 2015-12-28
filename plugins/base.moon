handlers:
	PING: (bot, sender, args, last)->
		print ("PONG %s")\format last
		bot\send_raw ("PONG %s")\format last
