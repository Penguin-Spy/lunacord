local websocket = require 'websocket.client_copas'
local json = require 'lunajson'
local copas = require("copas")
local timer = require("copas.timer")

local zlib = require 'lunacord.zlib'
local dump = require 'lunacord.dump'

local gateway_uri = "wss://gateway.discord.gg/?encoding=json&v=9&compress=zlib-stream"
local ssl_params = { mode = "client", protocol = "any" }

local DS = {}

--- Receive a raw payload from the websocket
--- @param self table   The DiscordSocket to receive on
--- @return table data  The received payload
--- @nodiscard
local function raw_receive(self)
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

--
--- Connect to the gateway
--- @param identify_data table  The data of the identify send event
--
function DS:connect(identify_data)
  self.ws = websocket()
  self.stream = zlib.stream()

  local sucess, err, res = self.ws:connect(gateway_uri, nil, ssl_params)
  if not sucess then
    error(dump.dump("[lunacord] WebSocket connection error: " .. err .. "\nresponse headers:",
      res
    ))
  end
  self.last_sequence = nil -- pretty sure json will serialize this to `null`

  -- receive & handle hello event
  local hello = raw_receive(self)
  dump("hello", hello)
  if hello and hello.op == 10 then
    local heartbeat_interval = hello.d.heartbeat_interval
    dump("heartbeat_interval", heartbeat_interval)

    --copas.addnamedthread("lunacord_heartbeat", function()
    local delay = heartbeat_interval / 1000
    local initial_delay = math.random() * delay * 0.5
    dump {
      delay = delay,
      initial_delay = initial_delay
    }
    timer.new {
      name = "lunacord_heartbeat_timer",
      delay = delay,
      initial_delay = initial_delay,
      recurring = true,
      callback = function(timer_obj)
        dump("timer", timer_obj)
        self:send {
          op = 1,
          d = self.last_sequence
        }
      end
    }
    --end)
  else
    error("[lunacord] did not receive hello event as first event")
  end

  -- identify ourselves to the gateway
  local identify = {
    op = 2,
    d = identify_data
  }
  dump("identifying with ", identify)
  self:send(identify)

  local ready = raw_receive(self)
  dump("recieved ready!", ready)

  print("discord_socket is connected!")
end

--- Receive an event from the gateway
--- @return table data The received event payload
--- @nodiscard
function DS:receive()
  local event = raw_receive(self)

  if event.op == 0 then -- Gateway event dispatch
    self.last_sequence = event.s
    local event_name = event.t
    if event_name ~= "GUILD_CREATE" then
      dump(event_name, event.d)
    else
      dump(event_name, (event.d.name or "unavailable") .. " (" .. event.d.id .. ")")
    end

  elseif event.op == 1 then -- Heartbeat request
    print("Discord requested immediate heartbeat.\n(we cant do this yet, oops)")

  elseif event.op == 7 then -- Reconnect
    print("Discord requested reconnect & resume.\n(we cant do this yet, oops)")

  elseif event.op == 9 then -- Invalid Session
    print("Session invalidated.\n(we should reconnect but we can't yet)")

  elseif event.op == 11 then -- Heartbeat ACK
    print("Heartbeat ACK")

  else
    error("[lunacord] Invalid gateway opcode: " .. tostring(event.op))
  end

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
