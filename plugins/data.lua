local IRCClient
IRCClient = require('irc').IRCClient
local serve_self
serve_self = function(new_table)
  return setmetatable(new_table, {
    __call = function(self)
      return pairs(self)
    end
  })
end
local unpack = unpack or table.unpack
local caps = {
  'extended-join',
  'multi-prefix',
  'away-notify',
  'account-notify',
  'chghost',
  'server-time',
  'echo-message',
  'invite-notify'
}
IRCClient:add_hook('CONNECT', function(self)
  self.channels = serve_self({ })
  self.users = serve_self({ })
  self.server = {
    caps = serve_self({ }),
    ircv3_caps = serve_self({ }),
    batches = serve_self({ })
  }
end)
IRCClient:add_hook('ACK_CAP', function(self)
  self.data.set_caps = self.data.set_caps - 1
  if self.data.set_caps <= 0 then
    return self:send_raw('CAP END')
  end
end)
IRCClient:add_hook('CONNECT', function(self)
  if not self.data then
    self.data = { }
  end
  self.data.last_connect = os.time()
  self.data.set_caps = 0
  self:send_raw('CAP LS 302')
  for i = 1, #caps do
    self.data.set_caps = self.data.set_caps + 1
  end
end)
IRCClient:add_handler('BATCH', function(self, prefix, args, trail, tags)
  local tag_type, tag = args[1]:match('(.)(.+)')
  if tag_type == '+' then
    self.server.batches[tag] = {
      unpack(args, 2)
    }
  elseif tag_type == '-' then
    self.server.batches[tag] = nil
  end
end)
IRCClient:add_handler('005', function(self, prefix, args)
  local isupport_caps = {
    select(2, unpack(args))
  }
  for _index_0 = 1, #isupport_caps do
    local cap = isupport_caps[_index_0]
    if cap:sub(1, 1) == "-" then
      if cap:find("=") then
        self.server.caps[cap:match("^%-(.+)=")] = nil
      else
        self.server.caps[cap:sub(2)] = nil
      end
    elseif cap:find("=") then
      local key, value = cap:match('^(.-)=(.+)')
      self.server.caps[key] = value
    else
      self.server.caps[cap] = true
    end
  end
end)
IRCClient:add_handler('AWAY', function(self, prefix, args, trail)
  local nick = prefix:match('^(.-)!')
  self.users[nick].away = trail
end)
IRCClient:add_handler('ACCOUNT', function(self, prefix, args, trail)
  local nick = prefix:match('^(.-)!')
  self.users[nick].account = args[1] ~= "*" and args[1] or nil
end)
IRCClient:add_handler('JOIN', function(self, prefix, args, trail, tags)
  if tags == nil then
    tags = { }
  end
  local channel
  local account
  if self.server.ircv3_caps['extended-join'] then
    if args[2] ~= '*' then
      account = args[2]
    end
    channel = args[1]
  elseif self.server.ircv3_caps['account-tag'] and tags.account then
    account = tags.account
    channel = args[1]
  else
    channel = args[1] or trail
  end
  local nick, username, host = prefix:match('^(.-)!(.-)@(.-)$')
  if prefix:match('^.-!.-@.-$') then
    if not self.users[nick] then
      self.users[nick] = {
        account = account,
        channels = {
          [channel] = {
            status = ""
          }
        },
        username = username,
        host = host
      }
    else
      if not self.users[nick].channels then
        self.users[nick].channels = {
          [channel] = {
            status = ""
          }
        }
      else
        self.users[nick].channels[channel] = {
          status = ""
        }
      end
    end
    if account then
      self.users[nick].account = account
    end
  end
  if not self.channels[channel] then
    if self.server.ircv3_caps['userhost-in-names'] then
      self:send_raw(('NAMES %s'):format(channel))
    else
      self:send_raw(('WHO %s'):format(channel))
    end
    self.channels[channel] = {
      users = {
        [nick] = self.users[nick]
      }
    }
  else
    self.channels[channel].users[nick] = self.users[nick]
  end
end)
IRCClient:add_handler('NICK', function(self, prefix, args, trail)
  local old = prefix:match('^(.-)!') or prefix
  local new = args[1] or trail
  for channel_name in pairs(self.users[old].channels) do
    self.channels[channel_name].users[new] = self.channels[channel_name].users[old]
    self.channels[channel_name].users[old] = nil
  end
  self.users[new] = self.users[old]
  self.users[old] = nil
end)
IRCClient:add_handler('MODE', function(self, prefix, args)
  if args[1] and args[1]:sub(1, 1) == "#" then
    return self:send_raw(('NAMES %s'):format(args[1]))
  end
end)
IRCClient:add_handler('353', function(self, prefix, args, trail)
  local channel = args[3]
  local statuses = self.server.caps.PREFIX and self.server.caps.PREFIX:match('%(.-%)(.+)' or "+@")
  statuses = "[" .. statuses:gsub("%p", "%%%1") .. "]"
  for text in trail:gmatch('%S+') do
    local status, pre, nick, user, host
    if text:match(statuses) then
      status, pre = text:match(('^(%s+)(.+)'):format(statuses))
    else
      status, pre = '', text
    end
    if self.server.ircv3_caps['userhost-in-names'] then
      nick, user, host = pre:match('^(.-)!(.-)@(.-)$')
    else
      nick = pre
    end
    if not self.users[nick] then
      self.users[nick] = {
        channels = { }
      }
    end
    if user then
      self.users[nick].user = user
    end
    if host then
      self.users[nick].host = host
    end
    if self.channels[channel].users[nick] then
      if self.users[nick].channels[channel] then
        self.users[nick].channels[channel].status = status
      else
        self.users[nick].channels[channel] = {
          status = status
        }
      end
    else
      self.channels[channel].users[nick] = self.users[nick]
      self.users[nick].channels[channel] = {
        status = status
      }
    end
  end
end)
IRCClient:add_handler('352', function(self, prefix, args)
  local _, user, host, nick, away
  _, user, host, _, nick, away = unpack(args)
  if not self.users[nick] then
    self.users[nick] = {
      channels = { }
    }
  end
  self.users[nick].user = user
  self.users[nick].host = host
  self.users[nick].away = away:sub(1, 1) == "G"
end)
IRCClient:add_handler('CHGHOST', function(self, prefix, args)
  local nick = prefix:match('^(.-)!')
  self.users[nick].user = args[1]
  self.users[nick].host = args[2]
end)
IRCClient:add_handler('KICK', function(self, prefix, args)
  local channel = args[1]
  local nick = args[2]
  self.users[nick].channels[channel] = nil
  if #self.users[nick].channels == 0 then
    self.users[nick] = nil
  end
end)
IRCClient:add_handler('PART', function(self, prefix, args)
  local channel = args[1]
  local nick = prefix:match('^(.-)!')
  self.users[nick].channels[channel] = nil
  if #self.users[nick].channels == 0 then
    self.users[nick] = nil
  end
end)
IRCClient:add_handler('QUIT', function(self, prefix, args)
  local nick = prefix:match('^(.-)!')
  for channel in pairs(self.users[nick].channels) do
    self.channels[channel].users[nick] = nil
  end
  self.users[nick] = nil
end)
return IRCClient:add_handler('CAP', function(self, prefix, args, trailing)
  local to_process
  if args[2] == 'LS' or args[2] == 'ACK' or args[2] == 'NAK' then
    to_process = { }
  end
  if args[2] == 'LS' or args[2] == 'ACK' or args[2] == 'NEW' or args[2] == 'DEL' then
    for item in trailing:gmatch('%S+') do
      for _index_0 = 1, #caps do
        local cap = caps[_index_0]
        if item == cap then
          to_process[#to_process + 1] = cap
        end
      end
    end
  end
  if args[2] == 'LS' then
    if #to_process > 0 then
      self:send_raw(('CAP REQ :%s'):format(table.concat(to_process, ' ')))
    end
    for i = #to_process + 1, #caps do
      self:fire_hook('ACK_CAP')
    end
  elseif args[2] == 'NEW' then
    local to_send = { }
    for item in trailing:gmatch('%S+') do
      for _index_0 = 1, #caps do
        local cap = caps[_index_0]
        if item == cap then
          to_send[#to_send + 1] = item
        end
      end
    end
    return self:send_raw(('CAP REQ :%s'):format(table.concat(to_send, ' ')))
  elseif args[2] == 'DEL' then
    for item in trailing:gmatch('%S+') do
      self.ircv3_caps[item] = nil
    end
  elseif args[2] == 'ACK' then
    for _index_0 = 1, #to_process do
      local cap = to_process[_index_0]
      local key, value = cap:match('^(.-)=(.+)')
      if value then
        self.server.ircv3_caps[key] = value
      else
        self.server.ircv3_caps[cap] = true
      end
      self:fire_hook('ACK_CAP')
    end
  end
end)
