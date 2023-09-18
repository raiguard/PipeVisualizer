if script.active_mods["gvv"] then
  require("__gvv__.gvv")()
end

local handler = require("__core__/lualib/event_handler")

handler.add_libraries({
  require("__PipeVisualizer__/scripts/migrations"),

  require("__PipeVisualizer__/scripts/colors"),
  require("__PipeVisualizer__/scripts/entity-detection"),
  require("__PipeVisualizer__/scripts/iterator"),
  require("__PipeVisualizer__/scripts/overlay"),
  require("__PipeVisualizer__/scripts/renderer"),
})

-- local colors = {
--   ["input-output"] = { r = 0.3, g = 0.3, a = 0.3 },
--   ["input"] = { r = 0.3, a = 0.3 },
--   ["output"] = { g = 0.3, a = 0.3 },
--   ["none"] = { a = 0 },
-- }
-- local entities = game.player.surface.find_entities_filtered({
--   area = area,
-- })
-- for _, entity in pairs(entities) do
--   --- @cast entity LuaEntity
--   local fluidbox = entity.fluidbox or {}
--   for i = 1, #fluidbox do
--     local prototypes = fluidbox.get_prototype(i --[[@as uint]])
--     if prototypes.object_name then
--       prototypes = { prototypes }
--     end
--     for _, prototype in pairs(prototypes) do
--       for _, connection in pairs(prototype.pipe_connections) do
--         local color = colors[connection.type]
--         local position = connection.positions[(entity.direction / 2) + 1]
--         rendering.draw_circle({
--           color = color,
--           radius = 0.2,
--           filled = true,
--           target = entity,
--           target_offset = { position.x, position.y },
--           surface = entity.surface_index,
--         })
--       end
--     end
--   end
-- end

-- /c game.player.teleport({ x = 646.60546875, y = -160.99609375 }) game.player.zoom = 0.67
