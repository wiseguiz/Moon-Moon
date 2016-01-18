local Logger = require('logger')
local serve_self
serve_self = function(self)
  return setmetatable(self, {
    __call = function(self)
      return pairs(self)
    end
  })
end
return {
  handlers = {
    ['001'] = function(self)
      self.channels = serve_self({ })
      self.users = serve_self({ })
      self.server = {
        caps = { }
      }
    end,
    ['005'] = function(self, prefix, args)
      local caps = {
        select(2, unpack(args))
      }
      for _, cap in pairs(caps) do
        if cap:find("=") then
          local key, value = cap:match('^(.-)=(.+)')
          self.server.caps[key] = value
        else
          self.server.caps[cap] = true
        end
      end
    end,
    ['JOIN'] = function(self, prefix, args, trail)
      local channel = trail or args[1]
      local nick, username, host = prefix:match('^(.-)!(.-)@(.-)$')
      if prefix:match('^.-!.-@.-$') then
        nick, username, host = prefix:match('^(.-)!(.-)@(.-)$')
        if not self.users[nick] then
          self.users[nick] = {
            channels = {
              [channel] = {
                status = ""
              }
            },
            username = username,
            host = host
          }
        else
          self.users[nick].channels = {
            [channel] = {
              status = ""
            }
          }
        end
      end
      if not self.channels[channel] then
        self.channels[channel] = {
          users = {
            [nick] = self.users[nick]
          }
        }
      end
    end,
    ['MODE'] = function(self, prefix, args)
      if args[1]:sub(1, 1) == "#" then
        return self:send_raw(('NAMES %s'):format(args[1]))
      end
    end,
    ['353'] = function(self, prefix, args, trail)
      local channel = args[3]
      local statuses = self.server.caps.PREFIX and self.server.caps.PREFIX:match('%(.-%)(.+)' or "+@")
      statuses = "^[" .. statuses:gsub("%[%]%(%)%.%+%-%*%?%^%$%%", "%%%1") .. "]"
      for text in trail:gmatch('%S+') do
        local status, nick
        if text:match(statuses) then
          status, nick = text:match('^(.)(.+)')
        else
          status, nick = '', text
        end
        if not self.users[nick] then
          self.users[nick] = {
            channels = { }
          }
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
    end,
    ['KICK'] = function(self, prefix, args)
      local channel = args[1]
      local nick = args[2]
      self.users[nick].channesl[channel] = nil
      if #self.users[nick].channels == 0 then
        self.users[nick] = nil
      end
    end,
    ['PART'] = function(self, prefix, args)
      local channel = args[1]
      local nick = prefix:match('^(.-)!')
      self.users[nick].channels[channel] = nil
      if #self.users[nick].channels == 0 then
        self.users[nick] = nil
      end
    end,
    ['QUIT'] = function(self, prefix, args)
      local channel = args[1]
      local nick = prefix:match('^(.-)!')
      for channel in pairs(self.users[nick].channels) do
        self.channels[channel].users[nick] = nil
      end
      self.users[nick] = nil
    end
  }
}
