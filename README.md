# Lunacord
A simple, convenient Discord bot library written in pure Lua.  
Everything from receiving gateway events to fetching and caching objects is handled by the library, allowing you to just focus on writing your Discord bot.  


## Status
currently, the library is still in development and cannot be used to write a bot.  

## Installation
Lunacord depends on an updated fork of [lua-websockets](https://github.com/Penguin-Spy/lua-websockets), and therefore requires [OpenSSL](https://github.com/openssl/openssl#build-and-install) to be installed. (see `windows.md` if relevant)  
```
git clone git://github.com/Penguin-Spy/lunacord.git
cd lunacord
luarocks make lua-websockets-scm-1.rockspec
luarocks make lunacord-scm-1.rockspec
```

## Usage
```lua
local lunacord = require 'lunacord'

-- Create a new client with the bot's token
local client = lunacord.client("token")

-- Register a callback for the Message Create event
client:on("MESSAGE_CREATE", function(msg)
  print("received message by " .. msg.author.username .. " with content: ", msg.content)
end)

-- Finally, start the copas loop to connect & run the bot
lunacord.run()
```
