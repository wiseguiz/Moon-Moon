IRCConnection = require 'irc' -- vim:set noet sts=0 sw=3 ts=3:
Logger        = require 'logger'
cqueues       = require 'cqueues'
lfs           = require 'lfs'

wd = lfs.currentdir()

Logger.set_debug true if os.getenv 'DEBUG'

mods = {}
watching = {
	dirty: nil
}
load_modules = (folder)->
	for file in lfs.dir folder
		mod_date = lfs.attributes folder .. '/' .. file, 'modification'
		if file\match "%.lua$"
			if not watching[file] or watching[file] ~= mod_date
				if not watching[file]
					Logger.print 'Loading ' .. file
				else
					Logger.print 'Reloading ' .. file
				watching.dirty = true
				watching[file] = mod_date
	if watching.dirty -- reload if dirty
		for file in lfs.dir folder
			if file\match "%.lua$"
				func = assert loadfile folder .. '/' .. file
				table.insert mods, func!

load_modules_in_plugin_folders = ->
	mods = {}
	for module_folder in *{'plugins', 'modules'}
		full_path = wd .. '/' .. module_folder
		load_modules full_path if lfs.attributes(full_path, 'mode') == 'directory'

load_modules_in_plugin_folders!

bots = {}
for file in lfs.dir 'configs'
	if file\match "%.ini$"
		data = {
			dir: wd
		}
		for line in io.lines('configs/' .. file)
			key, value = assert line\match "^(.-)=(.+)$"
			data[key] = value
		bot  = IRCConnection data.host, data.port, data

		for mod in *mods
			bot\load_modules mod

		bot.user_data   = data
		bot.config_file = file\match("(.+).ini$")

		table.insert(bots, bot)

main = (queue = require 'queue')->
	queue\wrap -> -- Run load_modules after reloading modules
		while true
			cqueues.sleep 5
			pcall ->
				load_modules_in_plugin_folders!
				if watching.dirty
					watching.dirty = false
					for bot in *bots
						bot\clear_modules!
						for mod in *mods
							bot\load_modules mod

	for bot in *bots
		queue\wrap ->
			local success
			for i=1, 3 do -- three tries
				ok, err = pcall bot.connect, bot
				success = ok
				if not ok
					Logger.print Logger.level.error .. '*** Unable to connect: ' .. bot.user_data.host
					Logger.debug Logger.level.error .. '*** ' .. err
				else
					break

			if not success
				Logger.print Logger.level.fatal .. '*** Not connecting anymore for: ' .. bot.config_file
				return
			bot\loop!

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
