## IRCConnection // API

## Functions

###`IRCConnection(server, port=6697, config={})`

**Description**

Stores data in a table which can be referred to as a "class" and returns
the table, which also includes the below listed functions.

**Parameters**

 * *server*: Hostname to use when connecting
 * *port*: Port to use when connecting
  - `6697` is used as the default and standard TLS por
 * *config*: Default configuration to use when connecting
  - `ssl`: use SSL or TLS when connecting
  - `autojoin`: Locations to automatically join on connect
  - `password`: Password to use - TLS/SSL connection only

**Returns**

 * _table_: A table containing all data needed to connect
  - This table also includes the functions in _IRCConnection_

###`IRCConnection:add_hook(id, hook)`

**Description**

Adds a hook, which can then later be fired by using `@fire_hook(id)`. Hooks do not overwrite each other.

**Parameters**

 * *id*: Hook ID to use when adding
 * *hook*: Function which acts as the 'hook'

**Returns**

 * _nil_

###`add_handler(id, handler)`

**Description**

Does the same thing as add_hook, however, handlers are fired on specific IRC commands such as `PRIVMSG`, `005`, `PING`, and other commands.

**Parameters**

 * *id*: Handler ID to use when adding
 * *handler* Function which acts as the 'handler'

**Returns**

 * _nil_

###`add_sender(id, sender)`

**Description**

Adds a sender which can then be used with `@send()`. Sender functions can be overwritten.

**Parameters**

 * *id*: Sender ID to use when adding
 * *sender*: Function which acts as the 'sender'

**Returns**

 * _nil_

###`load_modules(modules)`

**Description**

Takes a table of modules and caclls `add_sender`, `add_handler`, and `add_hook` respectively.

**Parameters**

 * *modules*: A table of modules, containing a field 'hooks', 'handlers', and 'senders' - all fields are optional

**Returns**

 * _nil_

###`clear_modules()`

**Description**

Removes all senders, handlers, and hooks

**Returns**

 * _nil_

###`connect()`

**Description**

Establishes an optionally nonblocking connection to the IRC server

**Returns**

 * _nil_

###`disconnect()`

**Description**

Disconnects from the IRC server

**Returns**

 * _nil_

###`send_raw(...)`

**Description**

Sends a space delimited set of strings to the server with a newline at the end

**Parameters**

 * `...`: A variable list of strings to send

**Returns**

 * _nil_

###`send(name, pattern, ...)`

**Description**

Sends data using a custom sending function

**Parameters**

 * *name*: Name of sender function to use
 * *pattern*: Pattern to use for formatting
 * `...`: Variable options for formatting

**Returns**

 * Return values of the sending function

###`parse_time(datestring)`

**Description**

Parses time from a `server-time`-compatible string

**Parameters**

 * *datestring*: A string in the format `%Y-%m-%dT%H:%M:%S.<milliseconds>Z`

**Returns**

 * (int) Time since system Epoch

###`parse_tags(tag_message)`

**Description**

Parses IRCv3 tags and returns a table list of values

**Parameters**

 * *tag_message*: Message to parse

**Returns**

 * _tags_: Table of tags from the message

###`parse(message_with_tags)`

**Description**

Separate an IRC message into command, argument, trailing, and tag values

**Parameters**

 * *message_with_tags*: IRC message

**Returns**

 * _prefix_: Who "sent" the message
 * _command_: The command sent; is never nil
 * _rest_: Table containing arguments
 * _trailing_: End of message, such as the message of a PRIVMSG
 * _tags_: IRCv3 tags

###`fire_hook(hook_name)`

**Description**

Runs all hook functions for `hook_name`

**Parameters**

 * *hook_name*: Name of hooks to be run

**Returns**

 * _nil_

###`process(line)`

**Description**

Runs handlers based off of the IRC received line

**Parameters**

 * *line*: Incoming IRC message

**Returns**

 * _nil_

###`loop()`

**Description**

Iterate through lines received from the server and process them

**Returns**

 * _nil_
