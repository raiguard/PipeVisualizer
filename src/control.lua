local area = require("__flib__.area")
local event = require("__flib__.event")

local constants = require("constants")

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
  local player = game.get_player(e.player_index)
  local player_position = player.position
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
  local tile_area = area.from_dimensions(tile_resolution, player_position)

  local entities = player.surface.find_entities_filtered({
    type = constants.search_types,
    area = tile_area,
  })

  -- local entities = { player.selected }

  local render_objects = {}

  table.insert(
    render_objects,
    rendering.draw_rectangle({
      left_top = tile_area.left_top,
      right_bottom = tile_area.right_bottom,
      filled = true,
      color = { a = 0.5 },
      surface = surface,
      players = { 1 },
    })
  )

  for _, entity in pairs(entities) do
    --- @type Fluid
    local color = { r = 0.3, g = 0.3, b = 0.3 }
    local fluid = entity.fluidbox[1]
    if fluid then
      -- TODO: Ensure a consistent brightness and saturation
      color = game.fluid_prototypes[fluid.name].base_color
    end

    local neighbours = entity.neighbours
    for _, fluidbox_neighbours in pairs(neighbours) do
      for _, neighbour in pairs(fluidbox_neighbours) do
        local neighbour_position = neighbour.position
        if neighbour_position.x > (entity.position.x + 0.99) or neighbour_position.y > (entity.position.y + 0.99) then
          local is_underground_connection = entity.type == "pipe-to-ground" and neighbour.type == "pipe-to-ground"
          table.insert(
            render_objects,
            rendering.draw_line({
              color = color,
              width = 5,
              gap_length = is_underground_connection and 0.5 or 0,
              dash_length = is_underground_connection and 0.3 or 0,
              from = entity,
              to = neighbour,
              surface = neighbour.surface,
              players = { 1 },
            })
          )
        end
      end
    end

    player_table.render_objects = render_objects
  end
end)
