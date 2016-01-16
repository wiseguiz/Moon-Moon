local IRCConnection = require('irc')
local Logger = require('logger')
local cqueues = require('cqueues')
local lfs = require('lfs')
local mods = { }
for file in lfs.dir('plugins') do
  if file:match("%.lua$") then
    local func = assert(loadfile('plugins/' .. file))
    table.insert(mods, func())
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
    bot:connect()
    for _, mod in pairs(mods) do
      bot:load_modules(mod)
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
  if os.getenv('DEBUG') then
    Logger.print('Loading debug module')
    Logger.set_debug(true)
    Logger.debug('Loaded debug module')
  end
  main()
  while not queue:empty() do
    assert(queue:step())
  end
else
  package.loaded['queue'] = fw
  return fw:wrap(main)
end
