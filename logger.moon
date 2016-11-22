_print = print
colors = {
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
}
level = {
	error: '\00304',
	reset: '\003',
	warn:  '\00308',
	okay:  '\00303',
	fatal: '\00305',
	debug: '\00306'
}
_debug, _color = false, true

set_debug = (value)->
	_debug = not not value -- truthify it
set_color = (value)->
	_color = not not value

color_to_xterm = (line)->
	return line\gsub('\003(%d%d?),(%d%d?)', (fg, bg)->
		fg, bg = tonumber(fg), tonumber(bg)
		if colors[fg] and colors[bg]
			return '\27[38;5;' .. colors[fg] .. ';48;5;' .. colors[bg] .. 'm'
	)\gsub('\003(%d%d?)', (fg)->
		fg = tonumber(fg)
		if colors[fg]
			return '\27[38;5;' .. colors[fg] .. 'm'
	)\gsub('[\003\015]', ()->
		return '\27[0m'
	).. '\27[0m'

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
		print line
	elseif default
		print default

return :set_debug, :set_color, :debug, :print, :level, :colors
