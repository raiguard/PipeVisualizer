local flib_bounding_box = require("__flib__/bounding-box")
local flib_direction = require("__flib__/direction")
local flib_position = require("__flib__/position")

-- --- @param c1 Color
-- --- @param c2 Color
-- local function mix_colors(c1, c2)
--   return {
--     r = math.min(c1.r + c2.r, 1) * 0.4,
--     g = math.min(c1.g + c2.g, 1) * 0.4,
--     b = math.min(c1.b + c2.b, 1) * 0.4,
--     a = 0.4,
--   }
-- end

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

local pipe_types = {
  ["pipe"] = true,
  ["pipe-to-ground"] = true,
  ["infinity-pipe"] = true,
}

--- @param entity LuaEntity
local function get_entity_data(entity)
  local unit_number = entity.unit_number --[[@as uint]]
  local data = global.renderer[unit_number]
  if not data then
    data = {
      entity = entity,
      connections = {},
    }
    global.renderer[unit_number] = data
  end
  return data
end

--- @param unit_number UnitNumber
--- @param entity_data EntityRenderData
local function clear_entity(unit_number, entity_data)
  if entity_data.box_border then
    rendering.destroy(entity_data.box_border)
  end
  if entity_data.box then
    rendering.destroy(entity_data.box)
  end
  global.renderer[unit_number] = nil
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

--- @param entity LuaEntity
function renderer.bring_to_front(entity)
  local entity_data = get_entity_data(entity)
  for _, connection_data in pairs(entity_data.connections) do
    rendering.bring_to_front(connection_data.line)
    if connection_data.shape then
      rendering.bring_to_front(connection_data.shape)
    end
  end
end

--- @param unit_number UnitNumber
--- @param fluid_system_id uint
function renderer.clear(unit_number, fluid_system_id)
  local entity_data = global.renderer[unit_number]
  if not entity_data then
    return
  end
  for target_unit_number, connection_data in pairs(entity_data.connections) do
    if connection_data.fluid_system_id == fluid_system_id then
      clear_connection(connection_data)
      entity_data.connections[target_unit_number] = nil
      local target_data = global.renderer[target_unit_number]
      if target_data then
        target_data.connections[unit_number] = nil
        if not next(target_data.connections) then
          clear_entity(target_unit_number, target_data)
        end
      end
    end
  end
  if not next(entity_data.connections) then
    clear_entity(unit_number, entity_data)
  end
end

local border_offsets = {
  [defines.direction.north] = { x = 0, y = -0.09 },
  [defines.direction.east] = { x = 0.09, y = 0 },
  [defines.direction.south] = { x = 0, y = 0.09 },
  [defines.direction.west] = { x = -0.09, y = 0 },
}

local offsets = {
  [defines.direction.north] = { x = 0, y = -0.042 },
  [defines.direction.east] = { x = 0.042, y = 0 },
  [defines.direction.south] = { x = 0, y = 0.042 },
  [defines.direction.west] = { x = -0.042, y = 0 },
}

--- @param connection PipeConnection
--- @param entity LuaEntity
--- @param target LuaEntity
--- @param color Color
--- @param players_array PlayerIndex[]
function renderer.draw_connection(connection, entity, target, fluid_system_id, color, players_array)
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

  local entity_data = get_entity_data(entity)
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
        players = players_array,
        dash_length = is_underground and 0.349 or 0,
        gap_length = is_underground and 0.651 or 0,
        dash_offset = is_underground and 0.375 or 0,
      }),
      line = rendering.draw_line({
        color = color,
        width = 3,
        surface = entity.surface_index,
        from = flib_position.add(from, offsets[flib_direction.opposite(direction)]),
        to = flib_position.add(to, offsets[direction]),
        dash_length = is_underground and 0.25 or 0,
        gap_length = is_underground and 0.75 or 0,
        dash_offset = is_underground and 0.375 or 0,
        players = players_array,
      }),
    }
    entity_data.connections[target.unit_number] = connection_data
    local target_data = get_entity_data(target)
    target_data.connections[entity.unit_number] = connection_data
  end

  if pipe_types[entity.type] then
    renderer.bring_to_front(entity)
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
      players = players_array,
    })
    connection_data.shape = rendering.draw_polygon({
      color = color,
      vertices = connection.flow_direction == "input-output" and inner_rectangle_points or inner_triangle_points,
      orientation = direction / 8,
      target = shape_position,
      surface = entity.surface_index,
      players = players_array,
    })
  end

  renderer.bring_to_front(entity)
end

--- @param entity LuaEntity
--- @param color Color
--- @param players_array PlayerIndex[]
function renderer.draw_entity(entity, color, players_array)
  if pipe_types[entity.type] then
    return
  end

  local entity_data = global.renderer[
    entity.unit_number --[[@as uint]]
  ]
  if not entity_data then
    entity_data = {
      connections = {},
      entity = entity,
    }
    global.renderer[entity.unit_number] = entity_data
  end
  if not entity_data.box then
    local box = flib_bounding_box.resize(flib_bounding_box.ceil(entity.bounding_box), -0.15)
    entity_data.box_border = rendering.draw_rectangle({
      color = {},
      left_top = box.left_top,
      right_bottom = box.right_bottom,
      width = 3,
      surface = entity.surface_index,
      players = players_array,
    })
    entity_data.box = rendering.draw_rectangle({
      color = { r = color.r * 0.4, g = color.g * 0.4, b = color.b * 0.4, a = 0.4 },
      left_top = box.left_top,
      right_bottom = box.right_bottom,
      filled = true,
      surface = entity.surface_index,
      players = players_array,
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

--- @class EntityRenderData
--- @field box_border RenderObjectID?
--- @field box RenderObjectID?
--- @field connections table<UnitNumber, ConnectionRenderData>
--- @field entity LuaEntity

--- @class ConnectionRenderData
--- @field color Color
--- @field entity LuaEntity
--- @field flow_direction string
--- @field fluid_system_id uint
--- @field line_border RenderObjectID
--- @field line RenderObjectID
--- @field shape_border RenderObjectID?
--- @field shape RenderObjectID?
--- @field target LuaEntity

function renderer.on_init()
  --- @type table<UnitNumber, EntityRenderData>
  global.renderer = {}
end

return renderer
