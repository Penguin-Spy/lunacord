---@diagnostic disable: lowercase-global

package = "Lunacord"
version = "scm-1"
source = {
  url = "git://github.com/Penguin-Spy/lunacord.git"
}

description = {
  summary = "A simple, convenient Discord bot library in pure Lua",
  detailed = [[
    A simple, convenient Discord bot library written in pure Lua.
    Everything from receiving gateway events to fetching and caching objects is handled by the library,
    allowing you to just focus on writing your Discord bot.
  ]],
  homepage = "https://github.com/Penguin-Spy/lunacord",
  license = "MIT"
}
dependencies = {
  "lua >= 5.4",
  "lua-websockets",
  "lunajson",
  "copas"
}

build = {
  type = "builtin",
  modules = {}
}
