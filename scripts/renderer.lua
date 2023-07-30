--- @diagnostic disable

local flib_bounding_box = require("__flib__/bounding-box")
local flib_direction = require("__flib__/direction")
local flib_position = require("__flib__/position")

--- Assumes that the positions are in exact cardinals.
--- @param from MapPosition
--- @param to MapPosition
--- @return defines.direction
local function get_cardinal_direction(from, to)
  if from.y > to.y then
    return defines.direction.north
  elseif from.x < to.x then
    return defines.direction.east
  elseif from.y < to.y then
    return defines.direction.south
  else
    return defines.direction.west
  end
end

local inner_triangle_points =
  { { target = { -0.296, 0.172 } }, { target = { 0, -0.109 } }, { target = { 0.296, 0.172 } } }
local outer_triangle_points = { { target = { -0.42, 0.22 } }, { target = { 0, -0.175 } }, { target = { 0.42, 0.22 } } }

local inner_rectangle_points = {
  { target = { -0.148, -0.0545 } },
  { target = { 0.148, -0.0545 } },
  { target = { 0.148, 0.0545 } },
  { target = { -0.148, 0.0545 } },
  { target = { -0.148, -0.0545 } },
}
local outer_rectangle_points = {
  { target = { -0.21, -0.11 } },
  { target = { 0.21, -0.11 } },
  { target = { 0.21, 0.11 } },
  { target = { -0.21, 0.11 } },
  { target = { -0.21, -0.11 } },
}

--- @type float
local border_width = 3 / 32

--- @type table<defines.direction, Vector>
local border_offsets = {
  [defines.direction.north] = { x = 0, y = -border_width },
  [defines.direction.east] = { x = border_width, y = 0 },
  [defines.direction.south] = { x = 0, y = border_width },
  [defines.direction.west] = { x = -border_width, y = 0 },
}

--- @type table<defines.direction, Vector>
local offsets = {
  [defines.direction.north] = { x = 0, y = -(border_width / 2 - 0.01) },
  [defines.direction.east] = { x = (border_width / 2 - 0.01), y = 0 },
  [defines.direction.south] = { x = 0, y = (border_width / 2 - 0.01) },
  [defines.direction.west] = { x = -(border_width / 2 - 0.01), y = 0 },
}

local pipe_types = {
  ["pipe"] = true,
  ["pipe-to-ground"] = true,
  ["infinity-pipe"] = true,
}

--- @class Renderer
local renderer = {}

--- @param iterator Iterator
--- @param system FluidSystemData
function renderer.clear(iterator, system)
  local entities = system.entities
  for _, entity_data in pairs(entities) do
    for _, connection_data in pairs(entity_data.connections) do
      if connection_data.line and rendering.is_valid(connection_data.line) then
        rendering.destroy(connection_data.line)
      end
      if connection_data.line_border and rendering.is_valid(connection_data.line_border) then
        rendering.destroy(connection_data.line_border)
      end
      if connection_data.shape and rendering.is_valid(connection_data.shape) then
        rendering.destroy(connection_data.shape)
      end
      if connection_data.shape_border and rendering.is_valid(connection_data.shape_border) then
        rendering.destroy(connection_data.shape_border)
      end
    end
  end
  system.entities = {}
  for unit_number, entity_data in pairs(entities) do
    local unified_data = iterator.entities[unit_number]
    if unified_data then
      renderer.draw_box(iterator, entity_data.entity)
    end
  end
end

--- @param iterator Iterator
--- @param entity_data EntityData
--- @param connection_index integer
--- @param connection PipeConnection
function renderer.start_connection(iterator, entity_data, connection_index, connection)
  local target_owner = connection.target.owner

  local is_underground = connection.connection_type == "underground"

  local source_position = is_underground and entity_data.position or connection.position
  local target_position = is_underground and target_owner.position or connection.target_position
  local direction = get_cardinal_direction(source_position, target_position)

  local shape_position = {
    x = source_position.x + (target_position.x - source_position.x) / 2,
    y = source_position.y + (target_position.y - source_position.y) / 2,
  }
  if not pipe_types[entity_data.type] then
    source_position = shape_position
  end
  if not pipe_types[target_owner.type] then
    target_position = shape_position
  end

  --- @type ConnectionData
  local connection_data = {
    connection = connection,
    direction = direction,
    has_shape = false,
    is_underground = connection.connection_type == "underground",
    shape_position = shape_position,
    source = entity_data.entity,
    source_flow_direction = connection.flow_direction,
    source_position = source_position,
    source_unit_number = entity_data.unit_number,
    target_flow_direction = "input-output", -- Temporary
    target_position = target_position,
    target = target_owner,
    target_unit_number = target_owner.unit_number,
  }
  entity_data.connections[connection_index] = connection_data

  -- if not iterator.in_overlay then
  --   connection_data.line_border = rendering.draw_line({
  --     color = {},
  --     width = 6,
  --     surface = entity_data.surface_index,
  --     from = flib_position.add(source_position, border_offsets[flib_direction.opposite(direction)]),
  --     to = flib_position.add(target_position, border_offsets[direction]),
  --     players = { iterator.player_index },
  --     dash_length = is_underground and (0.25 + border_width) or 0,
  --     gap_length = is_underground and (0.75 - border_width) or 0,
  --     dash_offset = is_underground and 0.42 or 0,
  --     visible = false,
  --   })
  -- end

  if pipe_types[entity_data.type] and pipe_types[target_owner.type] then
    return
  end
  connection_data.has_shape = true
  if iterator.in_overlay then
    return
  end

  if connection.flow_direction == "input" then
    direction = flib_direction.opposite(direction)
  end
  -- connection_data.shape_border = rendering.draw_polygon({
  --   color = {},
  --   vertices = connection.flow_direction == "input-output" and outer_rectangle_points or outer_triangle_points,
  --   orientation = direction / 8,
  --   target = shape_position,
  --   surface = entity_data.surface_index,
  --   players = { iterator.player_index },
  --   visible = false,
  -- })
