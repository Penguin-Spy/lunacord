local websocket = require 'coro-websocket'
local zlib = require 'zlib'

local Client = {}

function Client.connect()
  local co = coroutine.create(function()
    local res, read, write = websocket.connect {
      host = "gateway.discord.gg",
      port = "443",
      tls = true,
      pathname = "/?encoding=json&v=9&compress=zlib-stream",
      headers = {
        ['User-Agent'] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:103.0) Gecko/20100101 Firefox/103.0"
      }
    }

    p(res, read, write)

    local payload = read().payload
    p(payload)

    --[[local f = io.open("message.bin", "w+b")
    if not f then return nil end

    f:write(payload)
    f:close()]]

    local data = zlib.decompress(payload)
    p(data)

  end)

  p("start:", coroutine.resume(co))

end

return Client
