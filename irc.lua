local socket = require('cqueues.socket')
local Logger = require('logger')
local IRCConnection
do
  local _class_0
  local _base_0 = {
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
    end,
    connect = function(self)
      if self.socket then
        self.socket:shutdown()
      end
      local host = self.config.server
      local port = self.config.port
      local debug_msg = ('Connecting... {host: "%s", port: "%s"}'):format(host, port)
      Logger.debug(debug_msg, Logger.level.warn .. '--- Connecting...')
      self.socket = assert(socket.connect({
        host = host,
        port = port
      }))
      if self.config.ssl then
        Logger.debug('Starting TLS exchange...')
        self.socket:starttls()
        Logger.debug('Started TLS exchange')
      end
      Logger.print(Logger.level.okay .. '--- Connected')
      local nick = self.config.nick or 'Moonmoon'
      local user = self.config.username or 'moon'
      local real = self.config.realname or 'Moon Moon: MoonScript IRC Bot'
      Logger.print(Logger.level.warn .. '--- Sending authentication data')
      self:send_raw(('NICK %s'):format(nick))
      self:send_raw(('USER %s * * :%s'):format(user, real))
      debug_msg = ('Sent authentication data: {nickname: %s, username: %s, realname: %s}'):format(nick, user, real)
      return Logger.debug(debug_msg, Logger.level.okay .. '--- Sent authentication data')
    end,
    send_raw = function(self, ...)
      return self.socket:write(table.concat({
        ...
      }, ' ') .. '\n')
    end,
    send = function(self, name, pattern, ...)
      return self.senders[name](pattern:format(...))
    end,
    parse = function(self, message)
      local prefix_end = 0
      local prefix = nil
      if message:sub(1, 1) == ":" then
        prefix_end = message:find(" ")
        prefix = message:sub(2, message:find(" ") - 1)
      end
      local trailing = nil
      local tstart = message:find(" :")
      if tstart then
        trailing = message:sub(tstart + 2)
      else
        tstart = #message
      end
      local rest = (function(segment)
        local t = { }
        for word in segment:gmatch("%S+") do
          table.insert(t, word)
        end
        return t
      end)(message:sub(prefix_end + 1, tstart))
      local command = rest[1]
      table.remove(rest, 1)
      return prefix, command, rest, trailing
    end,
    process = function(self, line)
      local prefix, command, args, rest = self:parse(line)
      Logger.debug(Logger.level.warn .. '--- | Line: ' .. line)
      if not self.handlers[command] then
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
        Logger.debug(Logger.level.okay .. '---  \\ Trailing: ' .. rest)
      end
      for _, handler in pairs(self.handlers[command]) do
        local ok, err = pcall(handler, self, prefix, args, rest)
        if not ok then
          Logger.debug(Logger.level.error .. ' *** ' .. err)
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
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, server, port, config)
      if port == nil then
        port = 6667
      end
      if config == nil then
        config = { }
      end
      assert(server)
      self.config = {
        server = server,
        port = port,
        config = config
      }
      for k, v in pairs(config) do
        self.config[k] = v
      end
      self.handlers = { }
      self.senders = { }
      self.server = { }
    end,
    __base = _base_0,
    __name = "IRCConnection"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  IRCConnection = _class_0
end
return IRCConnection
