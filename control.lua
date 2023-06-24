local handler = require("__core__/lualib/event_handler")

handler.add_libraries({
  require("__PipeVisualizer__/scripts/migrations"),

  require("__PipeVisualizer__/scripts/colors"),
  require("__PipeVisualizer__/scripts/iterator"),
  require("__PipeVisualizer__/scripts/overlay"),
})

-- script.on_event(defines.events.on_selected_entity_changed, function(e)
--   local player = game.get_player(e.player_index)
--   if not player then
--     return
--   end
--   local entity = player.selected
--   if not entity then
--     return
--   end
--   local fluidbox = entity.fluidbox
--   if not fluidbox then
--     return
--   end
--   for i = 1, #fluidbox do
--     --- @cast i uint
--     for _, connection in pairs(fluidbox.get_connections(i)) do
--       rendering.draw_circle({
--         color = { r = 0.5, a = 0.5 },
--         filled = true,
--         radius = 0.15,
--         surface = entity.surface,
--         target = connection.owner,
--       })
--     end
--     for _, pipe_connection in pairs(fluidbox.get_prototype(i).pipe_connections) do
--       rendering.draw_circle({
--         color = { g = 0.5, a = 0.5 },
--         filled = true,
--         radius = 0.15,
--         surface = entity.surface,
--         target = entity,
--         target_offset = pipe_connection.positions[entity.direction / 2 + 1],
--       })
--     end
--   end
-- end)
