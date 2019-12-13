cqueues = require 'cqueues'
import IRCClient from require 'lib.irc'

unpack = unpack or table.unpack

for tmp_cmd in *{'422', '376'}
	IRCClient\add_handler tmp_cmd, => @fire_hook 'READY'

IRCClient\add_hook 'READY', =>
	if @config.autojoin
		channels = @config.autojoin
		for i=1, #channels, 4
			@send_raw "JOIN", table.concat({channels[i], channels[i+1], channels[i+2], channels[i+3]}, ",")

IRCClient\add_handler 'PING', (prefix, args)=>
	@send_raw "PONG", unpack args

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
		@send_raw 'NICK', "#{@config.nick}[#{@data.nick_test}]"

IRCClient\add_handler '354', (prefix, args)=>
	table.remove(args, 1)
	query_type = table.remove(args, 1)
	@fire_hook "WHOX_#{query_type}", unpack(args)

IRCClient\add_sender 'PRIVMSG', (target, message, tags={})=>
	for line in message\gmatch("[^\r\n]+")
		@send_raw 'PRIVMSG', target, line, tags: tags
		unless @server.ircv3_caps["echo-message"]
			@process_line ":#{@config.nick}!local@localhost PRIVMSG #{target} :(local) #{line}"

IRCClient\add_sender 'TAGMSG', (target, tags={})=>
	@send_raw 'TAGMSG', target, tags: tags
