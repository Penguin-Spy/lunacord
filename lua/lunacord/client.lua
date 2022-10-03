local websocket = require 'websocket.client'
local json = require 'lunajson'
local zlib = require 'lunacord.zlib'
local dump = require 'lunacord.dump'

--local gateway_uri = "wss://gateway.discord.gg/?encoding=json&v=9&compress=zlib-stream"
local gateway_uri = "wss://gateway.discord.gg/?encoding=json&v=9"
local ssl_params = { mode = "client", protocol = "any" }

-- the Client class
local Client = {}

--
--- Register an event handler
--- @param event string     Then name of the event
--- @param handler function The function to be called when the client recieves this event
--
function Client:on(event, handler)
  self.handlers[event] = handler
end

--
--- Connects to discord, handling all registered events. \
--- This method does not return until the client disconnects.
--- @param token string The bot token to authorize with
--- @return any code The disconnection code, or nil if the connection failed
--- @return string reason The provided reason for the disconnection
---
function Client:connect(token)
  dump(self)
  self.token = token
  self.ws = websocket.new()

  local sucess, err, res = self.ws:connect(gateway_uri, nil, ssl_params)
  if not sucess then
    print("[lunacord] websocket connection error: " .. err)
    print("response headers:")
    dump(res)
    return nil, "upgrade failed"
  end
  print("response headers:")
  dump(res)

  print("self after:")
  dump(self)

  while true do
    local payload, opcode, was_clean, code, reason = self.ws:receive()
    if payload then
      print("[" .. opcode .. "] " .. payload)
      --local decompressed = zlib.decompress(payload)
      --print(decompressed)
      --local data = json.decode(decompressed)
      local data = json.decode(payload)
      dump(data)
    else
      print("[Disconnected] was_clean=" .. tostring(was_clean) .. " code=" .. code .. " reason=" .. reason
      )
      return code, reason
    end
  end
end

-- class shenanegans (they're epic tho)
return function()
  return setmetatable({}, { __index = Client })
end
