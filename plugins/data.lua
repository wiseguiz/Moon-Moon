local Logger = require('logger')
local print = Logger.debug
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
      return print('Resetting channels, users, and server')
    end,
    ['005'] = function(self, prefix, args)
      print('Reading capabilities')
      for _, cap in pairs(args) do
        if cap:find("=") then
          local key, value = cap:match('^(.-)=(.+)')
          self.server.caps[key] = value
          print(("%s: %s"):format(key, value))
        else
          self.server.caps[cap] = true
          print(cap)
        end
      end
    end,
    ['JOIN'] = function(self, prefix, args, trail)
      local channel = trail or args[1]
      local nick, username, host = prefix:match('^(.-)!(.-)@(.-)$')
      if prefix:match('^.-!.-@.-$') then
        nick, username, host = prefix:match('^(.-)!(.-)@(.-)$')
        if not self.users[nick] then
          print('Registering user ' .. nick)
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
        print('Registering channel ' .. channel)
        self.channels[channel] = {
          users = {
            [nick] = self.users[nick]
          }
        }
      end
    end,
    ['MODE'] = function(self, prefix, args)
      print('Received mode change: ' .. table.concat(args, ", "))
      if prefix[1] == "#" then
        return self:send_raw(('NAMES'):format(args[1]))
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
        if self.channels[channel].users[nick] then
          if self.users[nick].channels[channel] then
            print(('Setting status of %s in %s to %s'):format(nick, channel, status))
            self.users[nick].channels[channel].status = status
          else
            self.users[nick].channels[channel] = {
              status = status
            }
          end
        else
          print(('Registering user %s of %s for status %s'):format(nick, channel, status))
          self.channels[channel].users[nick] = {
            channels = {
              [channel] = {
                status = status
              }
            }
          }
        end
      end
    end,
    ['PART'] = function(self, prefix, args)
      local channel = args[1]
      local nick = prefix:match('^(.-)!')
      self.users[nick].channels[channel] = nil
      if #self.users[nick].channels == 0 then
        print(('Garbaging user %s'):format(nick))
        self.users[nick] = nil
      end
    end,
    ['QUIT'] = function(self, prefix, args)
      local channel = args[1]
      local nick = prefix:match('^(.-)!')
      for channel in self.users[nick].channels do
        print(('Removing %s from %s'):format(nick, channel))
        self.channels[channel].users[nick] = nil
      end
      print(('Garbaging user %s'):format(nick))
      self.users[nick] = nil
    end
  }
}
