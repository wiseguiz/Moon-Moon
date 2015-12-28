import IRCConnection, Logger from require 'irc'
cqueues = require 'cqueues'

stack = cqueues.new!

-- ::TODO:: remove this section later

bot = IRCConnection 'irc.esper.net'
bot\connect!
stack\wrap ->bot\loop
stack\loop!
