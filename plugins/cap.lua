return {
  handlers = {
    ['CAP'] = function(self, prefix, args, trail)
      if args[2] == "DEL" then
        for cap in trail:gmatch('%S+') do
          self.server.ircv3_caps[cap] = nil
        end
      elseif args[2] == "NEW" then
        return self:send_raw('CAP LS')
      end
    end
  }
}
