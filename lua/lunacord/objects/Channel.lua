---@class Channel
---@field id snowflake
local Channel = {}




-- Constructor
---@param data table
---@return Channel
return function(data)
  return setmetatable(data, { __index = Channel })
end
