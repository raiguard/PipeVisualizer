local area = require("__flib__.area")

local vivid = require("lib.vivid")

local constants = require("constants")

local visualizer = {}

--- @param player_table PlayerTable
function visualizer.destroy(player_table)
  player_table.flags.toggled = false
  for _, id in pairs(player_table.render_objects) do
    rendering.destroy(id)
  end
  player_table.render_objects = {}
end

--- @param player LuaPlayer
--- @param player_table PlayerTable
function visualizer.fluids(player, player_table)
  player_table.flags.toggled = true
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
  area.expand(tile_area, 15)

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
      players = { player.index },
    })
  )

  for _, entity in pairs(entities) do
    --- @type Fluid
    local color = { r = 0.3, g = 0.3, b = 0.3 }
    local fluid = entity.fluidbox[1]
    if fluid then
      local base_color = game.fluid_prototypes[fluid.name].base_color
      local h, s, v, a = vivid.RGBtoHSV(base_color)
      v = math.max(v, 0.8)
      local r, g, b, a = vivid.HSVtoRGB(h, s, v, a)
      color = { r = r, g = g, b = b, a = a }
    end

    local neighbours = entity.neighbours
    for _, fluidbox_neighbours in pairs(neighbours) do
      for _, neighbour in pairs(fluidbox_neighbours) do
        local neighbour_position = neighbour.position
        local is_pipe_entity = constants.search_types_lookup[neighbour.type]
        if
          not is_pipe_entity
          or (neighbour_position.x > (entity.position.x + 0.99) or neighbour_position.y > (entity.position.y + 0.99))
        then
          local is_underground_connection = entity.type == "pipe-to-ground"
            and neighbour.type == "pipe-to-ground"
            and (entity.direction == defines.direction.north or entity.direction == defines.direction.west)
          local offset = { 0, 0 }
          if is_underground_connection then
            if entity.direction == defines.direction.north then
              offset = { 0, -0.25 }
            else
              offset = { -0.25, 0 }
            end
          end
          table.insert(
            render_objects,
            rendering.draw_line({
              color = color,
              width = 5,
              gap_length = is_underground_connection and 0.5 or 0,
              dash_length = is_underground_connection and 0.5 or 0,
              from = entity,
              from_offset = offset,
              to = neighbour,
              surface = neighbour.surface,
              players = { player.index },
            })
          )
        end
        if not is_pipe_entity then
          table.insert(
            render_objects,
            rendering.draw_rectangle({
              left_top = neighbour,
              left_top_offset = { -0.2, -0.2 },
              right_bottom = neighbour,
              right_bottom_offset = { 0.2, 0.2 },
              color = color,
              filled = true,
              target = neighbour,
              surface = surface,
              players = { player.index },
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
        players = { player.index },
      })
    )
  end

  player_table.render_objects = render_objects
end

return visualizer
