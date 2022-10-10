local Guild = require 'lunacord.objects.Guild'

---@class snowflake A discord snowflake

---@class Cache
---@field guilds Guild[]
---@field channels Channel[]
---@field users User[]
---@field applications table[]
---@field webhooks table[]
---@field invites table[]
---
---@field add_guild function

---@type Cache
local Cache = {
  guilds = {}, -- contain their Members
  channels = {}, -- channel objects contain all their messages
  users = {},

  applications = {},
  webhooks = {},
  invites = {}

  -- potentially other stuff like stage-instances and whatnot
}

---@param data table The raw guild data from the GUILD_CREATE gateway dispatch
function Cache:add_guild(data)
  if not data.unavailable then
    local extra = {
      joined_at = data.joined_at,
      large = data.large,
      unavailable = data.unavailable,
      member_count = data.member_count,
      voice_states = data.voice_states,
      presences = data.presences,
      stage_instances = data.stage_instances,
      guild_scheduled_events = data.guild_scheduled_events
    }
    local members = data.members
    local channels = data.channels
    local threads = data.threads

    data.joined_at = nil
    data.large = nil
    data.unavailable = nil
    data.member_count = nil
    data.voice_states = nil
    data.presences = nil
    data.stage_instances = nil
    data.guild_scheduled_events = nil
    data.members = nil
    data.channels = nil
    data.threads = nil
  end

  local test = Guild(data)
  self.guilds[data.id] = test
end

---@param id snowflake
---@return Guild
function Cache:get_guild(id)
  return self.guilds[id]
end

-- Constructor
---@return Cache
return function()
  return setmetatable({}, { __index = Cache })
end
