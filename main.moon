import IRCConnection, Logger from require 'irc'
cqueues = require 'cqueues'
lfs     = require 'lfs'

mods = {}
for file in lfs.dir 'plugins'
	if file\match "%.lua$"
		func = assert loadfile 'plugins/' .. file
		table.insert mods, func!

queue = cqueues.new!

--[[ ::TODO::
-- Remove this section later;
-- loop through config.ini
-- for a list of IRC bots.
-- ]]

bot = IRCConnection 'irc.esper.net'
bot\connect!
for _, mod in pairs(mods)
	bot\load_modules mod
queue\wrap -> bot\loop!

while not queue\empty!
	assert queue\step!
