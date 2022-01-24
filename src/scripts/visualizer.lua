local area = require("__flib__.area")

local vivid = require("lib.vivid")

local constants = require("constants")

local visualizer = {}

function visualizer.fluids(player, player_table)
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
      local base_color = game.fluid_prototypes[fluid.name].base_color
      local h, s, v, a = vivid.RGBtoHSV(base_color)
      v = 1
      local r, g, b, a = vivid.HSVtoRGB(h, s, v, a)
      color = { r = r, g = g, b = b, a = a }
    end

    local neighbours = entity.neighbours
    for _, fluidbox_neighbours in pairs(neighbours) do
      for _, neighbour in pairs(fluidbox_neighbours) do
        local neighbour_position = neighbour.position
        if neighbour_position.x > (entity.position.x + 0.99) or neighbour_position.y > (entity.position.y + 0.99) then
          local is_underground_connection = entity.type == "pipe-to-ground"
            and neighbour.type == "pipe-to-ground"
            and (entity.direction == defines.direction.north or entity.direction == defines.direction.west)
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

    table.insert(
      render_objects,
      rendering.draw_circle({
        color = color,
        radius = 0.2,
        filled = true,
        target = entity,
        surface = surface,
        players = { 1 },
      })
    )

    player_table.render_objects = render_objects
  end
end

return visualizer
