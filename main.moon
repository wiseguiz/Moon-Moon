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

pcall -> -- use StackTracePlus if available; it's much better than builtin
	debug.traceback = require("StackTracePlus").stacktrace

load_modules = (folder)->
	for file in lfs.dir folder
		if file\match "%.lua$"
			path = "#{folder}/#{file}"
			IRCClient\with_context path, loadfile path

load_modules_in_plugin_folders = ->
	for module_folder in *{'plugins', 'modules'}
		full_path = wd .. '/' .. module_folder
		load_modules full_path if lfs.attributes(full_path, 'mode') == 'directory'

load_modules_in_plugin_folders!

bots = {}
conf_home = os.getenv('XDG_CONFIG_HOME') or os.getenv('HOME') .. '/.config'
for file in lfs.dir "#{conf_home}/moonmoon"
	if file\match "%.lua$"
		local data
		(loadfile "#{conf_home}/moonmoon/#{file}", nil, {
			bot: (name)->
				return (file_data)->
					file_data.name = name
					file_data.file = file
					data = file_data
		})()
		unless data and data.server
			print "Missing `server` field: [#{file}]"
			continue
		if os.getenv 'DEBUG'
			for key, value in pairs data
				if type(value) == "string" then
					print ("%q: %q")\format key, value
				else
					print ("%q: %s")\format key, value
		bot = IRCClient data.server, data.port, data
		table.insert(bots, bot)

queue = cqueues.new!

package.loaded["queue"] = queue -- for use in modules

for bot in *bots
	queue\wrap ->
		while true
			local success
			for i=1, 3 do -- three tries
				ok, err = pcall bot.connect, bot
				success = ok
				if not ok
					Logger.print Logger.level.error .. '*** Unable to connect: ' .. bot.config.server
					Logger.debug Logger.level.error .. '*** ' .. err
				else
					break
			if not success
				Logger.print Logger.level.fatal .. '*** Not connecting anymore for: ' .. bot.config.file
				return

			ok, err = pcall -> bot\loop!
			if not ok then
				Logger.print Logger.level.error .. err

while not queue\empty!
	ok, err = queue\loop!
	if not ok
		Logger.debug "#{Logger.level.error} *** #{err}"
