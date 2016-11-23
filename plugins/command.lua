local lfs = require("lfs")
local IRCClient
IRCClient = require("irc").IRCClient
local unpack = unpack or table.unpack
return IRCClient:add_handler('PRIVMSG', function(self, prefix, args, message)
  if not message:match("^!" or not prefix:match(".+!.+@.+")) then
    return 
  end
  local line = message:sub(2)
  local command = line:match("%S+")
  if not self.commands[command] then
    return self:send_raw(("PRIVMSG %s :Command not found: [%s]!"):format(args[1], command))
  end
  args = { }
  for arg in line:gmatch("%S+") do
    args[#args + 1] = arg
  end
  table.remove(args[1])
  local ok, err = pcall(self.commands, self, table.concat(args, " "), unpack(args))
  if not ok then
    return self:send_raw(("PRIVMSG %s :Error: [%s]!"):format(args[1], err))
  end
end)
