local copas = require 'copas'

local gateway = require 'lunacord.gateway'
local cache = require 'lunacord.cache'
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
    self.cache = cache()

    self.gateway = gateway()

    self.gateway:connect {
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
      local event_name, event_data = self.gateway:receive()

      if event_name == "GUILD_CREATE" then
        print("< Dispatch " .. dump.colorize(event_name) .. ": ", event_data.name .. " (" .. event_data.id .. ")")

      elseif event_name == "READY" then
        self.user = event_data.user
        for _, guild in ipairs(event_data.guilds) do
          self.cache:add_guild(guild)
        end
        print("< Connected as " .. self.user.username .. "#" .. self.user.discriminator .. " (" .. self.user.id .. ")!")

      else
        print("< Dispatch " .. dump.colorize(event_name) .. ": ", dump.raw(event_data, 1))
      end

    end
  end)
end

-- class shenanegans (they're epic tho)
return function()
  return setmetatable({}, { __index = Client })
end
