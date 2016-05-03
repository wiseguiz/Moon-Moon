local IRCConnection = require('irc')
local Logger = require('logger')
local cqueues = require('cqueues')
local lfs = require('lfs')
local wd = lfs.currentdir()
if os.getenv('DEBUG') then
  Logger.set_debug(true)
end
local mods = { }
local load_modules
load_modules = function(folder)
  for file in lfs.dir(folder) do
    if file:match("%.lua$") then
      local func = assert(loadfile(folder .. '/' .. file))
      table.insert(mods, func())
    end
  end
end
local load_modules_in_plugin_folders
load_modules_in_plugin_folders = function()
  mods = { }
  local _list_0 = {
    'plugins',
    'modules'
  }
  for _index_0 = 1, #_list_0 do
    local module_folder = _list_0[_index_0]
    local full_path = wd .. '/' .. module_folder
    if lfs.attributes(full_path, 'mode') == 'directory' then
      load_modules(full_path)
    end
  end
end
load_modules_in_plugin_folders()
local bots = { }
for file in lfs.dir('configs') do
  if file:match("%.ini$") then
    local data = {
      dir = wd
    }
    for line in io.lines('configs/' .. file) do
      local key, value = assert(line:match("^(.-)=(.+)$"))
      data[key] = value
    end
    local bot = IRCConnection(data.host, data.port, data)
    for _index_0 = 1, #mods do
      local mod = mods[_index_0]
      bot:load_modules(mod)
    end
    bot.user_data = data
    bot.config_file = file:match("(.+).ini$")
    table.insert(bots, bot)
  end
end
local queue = cqueues.new()
for _index_0 = 1, #bots do
  local bot = bots[_index_0]
  queue:wrap(function()
    local success
    for i = 1, 3 do
      local ok, err = pcall(bot.connect, bot)
      success = ok
      if not ok then
        Logger.print(Logger.level.error .. '*** Unable to connect: ' .. bot.user_data.host)
        Logger.debug(Logger.level.error .. '*** ' .. err)
      else
        break
      end
    end
    if not success then
      Logger.print(Logger.level.fatal .. '*** Not connecting anymore for: ' .. bot.config_file)
      return 
    end
    return bot:loop()
  end)
end
return assert(queue:loop())
