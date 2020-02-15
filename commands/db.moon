import IRCClient from require "lib.irc"

pgmoon = require "pgmoon"

IRCClient\add_command "init-db", (prefix, channel)=>
	nick = prefix.nick
	user = @users\expect nick, "User not seen by bot: #{nick}"
	account = user.account\expect "User does not have an account"
	valid_account = @config.owner_account
	assert account == valid_account, "You're not #{valid_account}"
	@db = pgmoon.new
		socket_type: "cqueues"
		database: "#{@config.db.name}"
		user: "#{@config.db.username}"
		password: "#{@config.db.password}"

	ok, err = @db\connect!
	if ok
		@send "COMMAND_OK", channel, "init-db", "Successfully connected"
	else
		@send "COMMAND_ERR", channel, "init-db", err
