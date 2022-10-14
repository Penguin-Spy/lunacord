local copas = require 'copas'

local clients = {}
local function register(client)
  table.insert(clients, client)
end

local function run()
  local success, msg
  repeat
    success, msg = pcall(copas.step)
    if not success then
      if msg:sub(-12) == "interrupted!" then
        -- caught Ctrl+C or other quit signal
        print("[lunacord] Caught quit signal, disconnecting all clients")
      else
        -- encountered an actual error
        print(debug.traceback(msg))
      end

      -- disconnect all clients
      for _, client in ipairs(clients) do
        copas.addthread(function()
          client:disconnect() -- yields, never returns
        end)
      end
    end
  until copas.finished()
  return success, msg
end

return {
  run = run,
  register = register
}
