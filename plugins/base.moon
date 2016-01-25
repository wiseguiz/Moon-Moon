set_caps = 0
{
	handlers:
		['001']: =>
			if @config.autojoin
				for channel in @config.autojoin\gmatch "[^,]+"
					@send_raw ("JOIN %s")\format channel
		PING: (bot, sender, args, last)->
			bot\send_raw ("PONG %s")\format last
	hooks:
		['CONNECT']: =>
			@send_raw 'CAP LS 302'
			if not @fire_hook 'CAP_LS'
				@send_raw 'CAP END'
		['REQ_CAP']: =>
			set_caps += 1
		['ACK_CAP']: =>
			set_caps -= 1
			if set_caps == 0
				@send_raw 'CAP END'
}
