local area = require("__flib__.area")
local direction = require("__flib__.direction")

local constants = require("constants")

local visualizer = {}

--- @param player LuaPlayer
--- @param player_table PlayerTable
function visualizer.create(player, player_table)
  player_table.enabled = true
  player_table.entity_objects = {}
  player_table.overlay = rendering.draw_rectangle({
    left_top = { x = 0, y = 0 },
    right_bottom = { x = 0, y = 0 },
    filled = true,
    color = { a = 0.6 },
    surface = player.surface,
    players = { player.index },
  })

  visualizer.update(player, player_table)
end

--- @param player LuaPlayer
--- @param player_table PlayerTable
function visualizer.update(player, player_table)
  local player_surface = player.surface
  local player_position = {
    x = math.floor(player.position.x),
    y = math.floor(player.position.y),
  }

  local overlay_area = area.from_dimensions(
    { height = constants.max_viewable_radius * 2, width = constants.max_viewable_radius * 2 },
    player_position
  )

  -- Update overlay
  rendering.set_left_top(player_table.overlay, overlay_area.left_top)
  rendering.set_right_bottom(player_table.overlay, overlay_area.right_bottom)

  -- Compute areas to search based on movement
  local areas = {}
  if player_table.last_position then
    local last_position = player_table.last_position
    --- @type Position
    local delta = {
      x = player_position.x - last_position.x,
      y = player_position.y - last_position.y,
    }

    if delta.x < 0 then
      table.insert(areas, {
        left_top = {
          x = player_position.x - constants.max_viewable_radius,
          y = player_position.y - constants.max_viewable_radius,
        },
        right_bottom = {
          x = last_position.x - constants.max_viewable_radius,
          y = player_position.y + constants.max_viewable_radius,
        },
      })
    elseif delta.x > 0 then
      table.insert(areas, {
        left_top = {
          x = last_position.x + constants.max_viewable_radius,
          y = player_position.y - constants.max_viewable_radius,
        },
        right_bottom = {
          x = player_position.x + constants.max_viewable_radius,
          y = player_position.y + constants.max_viewable_radius,
        },
      })
    end

    if delta.y < 0 then
      table.insert(areas, {
        left_top = {
          x = player_position.x - constants.max_viewable_radius,
          y = player_position.y - constants.max_viewable_radius,
        },
        right_bottom = {
          x = player_position.x + constants.max_viewable_radius,
          y = last_position.y - constants.max_viewable_radius,
        },
      })
    elseif delta.y > 0 then
      table.insert(areas, {
        left_top = {
          x = player_position.x - constants.max_viewable_radius,
          y = last_position.y + constants.max_viewable_radius,
        },
        right_bottom = {
          x = player_position.x + constants.max_viewable_radius,
          y = player_position.y + constants.max_viewable_radius,
        },
      })
    end
  else
    table.insert(areas, overlay_area)
  end

  player_table.last_position = player_position

  local entity_objects = player_table.entity_objects
  local shapes_to_draw = {}

  for _, tile_area in pairs(areas) do
    local entities = player.surface.find_entities_filtered({
      type = constants.entity_types,
      area = tile_area,
    })
    for _, entity in pairs(entities) do
      local fluidbox = entity.fluidbox
      if fluidbox and #fluidbox > 0 and not entity_objects[entity.unit_number] then
        local color = { r = 0.3, g = 0.3, b = 0.3 }
        local this_entity_objects = {}
        for fluidbox_index, fluidbox_neighbours in pairs(entity.neighbours) do
          --- @type Fluid
          --- TODO: Color by fluid in network (requires an API feature)
          local fluid = fluidbox[fluidbox_index]
          local this_color
          if fluid then
            -- Only update the shape color if it's not grey
            this_color = global.fluid_colors[fluid.name]
            color = this_color
          else
            this_color = { r = 0.3, g = 0.3, b = 0.3 }
          end

          for _, neighbour in pairs(fluidbox_neighbours) do
            local entity_direction = entity.direction
            local entity_position = entity.position
            local neighbour_position = neighbour.position

            local is_southeast = neighbour_position.x > (entity_position.x + 0.99)
              or neighbour_position.y > (entity_position.y + 0.99)
            local is_underground_connection = entity.type == "pipe-to-ground"
              and neighbour.type == "pipe-to-ground"
              and entity_direction == direction.opposite(neighbour.direction)
              and entity_direction
                == direction.opposite(direction.from_positions(entity_position, neighbour_position, true))

            if is_southeast then
              -- Draw connection line
              local offset = { 0, 0 }
              if is_underground_connection then
                if entity.direction == defines.direction.north or entity.direction == defines.direction.south then
                  offset = { 0, -0.125 }
                else
                  offset = { -0.125, 0 }
                end
              end
              table.insert(
                this_entity_objects,
                rendering.draw_line({
                  color = this_color,
                  width = 5,
                  gap_length = is_underground_connection and 0.25 or 0,
                  dash_length = is_underground_connection and 0.25 or 0,
                  from = entity,
                  from_offset = offset,
                  to = neighbour,
                  surface = neighbour.surface,
                  players = { player.index },
                })
              )
            elseif is_underground_connection and not area.contains_position(overlay_area, neighbour_position) then
              -- Iterate the neighbour to draw the underground connection line
              table.insert(entities, neighbour)
            end
          end
        end

        shapes_to_draw[entity.unit_number] = { color = color, entity = entity }

        entity_objects[entity.unit_number] = this_entity_objects
      end
    end

    -- Now draw shapes, so they are on top
    for unit_number, shape_data in pairs(shapes_to_draw) do
      local entity = shape_data.entity
      if constants.type_to_shape[entity.type] == "square" then
        table.insert(
          entity_objects[unit_number],
          rendering.draw_rectangle({
            left_top = entity,
            left_top_offset = { -0.2, -0.2 },
            right_bottom = entity,
            right_bottom_offset = { 0.2, 0.2 },
            color = shape_data.color,
            filled = true,
            target = entity,
            surface = player_surface,
            players = { player.index },
          })
        )
      else
        table.insert(
          entity_objects[unit_number],
          rendering.draw_circle({
            color = shape_data.color,
            radius = 0.2,
            filled = true,
            target = entity,
            surface = player_surface,
            players = { player.index },
          })
        )
      end
    end
  end
end

--- @param player_table PlayerTable
function visualizer.destroy(player_table)
  player_table.enabled = false
  rendering.destroy(player_table.overlay)
  for _, objects in pairs(player_table.entity_objects) do
    for _, id in pairs(objects) do
      rendering.destroy(id)
    end
  end
  player_table.entity_objects = {}
  player_table.last_position = nil
end

return visualizer
