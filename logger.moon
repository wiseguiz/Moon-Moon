_print = print
colors = setmetatable({
	[0]:  15, -- white
	[1]:  0,  -- black
	[2]:  4,  -- blue
	[3]:  2,  -- green
	[4]:  1,  -- red
	[5]:  3,  -- brown
	[6]:  5,  -- purple
	[7]:  3,  -- orange
	[8]:  11, -- yellow
	[9]:  10, -- light green
	[10]: 6,  -- teal
	[11]: 14, -- cyan
	[12]: 12, -- light blue
	[13]: 13, -- pink
	[14]: 8,  -- gray
	[15]: 7  -- light gray
}, __index: ()-> 0)
level = {
	error: '\00304'
	reset: '\003'
	warn:  '\00308'
	okay:  '\00303'
	fatal: '\00305'
	debug: '\00310'
}
_debug, _color = false, true

set_debug = (value)->
	_debug = not not value -- truthify it
set_color = (value)->
	_color = not not value

color_to_xterm = (line)->
	local fg, bg
	is_bold = false
	return line\gsub('\003(%d%d?),(%d%d?)', (tfg, tbg)->
		fg, bg = tonumber(tfg), tonumber(tbg)
		return '\27[38;5;' .. colors[fg] .. ';48;5;' .. colors[bg] .. 'm'
	)\gsub('\003(%d%d?)', (tfg)->
		bg = nil
		fg = tonumber(tfg)
		if colors[fg]
			return '\27[38;5;' .. colors[fg] .. 'm'
	)\gsub('[\003\015]', (char)->
		fg, bg = nil, nil
		if char == '\015' or not is_bold
			return '\27[0m'
		else
			return '\27[0;1m'
	)\gsub('\002', ()->
		is_bold = not is_bold
		if is_bold
			return '\27[1m'
		else
			if fg and bg
				return ('\27[0;38;5;%s;48;5;%sm')\format colors[fg], colors[bg]
			elseif fg
				return ('\27[0;38;5;%sm')\format colors[fg]
			else
				return '\27[0m'
	) .. '\27[0m'

print = (line)->
	local output_line
	if _color
		output_line = color_to_xterm os.date('[%X]')\gsub('.', (ch)->
			if ch\match '[%[%]:]'
				return '\00311' .. ch .. '\003'
			else
				return '\00315' .. ch .. '\003'
		) .. ' ' .. tostring line
	else
		output_line = os.date('[%X] ') .. tostring line
	
	_print output_line

debug = (line, default)->
	if _debug
		print level.debug .. line
	elseif default
		print default

return :set_debug, :set_color, :debug, :print, :level, :colors
