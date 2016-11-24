local cqueues = require('cqueues')
local IRCClient
IRCClient = require('irc').IRCClient
IRCClient:add_handler('001', function(self)
  if self.config.autojoin then
    local _list_0 = self.config.autojoin
    for _index_0 = 1, #_list_0 do
      local channel = _list_0[_index_0]
      self:send_raw(("JOIN %s"):format(channel))
    end
  end
end)
IRCClient:add_handler('PING', function(self, sender, args, last)
  return self:send_raw(("PONG :%s"):format(last))
end)
IRCClient:add_handler('ERROR', function(self)
  local time = os.time()
  if time > self.data.last_connect + 30 then
    return self:connect()
  else
    return cqueues.sleep(self.data.last_connect + 30 - time)
  end
end)
return IRCClient:add_handler('433', function(self)
  if not self.data.nick_test then
    self.data.nick_test = 0
  end
  self.data.nick_test = self.data.nick_test + 1
  cqueues.sleep(0.5)
  if self.data.nick_test >= 30 then
    return self:disconnect()
  else
    return self:send_raw(('NICK %s[%d]'):format(self.config.nick, self.data.nick_test))
  end
end)
