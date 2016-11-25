local IRCClient
IRCClient = require('irc').IRCClient
local colors = {
  3,
  4,
  6,
  8,
  9,
  10,
  11,
  13
}
local hash
hash = function(input)
  local out_hash = 5381
  for char in input:gmatch(".") do
    out_hash = ((out_hash << 5) + out_hash) + char:byte()
  end
  return out_hash
end
local color
color = function(input)
  return "\003" .. tostring(colors[hash(input) % #colors + 1]) .. tostring(input) .. "\003"
end
local patterns = {
  JOIN = "\00308[\003%s\00308]\003 \00309>\003 %s",
  MODE = "\00308[\003%s\00308]\003 Mode %s by %s",
  KICK = "\00308[\003%s\00308]\003 %s kicked %s",
  KICK_2 = "\00308[\003%s\00308]\003 %s kicked %s \00314(\00315%s\00314)\003",
  PART = "\00308[\003%s\00308]\003 \00304<\003 %s",
  PART_2 = "\00308[\003%s\00308]\003 \00304<\003 %s \00314(\00315%s\00314)\003",
  QUIT = "\00311<\003%s\00311>\003 \00304<\003",
  QUIT_2 = "\00311<\003%s\00311>\003 \00304<\003 \00315(\00314%s\00315)\003",
  ACTION = "\00308[\003%s\00308]\003 * %s %s",
  ACTION_2 = "* %s %s",
  PRIVMSG = "\00311<\00308[\003%s\00308]\003%s\00311>\003 %s",
  PRIVMSG_2 = "\00311<\003%s\00311>\003 %s",
  NOTICE = "\00311-\00308[\003%s\00308]\003%s\00311-\003 %s",
  NOTICE_2 = "\00311-\003%s\00311-\003 %s",
  INVITE = "\00308[\003%s\00308]\003 %s invited %s",
  NETJOIN = "\00308[\003%s\00308]\003 \00309>\003 \00314(\00315%s\00314)\003",
  NETSPLIT = "\00304<\003 \00314(\00315%s\00314)\003"
}
local serve_self
serve_self = function(new_table)
  return setmetatable(new_table, {
    __call = function(self)
      return pairs(self)
    end
  })
end
IRCClient:add_handler('372', function(self, prefix, args, trail)
  return self:log("\00305" .. trail)
end)
IRCClient:add_handler('JOIN', function(self, prefix, args, trail, tags)
  if tags == nil then
    tags = { }
  end
  local channel = args[1] or trail
  return self:log(patterns.JOIN:format(channel, color(prefix:match('^(.-)!') or prefix)))
end)
IRCClient:add_handler('NICK', function(self, prefix, args, trail)
  local old = color(prefix:match('^(.-)!') or prefix)
  local new = color(args[1] or trail)
  return self:log(('%s \00309>>\003 %s'):format(old, new))
end)
IRCClient:add_handler('MODE', function(self, prefix, args, trailing)
  local channel = args[1]
  table.remove(args, 1)
  if channel:sub(1, 1) == "#" then
    return self:log(patterns.MODE:format(channel, table.concat(args, " "), color(prefix:match('^(.-)!') or prefix)))
  end
end)
IRCClient:add_handler('KICK', function(self, prefix, args, trailing)
  local channel = args[1]
  local nick = color(args[2])
  local kicker = color(prefix:match('^(.-)!') or prefix)
  if trailing then
    return self:log(patterns.KICK_2:format(channel, kicker, nick, trailing))
  else
    return self:log(patterns.KICK:format(channel, kicker, nick))
  end
end)
IRCClient:add_handler('PART', function(self, prefix, args, trailing)
  local channel = args[1]
  local nick = color(prefix:match('^(.-)!') or prefix)
  if trailing then
    return self:log(patterns.PART_2:format(channel, nick, trailing))
  else
    return self:log(patterns.PART:format(channel, nick))
  end
end)
IRCClient:add_handler('QUIT', function(self, prefix, args, trailing, tags)
  if tags == nil then
    tags = { }
  end
  local nick = color(prefix:match('^(.-)!') or prefix)
  if trailing then
    return self:log(patterns.QUIT_2:format(nick, trailing))
  else
    return self:log(patterns.QUIT:format(nick))
  end
end)
IRCClient:add_handler('PRIVMSG', function(self, prefix, args, trailing)
  local nick = prefix:match('^(.-)!') or prefix
  if not args[1]:sub(1, 1) == '#' then
    if trailing:match("^\001ACTION .-\001$") then
      return self:log(patterns.ACTION_2:format(color(nick), trailing:match('^%S+%s+(.+)')))
    elseif not trailing:match('^\001') then
      return self:log(patterns.PRIVMSG_2:format(color(nick), trailing))
    end
  else
    local ch = args[1]
    prefix = self.users[nick].channels[ch].status:sub(1, 1) or ""
    if prefix ~= "" then
      prefix = color(prefix)
    end
    local user = prefix .. color(nick)
    if trailing:match("^\001ACTION .-\001$") then
      return self:log(patterns.ACTION:format(ch, user, trailing:match('^%S+%s+(.+)')))
    elseif not trailing:match('^\001') then
      return self:log(patterns.PRIVMSG:format(ch, user, trailing))
    end
  end
end)
IRCClient:add_handler('NOTICE', function(self, prefix, args, trailing)
  if trailing:sub(1, 1) == '\001' then
    return 
  end
  local nick = prefix:match('^(.-)!') or prefix
  if args[1]:sub(1, 1) == '#' then
    prefix = self.users[nick].channels[ch].status:sub(1, 1) or ""
    if prefix ~= "" then
      prefix = color(prefix)
    end
    local user = prefix .. color(nick)
    return self:log(patterns.NOTICE:format(args[1], user, trailing))
  else
    return self:log(patterns.NOTICE_2:format(color(nick), trailing))
  end
end)
return IRCClient:add_handler('INVITE', function(self, prefix, args, trailing)
  local nick = color(prefix:match('^(.-)!') or prefix)
  local channel = args[2]
  return self:log(patterns.INVITE:format(channel, nick, args[1]))
end)
