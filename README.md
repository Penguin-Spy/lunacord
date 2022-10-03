# Lunacord
A simple, convenient Discord bot library written in pure Lua.  
All caching is handled by the library, allowing you to just focus on writing your Discord bot.  


## Status
currently, the library is still in development and cannot be used to write a bot.  

## Installation
```
git clone https://github.com/Penguin-Spy/lunacord
cd lunacord
luarocks make lunacord-scm-1.rockspec
```

## Usage
```lua
local lunacord = require 'lunacord'

local client = lunacord.client()
client:connect("the token")
```
