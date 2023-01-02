local copas = require 'copas'

local manager = require 'lunacord.manager'
local gateway = require 'lunacord.gateway'
local cache = require 'lunacord.cache'
local dump = require 'lunacord.dump'

--- stop the lang server yelling at me about private vars; everything in this file is allowed to access them
---@diagnostic disable: invisible

---@class Client
---@field user User   The bot's user
--- private fields DO NOT TOUCH
---@field private cache Cache     This client's Cache instance
---@field private gateway table   This client's Gateway instance
---@field private handlers table  Table of all registered event handlers
---@field private thread thread   The gateway loop thread
---@field private identify table  The identify payload
local Client = {}

--
--- Register an event handler
--- @param event string     Then name of the event
--- @param handler function The function to be called when the client receives this event
--
function Client:on(event, handler)
  self.handlers[event] = handler
end

-- gateway event handling loop
-- This method does not return until the client disconnects.
--- @param self Client
local function run(self)
  if not self.identify.intents then
    self.identify.intents = 513 -- should compute via bitwise of registered event handlers w/ client:on(event)
  end

  self.gateway:connect(self.identify)
  manager.register(self)

  while true do
    local event_name, event_data = self.gateway:receive()
    if event_name == nil then break end

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
      local handler = self.handlers[event_name]
      if handler then
        handler(event_data)
      elseif self.handlers.raw then
        self.handlers.raw(event_name, event_data)
      end
    end

  end
end

-- Cleanly disconnects from Discord
function Client:disconnect()
  self.gateway:close()
end

-- Create a new client. \
--- The client is not yet connected to Discord. See the `readme.md` for usage. \
--- Multiple clients can be created and will run simultaneously.
--- @param token string The token of the bot account
--- @return Client
return function(token)
  ---@type Client
  local self = setmetatable({}, { __index = Client })

  self.cache = cache()
  self.gateway = gateway()
  self.handlers = {}

  self.identify = {
    token = token,
    properties = {
      os = "linux",
      browser = "lunacord",
      device = "lunacord"
    }
  }

  -- run is called with the rest of the parameters
  self.thread = copas.addnamedthread("lunacord_client_gateway_loop",
    run, self
  )

  return self
end
