---@class User
---@field id snowflake
---@field username string
---@field discriminator string
local User = {}


-- Constructor
---@param data table
---@return User
return function(data)
  return setmetatable(data, { __index = User })
end
