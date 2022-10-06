# Lunacord
A simple, convenient Discord bot library written in pure Lua.  
All caching is handled by the library, allowing you to just focus on writing your Discord bot.  


## Status
currently, the library is still in development and cannot be used to write a bot.  

## Installation
Lunacord depends on an updated fork of [lua-websockets](https://github.com/Penguin-Spy/lua-websockets), and therefore requires [OpenSSL](https://github.com/openssl/openssl#build-and-install) to be installed.  
```
git clone git://github.com/Penguin-Spy/lunacord.git
cd lunacord
luarocks make lua-websockets-scm-1.rockspec
luarocks make lunacord-scm-1.rockspec
```

## Usage
```lua
local lunacord = require 'lunacord'

local client = lunacord.client()
client:connect("the token")

lunacord.run()
```
