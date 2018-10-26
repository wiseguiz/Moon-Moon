import IRCClient from require "irc"

import sleep from require "cqueues"

unpack = unpack or table.unpack

handle_error = (channel, command)=> (err)->
	@log_traceback(err)
	@send "COMMAND_ERR", channel, command, "Error: #{err}"

IRCClient\add_sender 'COMMAND_OK', (target, command_name, message)=>
	@send "PRIVMSG", target, "[\00303#{command_name}\003] #{message}"

IRCClient\add_sender 'COMMAND_ERR', (target, command_name, message)=>
	@send "PRIVMSG", target, "[\00304!#{command_name}\003] #{message}"

IRCClient\add_handler 'PRIVMSG', (prefix, args, message)=>
	return unless prefix\match ".+!.+@.+"
	channel = args[1]

	cmd_prefix = @config.prefix
	return unless message\sub(1, #cmd_prefix) == cmd_prefix

	command = message\match "%S+", #cmd_prefix + 1
	command_args = {prefix, unpack(args)}
	return @send "COMMAND_ERR", channel, "core", "Command not found: #{command}" unless @commands[command]

	args = [arg for arg in message\gmatch "%S+", (message\find("%s") or #message) + 1]
	command_args[#command_args + 1] = table.concat(args, " ")
	command_args[#command_args + 1] = arg for arg in *args
	xpcall @commands[command], handle_error(self, channel, command), self, unpack(command_args)

IRCClient\add_command "test", async: true, (prefix, channel)=>
	nick = prefix\match "^[^!]+"

	sleep 5

	if @users[nick] and @users[nick].account
		@send "COMMAND_OK", channel, "test", "Account name: #{@users[nick].account}"
	else
		@send "COMMAND_ERR", channel, "test", "Account not found for: #{nick}"
