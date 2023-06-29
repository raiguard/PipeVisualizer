local flib_bounding_box = require("__flib__/bounding-box")
local flib_direction = require("__flib__/direction")
local flib_position = require("__flib__/position")

--- @class ConnectionRenderData
--- @field color Color
--- @field entity LuaEntity
--- @field flow_direction string
--- @field fluid_system_id uint
--- @field line_border RenderObjectID
--- @field line RenderObjectID
--- @field player_index PlayerIndex
--- @field shape_border RenderObjectID?
--- @field shape RenderObjectID?
--- @field target LuaEntity

--- @class EntityRenderData
--- @field box_border RenderObjectID?
--- @field box RenderObjectID?
--- @field connections table<UnitNumber, ConnectionRenderData>
--- @field entity LuaEntity
--- @field player_index PlayerIndex
--- @field unit_number UnitNumber

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

--- @type table<defines.direction, Vector>
local border_offsets = {
  [defines.direction.north] = { x = 0, y = -0.09 },
  [defines.direction.east] = { x = 0.09, y = 0 },
  [defines.direction.south] = { x = 0, y = 0.09 },
  [defines.direction.west] = { x = -0.09, y = 0 },
}

--- @type table<defines.direction, Vector>
local offsets = {
  [defines.direction.north] = { x = 0, y = -0.042 },
  [defines.direction.east] = { x = 0.042, y = 0 },
  [defines.direction.south] = { x = 0, y = 0.042 },
  [defines.direction.west] = { x = -0.042, y = 0 },
}

local pipe_types = {
  ["pipe"] = true,
  ["pipe-to-ground"] = true,
  ["infinity-pipe"] = true,
}

--- @param entity LuaEntity
--- @param player_index PlayerIndex
--- @return EntityRenderData
local function get_entity_data(entity, player_index)
  local player_renderer = global.renderer[player_index]
  if not player_renderer then
    player_renderer = {}
    global.renderer[player_index] = player_renderer
  end
  local unit_number = entity.unit_number --[[@as uint]]
  local entity_data = player_renderer[unit_number]
  if not entity_data then
    entity_data = {
      entity = entity,
      connections = {},
      player_index = player_index,
      unit_number = unit_number,
    }
    player_renderer[unit_number] = entity_data
  end
  return entity_data
end

--- @param entity_data EntityRenderData
local function clear_entity(entity_data)
  if entity_data.box_border then
    rendering.destroy(entity_data.box_border)
  end
  if entity_data.box then
    rendering.destroy(entity_data.box)
  end
  local player_renderer = global.renderer[entity_data.player_index]
  player_renderer[entity_data.unit_number] = nil
  if not next(player_renderer) then
    global.renderer[entity_data.player_index] = nil
  end
end

--- @param connection_data ConnectionRenderData
local function clear_connection(connection_data)
  rendering.destroy(connection_data.line_border)
  rendering.destroy(connection_data.line)
  if connection_data.shape_border then
    rendering.destroy(connection_data.shape_border)
  end
  if connection_data.shape then
    rendering.destroy(connection_data.shape)
  end
end

--- @class Renderer
local renderer = {}

--- @param entity_data EntityRenderData
function renderer.bring_to_front(entity_data)
  for _, connection_data in pairs(entity_data.connections) do
    rendering.bring_to_front(connection_data.line)
    if connection_data.shape then
      rendering.bring_to_front(connection_data.shape)
    end
  end
end

--- @param entity LuaEntity
--- @param fluid_system_id uint
--- @param player_index PlayerIndex
function renderer.clear(entity, fluid_system_id, player_index)
  local entity_data = get_entity_data(entity, player_index)
  for target_unit_number, connection_data in pairs(entity_data.connections) do
    if connection_data.fluid_system_id == fluid_system_id then
      clear_connection(connection_data)
      entity_data.connections[target_unit_number] = nil
      local target_data = get_entity_data(connection_data.target, player_index)
      target_data.connections[entity_data.unit_number] = nil
      if not next(target_data.connections) then
        clear_entity(target_data)
      end
    end
  end
  if not next(entity_data.connections) then
    clear_entity(entity_data)
  end
end

