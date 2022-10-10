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
    self.resume_gateway_url = ready.resume_gateway_url
    for _, guild in ipairs(ready.guilds) do
      self.cache:add_guild(guild)
    end

    print("< Connected as " .. self.user.username .. "#" .. self.user.discriminator .. " (" .. self.user.id .. ")!")
    print("  Resume url: ", dump.raw(self.resume_gateway_url))

    -- gateway event handling loop
    while true do
      local event_name, event_data = self.ds:receive()

      if event_name ~= "GUILD_CREATE" then
        print("< Dispatch " .. dump.colorize(event_name) .. ": ", dump.raw(event_data, 1))
      else
        print("< Dispatch " .. dump.colorize(event_name) .. ": ", event_data.name .. " (" .. event_data.id .. ")")
      end

    end
  end)
end

-- class shenanegans (they're epic tho)
return function()
  return setmetatable({}, { __index = Client })
end
