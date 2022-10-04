local colors = {
  ["nil"] = "\27[90m",
  ["number"] = "\27[92m",
  ["string"] = "\27[31m",
  ["boolean"] = "\27[34m",
  ["function"] = "\27[95m",
  ["thread"] = "\27[96m",
  ["userdata"] = "\27[33m",
  RESET = "\27[m"
}
local function colorize(v)
  if type(v) == "string" then
    return colors.string .. "\"" .. v .. "\"" .. colors.RESET
  else
    return colors[type(v)] .. tostring(v) .. colors.RESET
  end
end

local function indent(layer, value)
  return string.rep("  ", layer) .. value
end

local function dump(variable, layer, inline)
  local ret = ""
  layer = layer or 0
  if type(variable) == "table" then
    ret = ret .. "{\n"
    for key, value in pairs(variable) do
      ret = ret .. indent(layer + 1, "[" .. colorize(key) .. "] = " .. dump(value, layer + 1, true)) .. ",\n"
    end
    ret = ret .. indent(layer, "}")
  else
    local str = colorize(variable)
    ret = ret .. (inline and str or indent(layer, str))
  end

  return ret
end

--- Return value is callable and will print directly to stdio. \
--- Dumps the provided values, recusring through tables. \
--- DOES NOT YET PROTECT AGAINST SELF-REFERENCES!!
return setmetatable({
  raw = dump
}, {
  __call = function(_, ...)
    local ret = ""
    for _, value in ipairs(table.pack(...)) do
      ret = ret .. dump(value) .. "\t"
    end
    print(ret)
  end
})
