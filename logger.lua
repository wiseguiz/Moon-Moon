local _print = print
local colors = {
  [0] = 15,
  [1] = 0,
  [2] = 4,
  [3] = 2,
  [4] = 1,
  [5] = 3,
  [6] = 5,
  [7] = 3,
  [8] = 11,
  [9] = 10,
  [10] = 6,
  [11] = 14,
  [12] = 12,
  [13] = 13,
  [14] = 8,
  [15] = 7
}
local level = {
  error = '\00304',
  reset = '\003',
  warn = '\00308',
  okay = '\00303',
  fatal = '\00305',
  debug = '\00306'
}
local _debug, _color = false, true
local set_debug
set_debug = function(value)
  _debug = not not value
end
local set_color
set_color = function(value)
  _color = not not value
end
local color_to_xterm
color_to_xterm = function(line)
  return line:gsub('\003(%d%d?),(%d%d?)', function(fg, bg)
    fg, bg = tonumber(fg), tonumber(bg)
    if colors[fg] and colors[bg] then
      return '\27[38;5;' .. colors[fg] .. ';48;5;' .. colors[bg] .. 'm'
    end
  end):gsub('\003(%d%d?)', function(fg)
    fg = tonumber(fg)
    if colors[fg] then
      return '\27[38;5;' .. colors[fg] .. 'm'
    end
  end):gsub('[\003\015]', function()
    return '\27[0m'
  end) .. '\27[0m'
end
local print
print = function(line)
  local output_line
  if _color then
    output_line = color_to_xterm(os.date('[%X]'):gsub('.', function(ch)
      if ch:match('[%[%]:]') then
        return '\00311' .. ch .. '\003'
      else
        return '\00315' .. ch .. '\003'
      end
    end) .. ' ' .. tostring(line))
  else
    output_line = os.date('[%X] ') .. tostring(line)
  end
  return _print(output_line)
end
local debug
debug = function(line, default)
  if _debug then
    return print(line)
  elseif default then
    return print(default)
  end
end
return {
  set_debug = set_debug,
  set_color = set_color,
  debug = debug,
  print = print,
  level = level,
  colors = colors
}
