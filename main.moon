#!/usr/bin/env moon
--- Create and manage IRC bots.
-- @script main.moon
-- @author Ryan "ChickenNuggers" <ryan@hashbang.sh>

Logger        = require 'logger' -- vim:set noet sts=0 sw=3 ts=3:
cqueues       = require 'cqueues'
lfs           = require 'lfs'

import IRCClient from require 'irc'

wd = lfs.currentdir()
Logger.set_debug true if os.getenv 'DEBUG'

load_modules = (folder)->
	for file in lfs.dir folder
		if file\match "%.lua$"
			dofile folder .. '/' .. file

load_modules_in_plugin_folders = ->
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
		bot  = IRCClient data.host, data.port, data

		bot.user_data   = data
		bot.config_file = file\match("(.+).ini$")

		table.insert(bots, bot)

queue = cqueues.new!

for bot in *bots
	queue\wrap ->
		while true
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
			pcall -> bot\loop!

assert queue\loop!