--- @param connection PipeConnection
--- @param entity LuaEntity
--- @param target LuaEntity
--- @param color Color
--- @param player_index PlayerIndex
function renderer.draw_connection(connection, entity, target, fluid_system_id, color, player_index)
  local is_underground = connection.connection_type == "underground"

  local direction = flib_direction.from_positions(connection.position, connection.target_position, true)
  local from = is_underground and entity.position or connection.position
  local to = is_underground and target.position or connection.target_position

  local shape_position = flib_position.lerp(connection.position, connection.target_position, 0.5)
  if not pipe_types[entity.type] then
    from = shape_position
  end
  if not pipe_types[target.type] then
    to = shape_position
  end

  local entity_data = get_entity_data(entity, player_index)
  local connection_data = entity_data.connections[target.unit_number]
  if not connection_data then
    --- @type ConnectionRenderData
    connection_data = {
      color = color,
      fluid_system_id = fluid_system_id,
      entity = entity,
      target = target,
      line_border = rendering.draw_line({
        color = {},
        width = 6,
        surface = entity.surface_index,
        from = flib_position.add(from, border_offsets[flib_direction.opposite(direction)]),
        to = flib_position.add(to, border_offsets[direction]),
        players = { player_index },
        dash_length = is_underground and 0.349 or 0,
        gap_length = is_underground and 0.651 or 0,
        dash_offset = is_underground and 0.42 or 0,
      }),
      line = rendering.draw_line({
        color = color,
        width = 3,
        surface = entity.surface_index,
        from = flib_position.add(from, offsets[flib_direction.opposite(direction)]),
        to = flib_position.add(to, offsets[direction]),
        dash_length = is_underground and 0.25 or 0,
        gap_length = is_underground and 0.75 or 0,
        dash_offset = is_underground and 0.42 or 0,
        players = { player_index },
      }),
      player_index = player_index,
    }
    entity_data.connections[target.unit_number] = connection_data
    local target_data = get_entity_data(target, player_index)
    target_data.connections[entity.unit_number] = connection_data
  end

  if pipe_types[entity.type] then
    renderer.bring_to_front(entity_data)
    return
  end

  if connection_data.shape and connection_data.flow_direction ~= "input-output" then
    return
  end

  if connection.flow_direction == "input" then
    direction = flib_direction.opposite(direction)
  end
  connection_data.flow_direction = connection.flow_direction
  if connection_data.shape then
    rendering.set_vertices(
      connection_data.shape_border,
      connection.flow_direction == "input-output" and outer_rectangle_points or outer_triangle_points
    )
    rendering.set_vertices(
      connection_data.shape,
      connection.flow_direction == "input-output" and inner_rectangle_points or inner_triangle_points
    )
  else
    connection_data.shape_border = rendering.draw_polygon({
      color = {},
      vertices = connection.flow_direction == "input-output" and outer_rectangle_points or outer_triangle_points,
      orientation = direction / 8,
      target = shape_position,
      surface = entity.surface_index,
      players = { player_index },
    })
    connection_data.shape = rendering.draw_polygon({
      color = color,
      vertices = connection.flow_direction == "input-output" and inner_rectangle_points or inner_triangle_points,
      orientation = direction / 8,
      target = shape_position,
      surface = entity.surface_index,
      players = { player_index },
    })
  end

  renderer.bring_to_front(entity_data)
end

--- @param entity LuaEntity
--- @param color Color
--- @param player_index PlayerIndex
function renderer.draw_entity(entity, color, player_index)
  if pipe_types[entity.type] then
    return
  end

  local entity_data = get_entity_data(entity, player_index)
  if not entity_data.box then
    local box = flib_bounding_box.resize(flib_bounding_box.ceil(entity.bounding_box), -0.15)
    entity_data.box_border = rendering.draw_rectangle({
      color = {},
      left_top = box.left_top,
      right_bottom = box.right_bottom,
      width = 3,
      surface = entity.surface_index,
      players = { player_index },
    })
    entity_data.box = rendering.draw_rectangle({
      color = { r = color.r * 0.4, g = color.g * 0.4, b = color.b * 0.4, a = 0.4 },
      left_top = box.left_top,
      right_bottom = box.right_bottom,
      filled = true,
      surface = entity.surface_index,
      players = { player_index },
    })
    return
  end

  --- @type Color
  local color = { r = 0.3, g = 0.3, b = 0.3 }
  local lowest = math.huge
  for _, connection_data in pairs(entity_data.connections) do
    if connection_data.fluid_system_id < lowest then
      color = connection_data.color
      lowest = connection_data.fluid_system_id
    end
  end
  rendering.set_color(entity_data.box, { r = color.r * 0.4, g = color.g * 0.4, b = color.b * 0.4, a = 0.4 })
end

function renderer.on_init()
  --- @type table<PlayerIndex, table<UnitNumber, EntityRenderData>>
  global.renderer = {}
end

return renderer
