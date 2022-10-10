---@class Message
---@field id snowflake
local Message = {}



-- Constructor
---@param data table
---@return Message
return function(data)
  return setmetatable(data, { __index = Message })
end
