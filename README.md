## General Information

### Contributors

| Name            | Email                | GitHub Account |
| ----------------|----------------------|--------------- |
| Charles Heywood | charles@hashbang.sh  | ChickenNuggers |

### Project Information

Moon-Moon is an IRC bot run with the Lua programming language; however,
the syntax used in the development version is called 'MoonScript' - this
syntax can be compiled using Leafo's MoonScript program `moonc` and then
loaded as Lua bytecode.

The bot's core is based off of cqueues and is also compatible with the
[Astronomy](https://github.com/ChickenNuggers/Astronomy) framework. The
bot can also be run just by itself, however.

### Dependencies

[LuaRocks](https://luarocks.org) (recommended)

[MoonScript](https://moonscript.org) (development)

[Lua](http://www.lua.org)

[cqueues](http://25thandclement.com/~william/projects/cqueues.html)

[luafilesystem](https://keplerproject.github.io/luafilesystem/)

## Getting Started

### Installing Dependencies with LuaRocks

To install rocks locally, pass the `--local` flag to the `luarocks` command.
This downloads and installs rocks to a local directory without requiring
access to system directories. LuaRocks is recommended to allow for easy
installation of all the required software.

```sh
$ luarocks install cqueues
$ luarocks install luafilesystem
$ luarocks install moonscript # Optional
```

## The Coroutine System

Moon Moon takes advantage of a coroutine-based asynchronous system which
allows the software to have multiple things "running" at once - it's
almost like having a threaded program, without threads. This offers some
advantages:

 1. A single Lua state
 2. No callbacks
 3. Cleaner code base

Adding in a routine to the stack is simple, as demonstrated by the below
examples programmed in MoonScript and Lua for convenience:

**MoonScript**

```moonscript
cqueues = require 'cqueues'
stack   = require 'stack'

stack\wrap ->
	while true
		cqueues.sleep 5
		print 'Hello, World!'
```

**Lua**

```lua
local cqueues = require("cqueues")
local stack   = require("stack")
stack:wrap(function()
	while true do
		cqueues.sleep(5)
		print("Hello, World!")
	end
end)
```
