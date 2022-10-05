local websocket = require 'websocket.client_copas'
local json = require 'lunajson'
local zlib = require 'lunacord.zlib'
local dump = require 'lunacord.dump'

local gateway_uri = "wss://gateway.discord.gg/?encoding=json&v=9&compress=zlib-stream"
local ssl_params = { mode = "client", protocol = "any" }

local DS = {}

-- Connect to the gateway
function DS:connect()
  self.ws = websocket()
  self.stream = zlib.stream()

  local sucess, err, res = self.ws:connect(gateway_uri, nil, ssl_params)
  if not sucess then
    error(dump.dump("[lunacord] WebSocket connection error: " .. err .. "\nresponse headers:",
      res
    ))
  end
  dump("res", res)

  -- receive hello
  --   start heartbeat loop
  -- identify

end

--- Receive a raw payload from the websocket
--- @param self table   The DiscordSocket to receive on
--- @return table data  The received payload
--- @nodiscard
local function websocket_receive(self)
  local payload, opcode, was_clean, code, reason = self.ws:receive()

  if payload then
    local data
    if opcode == 1 then -- text frame
      data = json.decode(payload)
    elseif opcode == 2 then -- binary frame (zlib compressed)
      local decomp = self.stream:decompress(payload)
      data = json.decode(decomp)
    else
      error("[lunacord] invalid opcode: " .. tostring(opcode))
    end
    print("\treceive: " .. tostring(data))
    return data
  else
    error(dump.dump("[lunacord] WebSocket disconnected", {
      was_clean = was_clean,
      code = code,
      reason = reason
    }))
  end
end

--- Receive an event from the gateway
--- @return table data The received event payload
--- @nodiscard
function DS:receive()
  local event = websocket_receive(self)

  return event
end

function DS:send(data)
  local encoded = json.encode(data)
  print("\tsending: " .. tostring(encoded))
  self.ws:send(encoded)
end

return function()
  return setmetatable({}, { __index = DS })
end
