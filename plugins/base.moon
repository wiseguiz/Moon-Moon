set_caps = 0
local last_connect
{
	handlers:
		['001']: =>
			if @config.autojoin
				for channel in @config.autojoin\gmatch "[^,]+"
					@send_raw ("JOIN %s")\format channel
		['PING']: (sender, args, last)=>
			@send_raw ("PONG %s")\format last
		['ERROR']: (message)=>
			time = os.time()
			if time > last_connect + 30
				@connect!
			else
				cqueues.sleep(last_connect + 30 - time)

	hooks:
		['CONNECT']: =>
			last_connect = os.time()
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
