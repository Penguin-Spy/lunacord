---@class Guild
---@field id snowflake
---@field name string
---@field icon? string
--icon_hash = data.icon_hash,
---@field splash? string
---@field discovery_splash? string
---@field owner_id snowflake
---@field afk_channel_id? snowflake
---@field afk_timeout integer
---@field widget_enabled? boolean
---@field widget_channel_id? snowflake
---@field verification_level integer
---@field default_message_notifications integer
---@field explicit_content_filter integer
---@field roles table[] roles
---@field emojis table[]
---@field features table[]
---@field mfa_level integer
---@field application_id? snowflake
---@field system_channel_id? snowflake
---@field system_channel_flags integer
---@field rules_channel_id? snowflake
---@field max_presences? integer
---@field max_members? integer
---@field vanity_url_code? string
---@field description? string
---@field banner? string
---@field premium_tier integer
---@field premium_subscription_count? integer
---@field preferred_locale string
---@field public_updates_channel_id? snowflake
---@field max_video_channel_users? integer
-- ---@field approximate_member_count? integer
-- ---@field approximate_presence_count? integer
---@field welcome_screen? table
---@field nsfw_level integer
---@field stickers? table[]
---@field premium_progress_bar_enabled boolean
--
---@field available boolean
local Guild = {}

-- Constructor
---@param data table
---@return Guild
return function(data)

  if data.unavailable then
    data.available = false
    data.unavailable = nil
  else
    data.available = true
  end

  ---@type Guild
  --[[local guild = {
    id = data.id,
    name = data.name,
    icon = data.icon,
    splash = data.splash,
    discovery_splash = data.discovery_splash,
    owner_id = data.owner_id,
    afk_channel_id = data.afk_channel_id,
    afk_timeout = data.afk_timeout,
    widget_enabled = data.widget_enabled,
    widget_channel_id = data.widget_channel_id,
    verification_level = data.verification_level,
    default_message_notifications = data.default_message_notifications,
    explicit_content_filter = data.explicit_content_filter,
    roles = data.roles,
    emojis = data.emojis,
    features = data.features,
    mfa_level = data.mfa_level,
    application_id = data.application_id,
    system_channel_id = data.system_channel_id,
    system_channel_flags = data.system_channel_flags,
    rules_channel_id = data.rules_channel_id,
  }]]

  --return setmetatable(guild, { __index = Guild })
  return setmetatable(data, { __index = Guild })
end
