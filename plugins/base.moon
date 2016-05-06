cqueues = require 'cqueues'
import IRCClient from require 'irc'

IRCClient\add_handler '001', =>
	if @config.autojoin
		for channel in @config.autojoin\gmatch "[^,]+"
			@send_raw ("JOIN %s")\format channel

IRCClient\add_handler 'PING', (sender, args, last)=>
	@send_raw ("PONG :%s")\format last

IRCClient\add_handler 'ERROR', =>
	time = os.time()
	if time > @data.last_connect + 30
		@connect!
	else
		cqueues.sleep(@data.last_connect + 30 - time)

IRCClient\add_handler '433', =>
	@data.nick_test = 0 if not @data.nick_test
	@data.nick_test += 1
	cqueues.sleep 0.5
	if @data.nick_test >= 30
		@disconnect!
	else
		@send_raw ('NICK %s[%d]')\format @config.nick, @data.nick_test
