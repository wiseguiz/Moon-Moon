local cqueues = require('cqueues')
local set_caps = 0
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
      if time > last_connect + 30 then
        return self:connect()
      else
        return cqueues.sleep(last_connect + 30 - time)
      end
    end
  },
  hooks = {
    ['CONNECT'] = function(self)
      last_connect = os.time()
      self:send_raw('CAP LS 302')
      if not self:fire_hook('CAP_LS') then
        return self:send_raw('CAP END')
      end
    end,
    ['REQ_CAP'] = function(self)
      set_caps = set_caps + 1
    end,
    ['ACK_CAP'] = function(self)
      set_caps = set_caps - 1
      if set_caps == 0 then
        return self:send_raw('CAP END')
      end
    end
  }
}
