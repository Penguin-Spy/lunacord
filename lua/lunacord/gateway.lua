local websocket = require 'websocket.client_copas'
local json = require 'lunajson'
local copas = require 'copas'
local timer = require 'copas.timer'

local zlib = require 'lunacord.zlib'
local dump = require 'lunacord.dump'

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
    self.ws:close(4000, "Heartbeat not ACKd") -- yields, resumes in :receive()
  end
end

--
-- [[ Connecting/Resuming methods ]] --

-- Init and connect websocket. \
-- Can be called on already used gateway; will re-initalize (will not close websocket!)
--- @param url string   The gateway url to connect to
local function open(self, url)
  self.ws = websocket()
  self.stream = zlib.stream()

  local gateway_url = url .. self.cfg.gateway_options
  print("> Connecting to " .. gateway_url)
  local sucess, err, res = self.ws:connect(gateway_url, nil, self.cfg.ssl_params, self.cfg.req_headers)

  if not sucess then
    error(dump.dump("[lunacord] WebSocket connection error: " .. err ..
      "\nresponse headers:", res
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

    if self.heartbeat_timer then self.heartbeat_timer:cancel() end

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

-- Connect to the gateway
--- @param identify_data table  The data of the identify send event
function Gateway:connect(identify_data)
  open(self, "wss://gateway.discord.gg")
  hello(self)

  self.identify = identify_data -- save for resuming
  self:send {
    op = 2, -- Identify
    d = self.identify
  }
end

-- Reconnect to the gateway
--- @param resume boolean Should the session be resumed?
function Gateway:reconnect(resume)
  if self.ws.state ~= "CLOSED" then -- close current connection before reconnecting
    local was_clean, code, reason = self.ws:close(1000)
    print(was_clean, code, reason)
  end

  if resume then
    open(self, self.resume_gateway_url)
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
    -- therefore :reconnect() should only be called inside of :receive()

  else -- New connection
    open(self, "wss://gateway.discord.gg")
    hello(self)
    self:send {
      op = 2, -- Identify
      d = self.identify
    }
  end
end

-- Receive an event from the gateway
--- @return string|nil name The event name (nil when quitting)
--- @return table data      The event data
---@nodiscard
function Gateway:receive()
  while true do -- only return a gateway dispatch, internally handle all other opcodes
    local event, was_clean, code, reason = raw_receive(self)

    if not event then -- websocket disconnected
      print("< Websocket disconnected | (" .. tostring(was_clean) .. ") " .. tostring(code) .. ": " .. reason)

      if code == 4004 or code >= 4010 then -- do not reconnect
        error("[lunacord] Disconnected with code " .. code .. " (" .. reason .. "), not reconnecting")
      elseif code == 1000 then ---@diagnostic disable-next-line: missing-return-value
        return nil -- indicate client loop should return
      else
        -- (code == 1005 or code == 1006) -- no close code, should reconnect
        self:reconnect(code ~= 4007 and code ~= 4009) -- sequence/session invalid, should not resume
      end

    else
      if event.op == 0 and event.t then -- Gateway event dispatch
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
end

-- params are to allow sharding & whatnot
--- @param gateway_options? string  The gateway options query string. Defaults to API v9, zlib compression
--- @param ssl_params? table        SSL params. defaults to something that works idk what it does tho lol
--- @param req_headers? table       extra headers for connecting to the gateway
return function(gateway_options, ssl_params, req_headers)
  return setmetatable({
    cfg = { -- this instances' values for opening the websocket
      gateway_options = gateway_options or "/?encoding=json&v=9&compress=zlib-stream",
      ssl_params = ssl_params or { mode = "client", protocol = "any" },
      req_headers = req_headers or {}
    }
  }, { __index = Gateway })
end
