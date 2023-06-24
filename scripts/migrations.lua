local flib_migration = require("__flib__/migration")

local colors = require("__PipeVisualizer__/scripts/colors")
local overlay = require("__PipeVisualizer__/scripts/overlay")

local version_migrations = {
  ["2.0.0"] = function()
    global = {}

    colors.on_init()
    overlay.on_init()
  end,
}

local migrations = {}

migrations.on_configuration_changed = function(e)
  flib_migration.on_config_changed(e, version_migrations)
end

return migrations
