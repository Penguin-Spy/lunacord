local copas = require 'copas'

local clients = {}
local function register(client)
  table.insert(clients, client)
end

local function run()
  repeat
    local success, err = pcall(copas.step)
    if not success then
      if err == "interrupted!" or err:sub(-12) == "interrupted!" then
        -- caught Ctrl+C or other quit signal
        print("[lunacord] Caught quit signal, disconnecting all clients")
      else
        -- actual error
        print(debug.traceback(err))
      end

      -- disconnect all clients
      for _, client in ipairs(clients) do
        copas.addthread(function()
          client:disconnect() -- yields, never returns
        end)
      end
    end
  until copas.finished()
end

return {
  run = run,
  register = register
}
