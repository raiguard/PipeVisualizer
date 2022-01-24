local area = require("__flib__.area")
local event = require("__flib__.event")

local constants = require("constants")

event.on_init(function()
  global.players = {}
end)

event.on_player_created(function(e)
  --- @class PlayerTable
  global.players[e.player_index] = {}
end)

event.register("pv-toggle", function(e)
  local player = game.get_player(e.player_index)
  local position = player.position
  local surface = player.surface

  -- Calculate the area to search from resolution
  -- FIXME: This assumes a 16x9 or 9x16 proportion
  local resolution = player.display_resolution
  -- 12 is the pixels per tile at max zoom
  local pixels_per_tile = 12
  local tile_resolution = {
    width = resolution.width / pixels_per_tile,
    height = resolution.height / pixels_per_tile,
  }
  local tile_area = area.from_dimensions(tile_resolution, position)

  local entities = player.surface.find_entities_filtered({
    type = constants.search_types,
    area = tile_area,
  })

  rendering.draw_rectangle({
    left_top = tile_area.left_top,
    right_bottom = tile_area.right_bottom,
    filled = true,
    color = { g = 0.2, a = 0.2 },
    surface = surface,
    players = { 1 },
    time_to_live = 120,
  })

  for _, entity in pairs(entities) do
    --- @type Fluid
    local color = { r = 0.3, g = 0.3, b = 0.3 }
    local fluid = entity.fluidbox[1]
    if fluid then
      -- TODO: Ensure a consistent brightness and saturation
      color = game.fluid_prototypes[fluid.name].base_color
    end
    rendering.draw_circle({
      color = color,
      radius = 0.3,
      filled = true,
      surface = surface,
      target = entity.position,
      players = { 1 },
      time_to_live = 120,
    })
  end
end)
