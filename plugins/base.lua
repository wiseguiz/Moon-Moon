local cqueues = require('cqueues')
local last_connect
return {
  handlers = {
    ['001'] = function(self)
      if self.config.autojoin then
        for channel in self.config.autojoin:gmatch("[^,]+") do
          self:send_raw(("JOIN %s"):format(channel))
        end
      end
    end,
    ['PING'] = function(self, sender, args, last)
      return self:send_raw(("PONG %s"):format(last))
    end,
    ['ERROR'] = function(self, message)
      local time = os.time()
      if time > self.data.last_connect + 30 then
        return self:connect()
      else
        return cqueues.sleep(self.data.last_connect + 30 - time)
      end
    end,
    ['433'] = function(self)
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
    end
  },
  hooks = {
    ['CONNECT'] = function(self)
      if not self.data then
        self.data = { }
      end
      self.data.last_connect = os.time()
      self.data.set_caps = 0
      self:send_raw('CAP LS 302')
      if not self:fire_hook('LS_CAP') then
        return self:send_raw('CAP END')
      end
    end,
    ['REQ_CAP'] = function(self)
      self.data.set_caps = self.data.set_caps + 1
    end,
    ['ACK_CAP'] = function(self)
      self.data.set_caps = self.data.set_caps - 1
      if self.data.set_caps == 0 then
        return self:send_raw('CAP END')
      end
    end
  }
}
