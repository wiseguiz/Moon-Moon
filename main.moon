IRCConnection = require 'irc'
Logger = require 'logger'
cqueues = require 'cqueues'
lfs     = require 'lfs'

mods = {}
for file in lfs.dir 'plugins'
	if file\match "%.lua$"
		func = assert loadfile 'plugins/' .. file
		table.insert mods, func!

main = (queue = require 'queue')->

	for file in lfs.dir 'configs'
		if file\match "%.ini$"
			data = {}
			for line in io.lines('configs/' .. file)
				key, value = assert line\match "^(.-)=(.+)$"
				data[key] = value
			bot  = IRCConnection data.host, data.port, data

			bot\connect!
			for _, mod in pairs(mods)
				bot\load_modules mod

			queue\wrap -> bot\loop!

success, fw = pcall require, 'astronomy'
if not success then
	queue = cqueues.new!
	package.loaded['queue'] = queue
	if os.getenv 'DEBUG'
		Logger.print 'Loading debug module'
		Logger.set_debug true
		Logger.debug 'Loaded debug module'
	main!
	while not queue\empty!
		assert queue\step!

else
	fw\wrap main
