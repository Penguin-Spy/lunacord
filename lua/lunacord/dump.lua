local function indent(ret, layer, value)
  return ret .. string.rep("  ", layer) .. value
end

local function dump(variable, layer)
  local ret = ""
  layer = layer or 0
  if type(variable) == "table" then
    ret = ret .. "{\n"
    for key, value in pairs(variable) do
      ret = indent(ret, layer + 1, "[\"" .. tostring(key) .. "\"] = " .. dump(value, layer + 1))
    end
    ret = indent(ret, layer, "}\n")
  elseif type(variable) == "string" then
    ret = indent(ret, layer, "\"" .. variable .. "\"\n")
  else
    ret = indent(ret, layer, tostring(variable) .. "\n")
  end
  return ret
end

--
--- Dumps the provided value, recusring through tables. \
--- DOES NOT YET PROTECT AGAINST SELF-REFERENCES!!
--- @param value any The value to print
--
return function(value)
  print(dump(value))
end
