local set_caps = 0
return {
  handlers = {
    ['001'] = function(self)
      if self.config.autojoin then
        for channel in self.config.autojoin:gmatch("[^,]+") do
          self:send_raw(("JOIN %s"):format(channel))
        end
      end
    end,
    PING = function(bot, sender, args, last)
      return bot:send_raw(("PONG %s"):format(last))
    end
  },
  hooks = {
    ['CONNECT'] = function(self)
      self:send_raw('CAP LS')
      if not self:fire_hook('CAP_LS') then
        return self:send_raw('CAP END')
      end
    end,
    ['REG_CAP'] = function(self)
      set_caps = set_caps + 1
    end,
    ['ACK_CAP'] = function(self)
      set_caps = set_caps - 1
      if set_caps == 0 then
        return self:send_raw('CAP_END')
      end
    end
  }
}
