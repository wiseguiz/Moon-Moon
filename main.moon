IRCConnection = require 'irc'
Logger = require 'logger'
cqueues = require 'cqueues'
lfs     = require 'lfs'

Logger.set_debug true if os.getenv 'DEBUG'

mods = {}
load_modules = (folder)->
	for file in lfs.dir folder
		if file\match "%.lua$"
			func = assert loadfile folder .. '/' .. file
			table.insert mods, func!

for module_folder in *{'plugins', 'modules'}
	load_modules module_folder if lfs.attributes(module_folder, 'mode') == 'directory'

bots = {}
for file in lfs.dir 'configs'
	if file\match "%.ini$"
		data = {
			dir: lfs.currentdir!
		}
		for line in io.lines('configs/' .. file)
			key, value = assert line\match "^(.-)=(.+)$"
			data[key] = value
		bot  = IRCConnection data.host, data.port, data

		for _, mod in pairs(mods)
			bot\load_modules mod
		bot\connect!

		table.insert(bots, bot)

main = (queue = require 'queue')->
	for _, bot in pairs bots
		queue\wrap -> bot\loop!

success, fw = pcall require, 'astronomy'
if not success then
	queue = cqueues.new!
	package.loaded['queue'] = queue
	main!
	while not queue\empty!
		assert queue\step!

else
	package.loaded['queue'] = fw
	fw\wrap main
