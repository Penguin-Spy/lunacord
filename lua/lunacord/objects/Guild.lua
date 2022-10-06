-- Class
local Guild = {}

-- Constructor
return function()
  return setmetatable({}, {
    __index = Guild
  })
end
