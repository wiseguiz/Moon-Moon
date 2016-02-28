local IRCConnection = require('irc')
local Logger = require('logger')
local cqueues = require('cqueues')
local lfs = require('lfs')
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
local _list_0 = {
  'plugins',
  'modules'
}
for _index_0 = 1, #_list_0 do
  local module_folder = _list_0[_index_0]
  if lfs.attributes(module_folder, 'mode') == 'directory' then
    load_modules(module_folder)
  end
end
local bots = { }
for file in lfs.dir('configs') do
  if file:match("%.ini$") then
    local data = {
      dir = lfs.currentdir()
    }
    for line in io.lines('configs/' .. file) do
      local key, value = assert(line:match("^(.-)=(.+)$"))
      data[key] = value
    end
    local bot = IRCConnection(data.host, data.port, data)
    for _, mod in pairs(mods) do
      bot:load_modules(mod)
    end
    local success
    for i = 1, 3 do
      local ok, err = bot:connect()
      success = ok
      if not ok then
        Logger.print(Logger.level.error .. '*** Unable to connect: ' .. data.host)
      end
    end
    if not success then
      logger.print(Logger.level.fatal .. '*** Not connecting anymore for: ' .. file)
    end
    table.insert(bots, bot)
  end
end
local main
main = function(queue)
  if queue == nil then
    queue = require('queue')
  end
  for _, bot in pairs(bots) do
    queue:wrap(function()
      return bot:loop()
    end)
  end
end
local success, fw = pcall(require, 'astronomy')
if not success then
  local queue = cqueues.new()
  package.loaded['queue'] = queue
  main()
  while not queue:empty() do
    assert(queue:step())
  end
else
  package.loaded['queue'] = fw
  return fw:wrap(main)
end
