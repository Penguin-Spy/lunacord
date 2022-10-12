local websocket = require 'websocket.client_copas'
local json = require 'lunajson'
local copas = require 'copas'
local timer = require 'copas.timer'

local zlib = require 'lunacord.zlib'
local dump = require 'lunacord.dump'

local gateway_options = "/?encoding=json&v=9&compress=zlib-stream"
local default_ssl_params = { mode = "client", protocol = "any" }

local Gateway = {}


-- [[ Local gateway communcation methods ]] --

-- Receive a raw payload from the websocket
--- @param self table       The DiscordSocket to receive on
--- @return table|nil data  The received payload, or nil if the socket disconnected
--- @return ... #           On disconnect: `was_clean`, `code`, `reason`
---@nodiscard
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
    return data
  else
    return nil, was_clean, code, reason
  end
end

-- General function for heartbeating from timer or gateway request
local function heartbeat(self)
  if self.heartbeat_acknowledge then
    print("> Heartbeating with sequence: " .. self.last_sequence)
    self:send {
      op = 1,
      d = self.last_sequence
    }
    self.heartbeat_acknowledge = false
  else -- zombied connection
    print("  Did not receive heartbeat ACK in time!")
    self.ws:close(4000, "Heartbeat not ACKd") -- will never return(?) (i love multithreading!!!!)
  end
end

--
-- [[ Connecting/Resuming methods ]] --

-- Init and connect websocket
-- exposed to allow sharding & whatnot
function Gateway:_open(url, ws_protocol, ssl_params)
  self.ws = websocket()
  self.stream = zlib.stream()

  print("> Connecting to " .. url)
  local sucess, err, res = self.ws:connect(url, ws_protocol, ssl_params)
  if not sucess then
    error(dump.dump("[lunacord] WebSocket connection error: " .. err .. "\nresponse headers:",
      res
    ))
  end
end

-- Receive & handle hello event
local function hello(self)
  local hello = raw_receive(self)
  if hello and hello.op == 10 then
    local heartbeat_interval = hello.d.heartbeat_interval

    local delay = heartbeat_interval / 1000
    local initial_delay = math.random() * (delay - 5) + 5 -- wait at least 5 secs before initial heartbeat
    self.heartbeat_acknowledge = true -- so initial heartbeat succeeds

    if self.heartbeat_timer then
      local yea, err = self.heartbeat_timer:cancel()
      dump(yea, err)
    end

    self.heartbeat_timer = timer.new {
      name = "lunacord_heartbeat_timer",
      delay = delay,
      initial_delay = initial_delay,
      recurring = true,
      callback = function() heartbeat(self) end
    }

    print("< Heartbeating at interval " .. delay .. "s (inital: " .. initial_delay .. "s)")
  else
    dump(hello)
    error("[lunacord] ↑ did not receive hello event as first event")
  end
end

-- Identify ourselves to the Discord gateway; creates new session
local function identify(self, identify_data)
  self:send {
    op = 2,
    d = identify_data
  }

  self.identify = identify_data -- save for resuming
end

-- Connect to the gateway
--- @param identify_data table  The data of the identify send event
function Gateway:connect(identify_data)
  self:_open("wss://gateway.discord.gg" .. gateway_options, nil, default_ssl_params)
  hello(self)
  identify(self, identify_data)
end

-- Reconnect to the gateway
--- @param resume boolean Should the session be resumed?
function Gateway:reconnect(resume)
  if self.ws.state ~= "CLOSED" then -- close current connection before reconnecting
    local was_clean, code, reason = self.ws:close(1000)
    print(was_clean, code, reason)
  end

  if resume then
    self:_open(self.resume_gateway_url .. gateway_options, nil, default_ssl_params)
    hello(self)
    self:send {
      op = 6, -- Resume
      d = {
        token = self.identify.token,
        session_id = self.session_id,
        seq = self.last_sequence
      }
    }
    -- at this point, assuming the resume works, discord will begin sending all missed gateway dispatches
    -- therefore this should only be called inside of :receive()

  else -- New connection
    self:_open("wss://gateway.discord.gg" .. gateway_options, nil, default_ssl_params)
    hello(self)
    identify(self, self.identify)
  end
end

-- Receive an event from the gateway
--- @return string name The event name
--- @return table data  The event data
---@nodiscard
function Gateway:receive()
  while true do -- only return a gateway dispatch, internally handle all other opcodes
    local event, was_clean, code, reason = raw_receive(self)

    if not event then -- websocket disconnected
      print("< Websocket disconnected | (" .. tostring(was_clean) .. ") " .. tostring(code) .. ": " .. reason)
      if code == 4004 or code >= 4010 then -- do not reconnect
        error("[lunacord] Disconnected with code " .. code .. " (" .. reason .. "), not reconnecting")
      elseif code == 1000 then
        return "LUNACORD_CLOSE", {}
      else
        -- (code == 1005 or code == 1006) -- no close code, should reconnect
        self:reconnect(code ~= 4007 and code ~= 4009) -- sequence/session invalid, should not resume
      end

    else
      if event.op == 0 then -- Gateway event dispatch
        self.last_sequence = event.s
        if event.t == "READY" then
          self.session_id = event.d.session_id
          self.resume_gateway_url = event.d.resume_gateway_url
        end
        return event.t, event.d

      elseif event.op == 1 then -- Heartbeat request
        print("< Discord requested immediate heartbeat")
        copas.wakeup(self.heartbeat_timer.co)

      elseif event.op == 7 then -- Reconnect
        print("< Discord requested reconnect & resume")
        self:reconnect(true)

      elseif event.op == 9 then -- Invalid Session
        print("< Session invalidated")
        self:reconnect(event.d) -- true if able to resume (unlikely, but possible)

      elseif event.op == 11 then -- Heartbeat ACK
        self.heartbeat_acknowledge = true
        print("< Heartbeat ACK")

      else
        error("[lunacord] Invalid gateway opcode: " .. dump.dump(event.op, event))
      end
    end
  end
end

function Gateway:send(data)
  self.ws:send(json.encode(data))
end

function Gateway:close()
  self.heartbeat_timer:cancel()
  self.ws:close(1000, "Disconnecting")
  return self.session_id
end

return function()
  return setmetatable({}, { __index = Gateway })
end