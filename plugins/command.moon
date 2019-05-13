import IRCClient from require "irc"
import sleep from require "cqueues"

unpack = unpack or table.unpack

handle_error = (channel, command, err)=>
	@send "COMMAND_ERR", channel, command, "Error: #{err}"

IRCClient\add_sender 'COMMAND_OK', (target, command_name, message)=>
	@send "PRIVMSG", target, "[\00303#{command_name}\003] #{message}"

IRCClient\add_sender 'COMMAND_ERR', (target, command_name, message)=>
	@send "PRIVMSG", target, "[\00304!#{command_name}\003] #{message}"

IRCClient\add_handler 'PRIVMSG', (prefix, args)=>
	{channel, message} = args

	cmd_prefix = @config.prefix
	return unless message\sub(1, #cmd_prefix) == cmd_prefix

	cmd_name = message\match "%S+", #cmd_prefix + 1
	command_args = {prefix, channel}
	command = @commands\get cmd_name, multiple: false, index: IRCClient.commands
	return @send "COMMAND_ERR", channel, "core", "Command not found: #{cmd_name}" unless command

	args = [arg for arg in message\gmatch "%S+", (message\find("%s") or #message) + 1]
	command_args[#command_args + 1] = table.concat args, " "
	command_args[#command_args + 1] = arg for arg in *args

	ok, err = @pcall command, unpack command_args
	unless ok
		handle_error self, channel, cmd_name, err

IRCClient\add_command "test", (prefix, channel)=>
	{:nick} = prefix

	sleep 5

	if @users[nick] and @users[nick].account
		@send "COMMAND_OK", channel, "test", "Account name: #{@users[nick].account}"
	else
		@send "COMMAND_ERR", channel, "test", "Account not found for: #{nick}"
