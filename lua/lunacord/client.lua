local copas = require("copas")

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

  copas.addnamedthread("lunacord_client_gateway_loop", function()
    self.token = token
    self.ds = discord_socket()

    self.ds:connect {
      token = token,
      intents = 513,
      properties = {
        os = "windows",
        browser = "lunacord",
        device = "lunacord"
      }
    }

    -- gateway event handling loop
    while true do
      self.ds:receive()
      --dump("event", self.ds:receive())
    end
  end)
end

-- class shenanegans (they're epic tho)
return function()
  return setmetatable({}, { __index = Client })
end
