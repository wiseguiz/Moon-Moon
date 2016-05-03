local socket = require('cqueues.socket')
local Logger = require('logger')
local escapers = {
  ['s'] = ' ',
  ['r'] = '\r',
  ['n'] = '\n',
  [';'] = ';'
}
local IRCClient
do
  local _class_0
  local _base_0 = {
    handlers = { },
    senders = { },
    hooks = { },
    add_hook = function(self, id, hook)
      if not self.hooks[id] then
        self.hooks[id] = {
          hook
        }
      else
        return table.insert(self.hooks[id], hook)
      end
    end,
    add_handler = function(self, id, handler)
      if not self.handlers[id] then
        self.handlers[id] = {
          handler
        }
      else
        return table.insert(self.handlers[id], handler)
      end
    end,
    add_sender = function(self, id, sender)
      assert(not self.senders[id], "Sender already exists: " .. id)
      self.senders[id] = sender
    end,
    load_modules = function(self, modules)
      if modules.senders then
        for id, sender in pairs(modules.senders) do
          self:add_sender(id, sender)
        end
      end
      if modules.handlers then
        for id, handler in pairs(modules.handlers) do
          self:add_handler(id, handler)
        end
      end
      if modules.hooks then
        for id, hook in pairs(modules.hooks) do
          self:add_hook(id, hook)
        end
      end
    end,
    clear_modules = function(self)
      self.senders = { }
      self.handlers = { }
      self.hooks = { }
    end,
    connect = function(self)
      if self.socket then
        self.socket:shutdown()
      end
      local host = self.config.server
      local port = self.config.port
      local ssl = self.config.ssl
      local debug_msg = ('Connecting... {host: "%s", port: "%s"}'):format(host, port)
      if not self.config.nick then
        self.config.nick = 'Moon-Moon'
      end
      if not self.config.username then
        self.config.username = 'Mooooon'
      end
      if not self.config.realname then
        self.config.realname = 'Moon Moon: MoonScript IRC Bot'
      end
      Logger.debug(debug_msg, Logger.level.warn .. '--- Connecting...')
      self.socket = assert(socket.connect({
        host = host,
        port = port
      }))
      if ssl then
        Logger.debug('Starting TLS exchange...')
        self.socket:starttls()
        Logger.debug('Started TLS exchange')
      end
      Logger.print(Logger.level.okay .. '--- Connected')
      self:fire_hook('CONNECT')
      local nick = self.config.nick
      local user = self.config.username
      local real = self.config.realname
      local pass = self.config.password
      Logger.print(Logger.level.warn .. '--- Sending authentication data')
      self:send_raw(('NICK %s'):format(nick))
      if pass and ssl then
        Logger.debug('*** Sending password')
        self:send_raw(('PASS :%s'):format(pass))
      elseif pass then
        Logger.print(Logger.level.error .. '*** Not sending password: TLS not enabled ***')
      end
      self:send_raw(('USER %s * * :%s'):format(user, real))
      debug_msg = ('Sent authentication data: {nickname: %s, username: %s, realname: %s}'):format(nick, user, real)
      return Logger.debug(debug_msg, Logger.level.okay .. '--- Sent authentication data')
    end,
    disconnect = function(self)
      if self.socket then
        self.socket:shutdown()
      end
      return self:fire_hook('DISCONNECT')
    end,
    send_raw = function(self, ...)
      self.socket:write(table.concat({
        ...
      }, ' ') .. '\n')
      return Logger.debug('==> ' .. table.concat({
        ...
      }, ' '))
    end,
    send = function(self, name, pattern, ...)
      return self.senders[name](pattern:format(...))
    end,
    date_pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+).(%d+)Z",
    parse_time = function(self, datestring)
      local year, month, day, hour, min, sec, mil = datestring:match(self.date_pattern)
      return os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec
      }) + tonumber(mil) / 1000
    end,
    parse_tags = function(self, tag_message)
      local cur_name
      local tags = { }
      local charbuf = { }
      local pos = 1
      while pos < #tag_message do
        if tag_message:match('^\\', pos) then
          local lookahead = tag_message:sub(pos + 1, pos + 1)
          charbuf[#charbuf + 1] = escapers[lookahead] or lookahead
          pos = pos + 2
        elseif cur_name then
          if tag_message:match("^;", pos) then
            tags[cur_name] = table.concat(charbuf)
            cur_name = nil
            charbuf = { }
            pos = pos + 1
          else
            charbuf[#charbuf + 1], pos = tag_message:match("([^\\;]+)()", pos)
          end
        else
          if tag_message:match("^=", pos) then
            if #charbuf > 0 then
              cur_name = table.concat(charbuf)
              charbuf = { }
            end
            pos = pos + 1
          elseif tag_message:match("^;", pos) then
            if #charbuf > 0 then
              tags[table.concat(charbuf)] = true
              charbuf = { }
            end
            pos = pos + 1
          else
            charbuf[#charbuf + 1], pos = tag_message:match("([^\\=;]+)()", pos)
          end
        end
      end
      return tags
    end,
    parse = function(self, message_with_tags)
      local message, tags
      if message_with_tags:sub(1, 1) == '@' then
        tags = self:parse_tags(message_with_tags:sub(2, message_with_tags:find(' ') - 1))
        message = message_with_tags:sub((message_with_tags:find(' ') + 1))
      else
        message = message_with_tags
      end
      local prefix_end = 0
      local prefix = nil
      if message:sub(1, 1) == ':' then
        prefix_end = message:find(' ')
        prefix = message:sub(2, message:find(' ') - 1)
      end
      local trailing = nil
      local tstart = message:find(' :')
      if tstart then
        trailing = message:sub(tstart + 2)
      else
        tstart = #message
      end
      local rest = (function(segment)
        local t = { }
        for word in segment:gmatch('%S+') do
          table.insert(t, word)
        end
        return t
      end)(message:sub(prefix_end + 1, tstart))
      local command = rest[1]
      table.remove(rest, 1)
      return prefix, command, rest, trailing, tags
    end,
    fire_hook = function(self, hook_name)
      if not self.hooks[hook_name] then
        return false
      end
      if IRCClient.hooks[hook_name] then
        for _, hook in pairs(IRCClient.hooks[hook_name]) do
          Logger.debug(Logger.level.warn .. '--- Running global hook: ' .. hook_name)
          local ok, err = pcall(hook, self)
          if not ok then
            Logger.print(Logger.level.error .. '*** ' .. err)
          end
        end
      end
      for _, hook in pairs(self.hooks[hook_name]) do
        Logger.debug(Logger.level.warn .. '--- Running hook: ' .. hook_name)
        local ok, err = pcall(hook, self)
        if not ok then
          Logger.print(Logger.level.error .. '*** ' .. err)
        end
      end
    end,
    process = function(self, line)
      local prefix, command, args, rest, tags = self:parse(line)
      Logger.debug(Logger.level.warn .. '--- | Line: ' .. line)
      if not self.handlers[command] or not IRCClient.handlers[command] then
        return 
      end
      Logger.debug(Logger.level.okay .. '--- |\\ Running trigger: ' .. Logger.level.warn .. command)
      if prefix then
        Logger.debug(Logger.level.okay .. '--- |\\ Prefix: ' .. prefix)
      end
      if #args > 0 then
        Logger.debug(Logger.level.okay .. '--- |\\ Arguments: ' .. table.concat(args, ', '))
      end
      if rest then
        Logger.debug(Logger.level.okay .. '--- |\\ Trailing: ' .. rest)
      end
      for _, handler in pairs(IRCClient.handlers[command]) do
        local ok, err = pcall(handler, self, prefix, args, rest, tags)
        if not ok then
          Logger.print(Logger.level.error .. '*** ' .. err)
        end
      end
      for _, handler in pairs(self.handlers[command]) do
        local ok, err = pcall(handler, self, prefix, args, rest, tags)
        if not ok then
          Logger.print(Logger.level.error .. '*** ' .. err)
        end
      end
    end,
    loop = function(self)
      local line
      local print_error
      print_error = function(err)
        return Logger.debug("Error: " .. err .. " (" .. line .. ")")
      end
      for received_line in self.socket:lines() do
        line = received_line
        xpcall(self.process, print_error, self, received_line)
      end
    end,
    log = function(self, line)
      return Logger.print('\00311(\003' .. (self.server.caps and self.server.caps['NETWORK'] or self.config.server) .. '\00311)\003 ' .. line)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, server, port, config)
      if port == nil then
        port = 6697
      end
      if config == nil then
        config = { }
      end
      assert(server)
      self.config = {
        server = server,
        port = port,
        config = config,
        ssl = port == 6697
      }
      for k, v in pairs(config) do
        self.config[k] = v
      end
      self.handlers = { }
      self.senders = setmetatable({ }, {
        __index = IRCClient.senders
      })
      self.server = { }
      self.hooks = { }
    end,
    __base = _base_0,
    __name = "IRCClient"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  IRCClient = _class_0
end
return {
  IRCClient = IRCClient
}
