local Logger = require('logger')
local batches = {
  netjoin = { },
  netsplit = { }
}
local patterns = {
  JOIN = "\00308[\003%s\00308]\003 \00309>\003 %s",
  MODE = "\00308[\003%s\00308]\003 Mode %s by %s",
  KICK = "\00308[\003%s\00308]\003 %s kicked %s",
  KICK_2 = "\00308[\003%s\00308]\003 %s kicked %s \00315(%s)",
  PART = "\00308[\003%s\00308]\003 \00304<\003 %s",
  PART_2 = "\00308[\003%s\00308]\003 \00304<\003 %s \00315(%s)",
  QUIT = "\00311<\003%s\00311>\003 \00304<\003",
  QUIT_2 = "\00311<\003%s\00311>\003 \00304<\003 \00315(%s)",
  ACTION = "\00308[\003%s\00308]\003 * %s %s",
  ACTION_2 = "* %s %s",
  PRIVMSG = "\00311<\00308[\003%s\00308]\003%s\00311>\003 %s",
  PRIVMSG_2 = "\00311<\003%s\00311>\003 %s",
  NOTICE = "\00311-\00308[\003%s\00308]\003%s\00311-\003 %s",
  NOTICE_2 = "\00311-\003%s\00311-\003 %s",
  INVITE = "\00308[\003%s\00308]\003 %s invited %s",
  NETJOIN = "\00308[\003%s\00308]\003 \00309>\003 (%s)",
  NETSPLIT = "\00304<\003 (%s)"
}
local serve_self
serve_self = function(self)
  return setmetatable(self, {
    __call = function(self)
      return pairs(self)
    end
  })
end
local caps = {
  'echo-message',
  'invite-notify'
}
return {
  hooks = {
    ['NETJOIN'] = function(self)
      local channels = { }
      local _list_0 = batches.netjoin
      for _index_0 = 1, #_list_0 do
        local user = _list_0[_index_0]
        local channel, prefix = next(user)
        if not channels[channel] then
          channels[channel] = { }
        end
        table.insert(channels[channel], prefix:match('^(.-)!') or prefix)
      end
      for channel, channel_user_list in pairs(channels) do
        Logger.log(patterns.NETJOIN:format(channel, table.concat(channel_user_list, ', ')))
      end
    end,
    ['NETSPLIT'] = function(self)
      return Logger.log(patterns.NETSPLIT:format(table.concat(batches.netsplit, ', ')))
    end,
    ['LS_CAP'] = function(self)
      for i = 1, #caps do
        self:fire_hook('REQ_CAP')
      end
    end
  },
  handlers = {
    ['JOIN'] = function(self, prefix, args, trail, tags)
      if tags == nil then
        tags = { }
      end
      local channel = args[1] or trail
      if not tags.batch then
        return Logger.print(patterns.JOIN:format(channel, prefix:match('^(.-)!') or prefix))
      else
        local _list_0 = self.server.batches
        for _index_0 = 1, #_list_0 do
          local name, batch = _list_0[_index_0]
          if name == tags.batch and batch[1] == 'netjoin' then
            if #self.server.batches[name].gc > 0 then
              table.insert(self.server.batches[batch].gc, function()
                self:fire_hook('NETJOIN')
                batches.netjoin = { }
              end)
            end
            batches.netjoin[#batches.netjoin + 1] = {
              [channel] = prefix
            }
          end
        end
      end
    end,
    ['NICK'] = function(self, prefix, args, trail)
      local old = prefix:match('^(.-)!') or prefix
      local new = args[1] or trail
      return Logger.print(('%s \00309>>\003 %s'):format(old, new))
    end,
    ['MODE'] = function(self, prefix, args, trailing)
      local channel = args[1]
      table.remove(args, 1)
      if channel:sub(1, 1) == "#" then
        return Logger.print(patterns.MODE:format(channel, table.concat(args, " "), prefix:match('^(.-)!') or prefix))
      end
    end,
    ['KICK'] = function(self, prefix, args, trailing)
      local channel = args[1]
      local nick = args[2]
      local kicker = prefix:match('^(.-)!') or prefix
      if trailing then
        return Logger.print(patterns.KICK_2:format(channel, kicker, nick, trailing))
      else
        return Logger.print(patterns.KICK:format(channel, kicker, nick))
      end
    end,
    ['PART'] = function(self, prefix, args, trailing)
      local channel = args[1]
      local nick = prefix:match('^(.-)!') or prefix
      if trailing then
        return Logger.print(patterns.PART_2:format(channel, nick, trailing))
      else
        return Logger.print(patterns.PART:format(channel, nick))
      end
    end,
    ['QUIT'] = function(self, prefix, args, trailing, tags)
      if tags == nil then
        tags = { }
      end
      local nick = prefix:match('^(.-)!') or prefix
      if tags.batch then
        for name, batch in pairs(self.server.batches) do
          if name == tags.batch and tags.batch[1] == 'netsplit' then
            if #self.server.batches[name].gc > 0 then
              table.insert(self.server.batches[batch].gc, function()
                self:fire_hook('NETSPLIT')
                batches.netsplit = { }
              end)
            end
            batches.netsplit[#batches.netsplit + 1] = nick
          end
        end
      else
        if trailing then
          return Logger.print(patterns.QUIT_2:format(nick, trailing))
        else
          return Logger.print(patterns.QUIT:format(nick))
        end
      end
    end,
    ['PRIVMSG'] = function(self, prefix, args, trailing)
      local nick = prefix:match('^(.-)!') or prefix
      if not args[1]:sub(1, 1) == '#' then
        if trailing:match("^\001ACTION .-\001$") then
          return Logger.print(patterns.ACTION_2:format(nick, trailing:match('^%S+%s+(.+)')))
        elseif not trailing:match('^\001') then
          return Logger.print(patterns.PRIVMSG_2:format(nick, trailing))
        end
      else
        local ch = args[1]
        if trailing:match("^\001ACTION .-\001$") then
          return Logger.print(patterns.ACTION:format(ch, nick, trailing:match('^%S+%s+(.+)')))
        elseif not trailing:match('^\001') then
          return Logger.print(patterns.PRIVMSG:format(ch, nick, trailing))
        end
      end
    end,
    ['NOTICE'] = function(self, prefix, args, trailing)
      if trailing:sub(1, 1) == '\001' then
        return 
      end
      local nick = prefix:match('^(.-)!') or prefix
      if args[1]:sub(1, 1) == '#' then
        return Logger.print(patterns.NOTICE:format(args[1], nick, trailing))
      else
        return Logger.print(patterns.NOTICE_2:format(nick, trailing))
      end
    end,
    ['INVITE'] = function(self, prefix, args, trailing)
      local nick = prefix:match('^(.-)!') or prefix
      local channel = args[2]
      return Logger.print(patterns.INVITE:format(channel, nick, args[1]))
    end,
    ['CAP'] = function(self, prefix, args, trailing)
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
    end
  }
}
