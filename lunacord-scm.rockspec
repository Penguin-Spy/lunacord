package = "Lunacord"
version = "scm"
source = {
  url = "git://github.com/Penguin-Spy/lunacord"
}
description = {
  summary = "A simple, convenient Discord bot library in pure Lua",
  detailed = [[
    A simple, convenient Discord bot library written in pure Lua.
    All caching is handled by the library, allowing you to just
    focus on writing your Discord bot.
  ]],
  homepage = "https://github.com/Penguin-Spy/lunacord",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1"
}
build = {
  type = "builtin",
  modules = {}
}
