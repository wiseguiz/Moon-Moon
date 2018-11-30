cqueues = require 'cqueues'
import IRCClient from require 'irc'

unpack = unpack or table.unpack

for tmp_cmd in *{'422', '376'}
	IRCClient\add_handler tmp_cmd, => @fire_hook 'READY'

IRCClient\add_hook 'READY', =>
	if @config.autojoin
		-- ::TODO:: properly
		for channel in *@config.autojoin
			@send_raw ("JOIN %s")\format channel

IRCClient\add_handler 'PING', (prefix, args)=>
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

IRCClient\add_handler '354', (prefix, args)=>
	table.remove(args, 1)
	query_type = table.remove(args, 1)
	@fire_hook "WHOX_#{query_type}", unpack(args)

IRCClient\add_sender 'PRIVMSG', (channel, message)=>
	for line in message\gmatch("[^\r\n]+")
		@send_raw "PRIVMSG #{channel} :#{line}"
		unless @server.ircv3_caps["echo-message"]
			@process ":#{@config.nick}!local@localhost PRIVMSG #{channel} :(local) #{line}"
