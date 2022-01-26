-- TODO:
-- Better way to update while moving
local event = require("__flib__.event")

local visualizer = require("scripts.visualizer")

--- @param player_index number
local function init_player(player_index)
  --- @class PlayerTable
  global.players[player_index] = {
    enabled = false,
    entity_objects = {},
    --- @type Position?
    last_position = nil,
    rectangle = nil,
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
  local player = game.get_player(e.player_index)
  local player_table = global.players[e.player_index]
  if player_table.enabled then
    visualizer.destroy(player_table)
    return
  end
  visualizer.create(player, player_table)
end)

event.on_player_changed_position(function(e)
  local player = game.get_player(e.player_index)
  local player_table = global.players[e.player_index]
  if player_table.enabled then
    local last_position = player_table.last_position
    local position = player.position
    local floored_position = {
      x = math.floor(position.x),
      y = math.floor(position.y),
    }
    if floored_position.x ~= last_position.x or floored_position.y ~= last_position.y then
      visualizer.update(player, player_table)
    end
  end
end)
