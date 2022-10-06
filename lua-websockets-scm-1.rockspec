---@diagnostic disable: lowercase-global

package = "lua-websockets"
version = "scm-1"

source = {
  url = "git://github.com/Penguin-Spy/lua-websockets.git",
}

description = {
  summary = "Websockets for Lua 5.4",
  homepage = "http://github.com/Penguin-Spy/lua-websockets",
  license = "MIT/X11",
  detailed = "Provides sync and async clients and servers for copas and lua-ev."
}

dependencies = {
  "lua >= 5.4",
  "luasocket",
  "bit32",
  "luasec"
}

build = {
  type = 'none',
  install = {
    lua = {
      ['websocket'] = 'src/websocket.lua',
      ['websocket.sync'] = 'src/websocket/sync.lua',
      ['websocket.client'] = 'src/websocket/client.lua',
      ['websocket.client_sync'] = 'src/websocket/client_sync.lua',
      ['websocket.client_ev'] = 'src/websocket/client_ev.lua',
      ['websocket.client_copas'] = 'src/websocket/client_copas.lua',
      ['websocket.ev_common'] = 'src/websocket/ev_common.lua',
      ['websocket.server'] = 'src/websocket/server.lua',
      ['websocket.server_ev'] = 'src/websocket/server_ev.lua',
      ['websocket.server_copas'] = 'src/websocket/server_copas.lua',
      ['websocket.handshake'] = 'src/websocket/handshake.lua',
      ['websocket.tools'] = 'src/websocket/tools.lua',
      ['websocket.frame'] = 'src/websocket/frame.lua',
      ['websocket.bit'] = 'src/websocket/bit.lua',
    }
  }
}
