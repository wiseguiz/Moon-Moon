local Logger = require('logger')
local cqueues = require('cqueues')
local lfs = require('lfs')
local IRCClient
IRCClient = require('irc').IRCClient
local wd = lfs.currentdir()
if os.getenv('DEBUG') then
  Logger.set_debug(true)
end
local load_modules
load_modules = function(folder)
  for file in lfs.dir(folder) do
    if file:match("%.lua$") then
      dofile(folder .. '/' .. file)
    end
  end
end
local load_modules_in_plugin_folders
load_modules_in_plugin_folders = function()
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
      local key, value = assert(line:match("^(.-)%s+=%s+(.-)$"))
      if tonumber(value) then
        data[key] = tonumber(value)
      elseif value == "true" or value == "false" then
        data[key] = value == true
      else
        data[key] = value
      end
    end
    assert(data.server, "Missing `server` field: [" .. tostring(file) .. "]")
    if os.getenv('DEBUG') then
      for key, value in pairs(data) do
        if type(value) == "string" then
          print(("%q: %q"):format(key, value))
        else
          print(("%q: %s"):format(key, value))
        end
      end
    end
    local bot = IRCClient(data.server, data.port, data)
    bot.user_data = data
    bot.config_file = file:match("(.+).ini$")
    table.insert(bots, bot)
  end
end
local queue = cqueues.new()
for _index_0 = 1, #bots do
  local bot = bots[_index_0]
  queue:wrap(function()
    while true do
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
      local ok, err = pcall(function()
        return bot:loop()
      end)
      if not ok then
        Logger.print(Logger.level.error .. err)
      end
    end
  end)
end
return assert(queue:loop())
