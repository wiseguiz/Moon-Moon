lfs = require "lfs"
import IRCClient from require "irc"

unpack = unpack or table.unpack

IRCClient\add_handler 'PRIVMSG', (prefix, args, message)=>
	return if not message\match "^%?>" or not prefix\match ".+!.+@.+"
	line = message\sub 3
	command = line\match "%S+"
	if not @commands[command] then
		return @send_raw ("PRIVMSG %s :Command not found: [%s]!")\format(args[1], command)
	args = {}
	for arg in line\gmatch "%S+"
		args[#args + 1] = arg
	table.remove(args[1])
	ok, err = pcall(@commands, @, table.concat(args, " "), unpack(args))
	if not ok then
		return @send_raw ("PRIVMSG %s :Error: [%s]!")\format(args[1], err)
