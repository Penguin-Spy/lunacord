local copas = require("copas")
local timer = require("copas.timer")

local discord_socket = require 'lunacord.discord_socket'
local dump = require 'lunacord.dump'

-- the Client class
local Client = {}

--
--- Register an event handler
--- @param event string     Then name of the event
--- @param handler function The function to be called when the client receives this event
--
function Client:on(event, handler)
  self.handlers[event] = handler
end

--
--- Connects to discord, handling all registered events. \
--- This method does not return until the client disconnects.
--- @param token string The bot token to authorize with
--
function Client.connect(self, token)

  copas.addthread(function()
    self.token = token
    self.ds = discord_socket()

    self.ds:connect()

    -- receive & handle hello event
    local hello = self.ds:receive()
    dump("hello", hello)
    if hello and hello.op == 10 then
      local heartbeat_interval = hello.d.heartbeat_interval
      dump("heartbeat_interval", heartbeat_interval)

      --[=[copas(function()
        timer.new {
          delay = heartbeat_interval / 1000,
          recurring = true,
          callback = function(timer)
            dump("self", self)
            dump("timer", timer)
            --[[self.ds:send({

            })]]
          end
        }
      end)]=]
    else
      error("[lunacord] did not receive hello event as first event")
    end

    -- identify ourselves to the gateway
    local identify = {
      op = 2,
      d = {
        token = token,
        intents = 513,
        properties = {
          os = "windows",
          browser = "lunacord",
          device = "lunacord"
        }
      }
    }
    dump("identifying with ", identify)
    self.ds:send(identify)
    print("identified!")

    -- gateway event handling loop
    while true do
      dump("event", self.ds:receive())
    end
  end)
end

-- class shenanegans (they're epic tho)
return function()
  return setmetatable({}, { __index = Client })
end
