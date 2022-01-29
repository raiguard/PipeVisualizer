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
    color = { a = player.mod_settings["pv-overlay-opacity"].value },
    surface = player.surface,
    players = { player.index },
  })
  player_table.overlay_area = area.from_dimensions(
    { height = constants.max_viewable_radius * 2, width = constants.max_viewable_radius * 2 },
    player.position
  )

  visualizer.update(player, player_table)
end

--- @param player LuaPlayer
--- @param player_table PlayerTable
function visualizer.update(player, player_table)
  local player_position = {
    x = math.floor(player.position.x),
    y = math.floor(player.position.y),
  }

  -- Update overlay
  local overlay_area = area.center_on(player_table.overlay_area, player.position)
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

  -- Render connections
  for _, tile_area in pairs(areas) do
    local entities = player.surface.find_entities_filtered({
      type = constants.entity_types,
      area = tile_area,
    })
    visualizer.draw_entities(player, player_table, entities)
  end
end

--- @param player LuaPlayer
--- @param player_table PlayerTable
--- @param entities LuaEntity[]
function visualizer.draw_entities(player, player_table, entities)
  local entity_objects = player_table.entity_objects
  local shapes_to_draw = {}
  local overlay_area = player_table.overlay_area
  local fluid_colors = global.fluid_colors
  local fluid_system_colors = {}
  local fluid_system_uncolored = {}

  for _, entity in pairs(entities) do
    local fluidbox = entity.fluidbox
    if fluidbox and #fluidbox > 0 and not entity_objects[entity.unit_number] then
      local fluid_system_id = nil
      local this_entity_objects = {}
      for fluidbox_index, fluidbox_neighbours in pairs(entity.neighbours) do
        fluid_system_id = fluidbox.get_fluid_system_id(fluidbox_index)
        if fluid_system_id then
          -- Get the color
          local color = fluid_system_colors[fluid_system_id]
          if color then
            shape_color = color
          else
            --- @type Fluid
            local fluid = fluidbox[fluidbox_index] or fluidbox.get_filter(fluidbox_index)
            if fluid then
              color = fluid_colors[fluid.name]
              -- Update shape and fluid system color
              shape_color = color
              fluid_system_colors[fluid_system_id] = color
              -- Retroactively apply colors to other entities in this network
              for _, unit_number in pairs(fluid_system_uncolored[fluid_system_id] or {}) do
                for _, id in pairs(entity_objects[unit_number] or {}) do
                  rendering.set_color(id, color)
                end
              end
              fluid_system_uncolored[fluid_system_id] = nil
            else
              color = constants.default_color
              local uncolored_entities = fluid_system_uncolored[fluid_system_id]
              if not uncolored_entities then
                uncolored_entities = {}
                fluid_system_uncolored[fluid_system_id] = uncolored_entities
              end
              table.insert(uncolored_entities, entity.unit_number)
            end
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
                  color = color,
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
      end

      local unit_number = entity.unit_number
      shapes_to_draw[unit_number] = { fluid_system_id = fluid_system_id, entity = entity }
      entity_objects[unit_number] = this_entity_objects
    end
  end

  -- Now draw shapes, so they are on top
  for unit_number, shape_data in pairs(shapes_to_draw) do
    local color = fluid_system_colors[shape_data.fluid_system_id] or constants.default_color
    local entity = shape_data.entity
    if constants.type_to_shape[entity.type] == "square" then
      table.insert(
        entity_objects[unit_number],
        rendering.draw_rectangle({
          left_top = entity,
          left_top_offset = { -0.2, -0.2 },
          right_bottom = entity,
          right_bottom_offset = { 0.2, 0.2 },
          color = color,
          filled = true,
          target = entity,
          surface = entity.surface,
          players = { player.index },
        })
      )
    else
      table.insert(
        entity_objects[unit_number],
        rendering.draw_circle({
          color = color,
          radius = 0.2,
          filled = true,
          target = entity,
          surface = entity.surface,
          players = { player.index },
        })
      )
    end
  end
end

--- @param player_table PlayerTable
function visualizer.destroy(player_table)
  player_table.enabled = false
  if player_table.overlay then
    rendering.destroy(player_table.overlay)
    player_table.overlay = nil
  end
  for _, objects in pairs(player_table.entity_objects) do
    for _, id in pairs(objects) do
      rendering.destroy(id)
    end
  end
  player_table.entity_objects = {}
  player_table.last_position = nil
end

return visualizer