end

--- @param iterator Iterator
--- @param system FluidSystemData
--- @param entity_data EntityData
--- @param connection_data ConnectionData
function renderer.finish_connection(iterator, system, entity_data, connection_data)
  local direction = connection_data.direction
  connection_data.line = rendering.draw_line({
    color = system.color,
    width = 3,
    surface = entity_data.surface_index,
    from = flib_position.add(connection_data.source_position, offsets[flib_direction.opposite(direction)]),
    to = flib_position.add(connection_data.target_position, offsets[direction]),
    dash_length = connection_data.is_underground and 0.25 or 0,
    gap_length = connection_data.is_underground and 0.75 or 0,
    dash_offset = connection_data.is_underground and 0.42 or 0,
    players = { iterator.player_index },
  })
  if connection_data.line_border then
    rendering.set_visible(connection_data.line_border, true)
  end

  if not connection_data.has_shape then
    return
  end

  local flow_direction = connection_data.source_flow_direction
  if flow_direction == "input-output" and connection_data.target_flow_direction ~= "input-output" then
    flow_direction = connection_data.target_flow_direction
    if flow_direction == "output" then
      direction = flib_direction.opposite(direction)
    end
  elseif flow_direction == "input" then
    direction = flib_direction.opposite(direction)
  end
  if connection_data.shape_border then
    rendering.set_visible(connection_data.shape_border, true)
    rendering.set_orientation(connection_data.shape_border, direction / 8)
    rendering.set_vertices(
      connection_data.shape_border,
      flow_direction == "input-output" and outer_rectangle_points or outer_triangle_points
    )
  end

  connection_data.shape = rendering.draw_polygon({
    color = system.color,
    vertices = flow_direction == "input-output" and inner_rectangle_points or inner_triangle_points,
    orientation = direction / 8,
    target = connection_data.shape_position,
    surface = entity_data.surface_index,
    players = { iterator.player_index },
  })
end

--- @param iterator Iterator
--- @param entity LuaEntity
function renderer.draw_box(iterator, entity)
  if pipe_types[entity.type] then
    return
  end

  local entity_data = iterator.entities[
    entity.unit_number --[[@as uint]]
  ]
  if not entity_data then
    local box = flib_bounding_box.resize(entity.selection_box, -0.1)
    --- @type RenderObjectID?
    local box_border
    -- if not iterator.in_overlay then
    --   box_border = rendering.draw_rectangle({
    --     color = {},
    --     filled = false,
    --     left_top = box.left_top,
    --     right_bottom = box.right_bottom,
    --     width = 3,
    --     surface = entity.surface_index,
    --     players = { iterator.player_index },
    --   })
    -- end
    entity_data = {
      box_border = box_border,
      box = rendering.draw_rectangle({
        color = {},
        filled = true,
        left_top = box.left_top,
        right_bottom = box.right_bottom,
        surface = entity.surface_index,
        players = { iterator.player_index },
      }),
      entity = entity,
      unit_number = entity.unit_number,
    }
    iterator.entities[entity.unit_number] = entity_data
  end

  --- @type Color
  local color = {}
  --- @type FluidSystemID
  local highest_id = 0
  for _, system in pairs(iterator.systems) do
    if system.id > highest_id and system.entities[entity_data.unit_number] then
      color = system.color
      highest_id = system.id
    end
  end
  if highest_id > 0 then
    rendering.set_color(entity_data.box, { r = color.r * 0.4, g = color.g * 0.4, b = color.b * 0.4, a = 0.4 })
  else
    -- Clear box if there are no more entities
    if entity_data.box_border then
      rendering.destroy(entity_data.box_border)
    end
    rendering.destroy(entity_data.box)
    iterator.entities[entity_data.unit_number] = nil
  end
end

return renderer
