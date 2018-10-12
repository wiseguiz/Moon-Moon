import IRCClient from require "irc"

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

	cmd_prefix = @config.prefix or "?>"
	return unless message\sub(1, #cmd_prefix) == cmd_prefix
	line = message\sub #cmd_prefix + 1

	command = line\match "%S+"
	command_args = {prefix, unpack(args)}
	return @send "COMMAND_ERR", channel, "core", "Command not found: #{command}" unless @commands[command]

	args = [arg for arg in line\gmatch "%S+"]
	table.remove(args, 1)
	command_args[#command_args + 1] = table.concat(args, " ")
	command_args[#command_args + 1] = arg for arg in *args
	xpcall @commands[command], handle_error(self, channel, command), self, unpack(command_args)

IRCClient\add_command "test", (_, channel)=> @send "COMMAND_OK", channel, "test", "Result"
