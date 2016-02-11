cqueues = require 'cqueues'
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
			if time > @data.last_connect + 30
				@connect!
			else
				cqueues.sleep(@data.last_connect + 30 - time)
		['433']: =>
			@data.nick_test = 0 if not @data.nick_test
			@data.nick_test += 1
			cqueues.sleep 0.5
			if @data.nick_test >= 30
				@disconnect!
			else
				@send_raw ('NICK %s[%d]')\format @config.nick, @data.nick_test

	hooks:
		['CONNECT']: =>
			@data = {} if not @data
			@data.last_connect = os.time()
			@send_raw 'CAP LS 302'
			if not @fire_hook 'LS_CAP'
				@send_raw 'CAP END'
		['REQ_CAP']: =>
			set_caps += 1
		['ACK_CAP']: =>
			set_caps -= 1
			if set_caps == 0
				@send_raw 'CAP END'
}
