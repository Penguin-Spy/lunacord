local copas = require 'copas'

local discord_socket = require 'lunacord.discord_socket'
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
    self.ds = discord_socket()

    local ready = self.ds:connect {
      token = token,
      intents = 513,
      properties = {
        os = "windows",
        browser = "lunacord",
        device = "lunacord"
      }
    }

    -- process Ready event
    self.user = ready.user
    self.session_id = ready.session_id
    for _, guild in ipairs(ready.guilds) do
      self.cache:add_guild(guild)
    end

    print("< Connected as " .. self.user.username .. "#" .. self.user.discriminator .. " (" .. self.user.id .. ")!")
    print("  Resume url: ", dump.raw(ready.resume_gateway_url))

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
