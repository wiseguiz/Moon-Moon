import IRCClient from require "irc"
import sleep from require "cqueues"

unpack = unpack or table.unpack

handle_error = (target, command, err)=>
	@send "COMMAND_ERR", target, command, "Error: #{err}"

IRCClient\add_sender 'COMMAND_OK', (target, command_name, message, msgid)=>
	if msgid
		@send "PRIVMSG", target, "[\00303#{command_name}\003] #{message}", "+draft/reply": msgid
	else
		@send "PRIVMSG", target, "[\00303#{command_name}\003] #{message}"

IRCClient\add_sender 'COMMAND_ERR', (target, command_name, message, msgid)=>
	if msgid
		@send "PRIVMSG", target, "[\00304!#{command_name}\003] #{message}", "+draft/reply": msgid
	else
		@send "PRIVMSG", target, "[\00304!#{command_name}\003] #{message}"

IRCClient\add_handler 'PRIVMSG', (prefix, args, tags)=>
	{target, message} = args

	cmd_prefix = @config.prefix
	return unless message\sub(1, #cmd_prefix) == cmd_prefix

	msgid = @get_tag(tags, key: 'msgid').value

	cmd_name = message\match "%S+", #cmd_prefix + 1
	command_args = {prefix, target, tags}
	command = @commands\get cmd_name, multiple: false, index: IRCClient.commands
	return @send "COMMAND_ERR", target, "core", "Command not found: #{cmd_name}", msgid unless command

	args_start = (message\find"%s" or #message) + 1
	args = [arg for arg in message\sub(args_start)\gmatch "%S+"]
	command_args[#command_args + 1] = table.concat args, " "
	command_args[#command_args + 1] = arg for arg in *args

	command self, unpack command_args
	--ok, err = @pcall command, unpack command_args
	--unless ok
	--	handle_error self, target, cmd_name, err

IRCClient\add_command "test", async: true, (prefix, target, tags)=>
	{:nick} = prefix

	msgid = @get_tag(tags, key: 'msgid').value

	sleep 5

	if @users[nick] and @users[nick].account
		@send "COMMAND_OK", target, "test", "Account name: #{@users[nick].account}", msgid
	else
		@send "COMMAND_ERR", target, "test", "Account not found for: #{nick}", msgid

IRCClient\add_command "caps", (prefix, target)=>
	line = [k for k in pairs @server.ircv3_caps]
	@send "COMMAND_OK", target, "caps", table.concat(line, ", ")
