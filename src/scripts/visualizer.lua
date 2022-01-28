local area = require("__flib__.area")
local direction = require("__flib__.direction")

local vivid = require("lib.vivid")

local constants = require("constants")

local visualizer = {}

--- @param player LuaPlayer
--- @param player_table PlayerTable
function visualizer.create(player, player_table)
  player_table.enabled = true
  -- TODO: Failsafe to make sure that nothing is there?
  player_table.entity_objects = {}
  player_table.rectangle = rendering.draw_rectangle({
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
  rendering.set_left_top(player_table.rectangle, overlay_area.left_top)
  rendering.set_right_bottom(player_table.rectangle, overlay_area.right_bottom)

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

  for _, tile_area in pairs(areas) do
    local entities = player.surface.find_entities_filtered({
      type = constants.entity_types,
      area = tile_area,
    })
    for _, entity in pairs(entities) do
      local fluidbox = entity.fluidbox
      if fluidbox and #fluidbox > 0 then
        local entity_objects = player_table.entity_objects[entity.unit_number]
        if entity_objects then
          for _, id in pairs(entity_objects) do
            rendering.destroy(id)
          end
        end
        local entity_objects = {}
        local color

        local neighbours = entity.neighbours
        for fluidbox_index, fluidbox_neighbours in pairs(neighbours) do
          --- @type Fluid
          local fluid = fluidbox[fluidbox_index]
          if fluid then
            local base_color = game.fluid_prototypes[fluid.name].base_color
            local h, s, v, a = vivid.RGBtoHSV(base_color)
            v = math.max(v, 0.8)
            local r, g, b, a = vivid.HSVtoRGB(h, s, v, a)
            color = { r = r, g = g, b = b, a = a }
          else
            color = { r = 0.3, g = 0.3, b = 0.3 }
          end

          for _, neighbour in pairs(fluidbox_neighbours) do
            local neighbour_position = neighbour.position
            local is_underground_connection = entity.type == "pipe-to-ground"
              and neighbour.type == "pipe-to-ground"
              and entity.direction == direction.opposite(neighbour.direction)
              and entity.direction
                == direction.opposite(direction.from_positions(entity.position, neighbour.position, true))
            local is_southeast = neighbour_position.x > (entity.position.x + 0.99)
              or neighbour_position.y > (entity.position.y + 0.99)

            if is_southeast then
              -- Draw connection line
              local offset = { 0, 0 }
              if is_underground_connection then
                if entity.direction == defines.direction.north or entity.direction == defines.direction.south then
                  offset = { 0, -0.25 }
                else
                  offset = { -0.25, 0 }
                end
              end
              table.insert(
                entity_objects,
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
            elseif is_underground_connection and not area.contains_position(overlay_area, neighbour_position) then
              -- Iterate this entity so the underground connection doesn't "pop in" later
              table.insert(entities, neighbour)
            end
          end
        end

        -- Draw entity shape
        if constants.type_to_shape[entity.type] == "square" then
          table.insert(
            entity_objects,
            rendering.draw_rectangle({
              left_top = entity,
              left_top_offset = { -0.2, -0.2 },
              right_bottom = entity,
              right_bottom_offset = { 0.2, 0.2 },
              color = color,
              filled = true,
              target = entity,
              surface = player_surface,
              players = { player.index },
            })
          )
        else
          table.insert(
            entity_objects,
            rendering.draw_circle({
              color = color,
              radius = 0.2,
              filled = true,
              target = entity,
              surface = player_surface,
              players = { player.index },
            })
          )
        end

        player_table.entity_objects[entity.unit_number] = entity_objects
      end
    end
  end
end

--- @param player_table PlayerTable
function visualizer.destroy(player_table)
  player_table.enabled = false
  rendering.destroy(player_table.rectangle)
  for _, objects in pairs(player_table.entity_objects) do
    for _, id in pairs(objects) do
      rendering.destroy(id)
    end
  end
  player_table.entity_objects = {}
  player_table.last_position = nil
end

return visualizer
