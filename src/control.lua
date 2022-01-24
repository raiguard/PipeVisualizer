local event = require("__flib__.event")

local visualizer = require("scripts.visualizer")

--- @param player_index number
local function init_player(player_index)
  --- @class PlayerTable
  global.players[player_index] = {
    flags = {
      render_objects = {},
      toggled = false,
    },
  }
end

event.on_init(function()
  global.players = {}

  for player_index in pairs(game.players) do
    init_player(player_index)
  end
end)

event.on_player_created(function(e)
  init_player(e.player_index)
end)

event.register("pv-toggle", function(e)
  local player_table = global.players[e.player_index]
  if player_table.flags.toggled then
    player_table.flags.toggled = false
    for _, id in pairs(player_table.render_objects) do
      rendering.destroy(id)
    end
    player_table.render_objects = {}
    return
  end
  player_table.flags.toggled = true
  visualizer.fluids(game.get_player(e.player_index), player_table)
end)
