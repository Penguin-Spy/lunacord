-- Class
local Cache = {
  guilds = {}, -- contain their Members
  channels = {}, -- channel objects contain all their messages
  users = {},

  applications = {},
  webhooks = {},
  invites = {}

  -- potentially other stuff like stage-instances and whatnot
}

-- TODO: should these (and the cache state) just be in the Client?
function Cache:add_guild(guild_obj)
  self.guilds[guild_obj.id] = guild_obj
end

function Cache:get_guild(id)
  return self.guilds[id]
end

-- Constructor
return function()
  return setmetatable({}, {
    __index = Cache
  })
end
