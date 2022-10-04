local websocket = require 'websocket.client_copas'
local json = require 'lunajson'
local zlib = require 'lunacord.zlib'
local dump = require 'lunacord.dump'

local gateway_uri = "wss://gateway.discord.gg/?encoding=json&v=9&compress=zlib-stream"
--local gateway_uri = "ws://localhost:8080/"
local ssl_params = { mode = "client", protocol = "any" }

local DS = {}

function DS:connect()
  self.ws = websocket()

  local sucess, err, res = self.ws:connect(gateway_uri, nil, ssl_params)
  if not sucess then
    error(dump.dump("[lunacord] WebSocket connection error: " .. err .. "\nresponse headers:",
      res
    ))
  end
  dump("res", res)
end

--- @return table data The recieved event payload
--- @nodiscard
function DS:receive()
  local payload, opcode, was_clean, code, reason = self.ws:receive()
  if payload then
    dump(payload, opcode)
    local data
    if opcode == 1 then -- text frame
      data = json.decode(payload)
    elseif opcode == 2 then -- binary frame (zlib compressed)
      data = json.decode(zlib.decompress(payload))
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

function DS:send(data)
  local encoded = json.encode(data)
  print("\tsending: " .. tostring(encoded))
  self.ws:send(encoded)
end

return function()
  return setmetatable({}, { __index = DS })
end
