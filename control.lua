local handler = require("__core__.lualib.event_handler")

handler.add_libraries({
  require("scripts.migrations"),

  require("scripts.blacklist"),
  require("scripts.colors"),
  require("scripts.iterator"),
  require("scripts.mouseover"),
  require("scripts.order"),
  require("scripts.overlay"),
  require("scripts.renderer"),
})
