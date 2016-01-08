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
  }
}
