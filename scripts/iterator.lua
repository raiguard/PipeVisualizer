local flib_bounding_box = require("__flib__/bounding-box")
local flib_queue = require("__flib__/queue")

--- @alias FlowDirection "input"|"output"|"input-output"
--- @alias FluidSystemID uint
--- @alias PlayerIndex uint

--- @class ConnectionData
--- @field boundary_position MapPosition
--- @field connection_index uint
--- @field fluidbox_index uint

--- @class EntityData
--- @field connections RenderObjectID[]
--- @field entity LuaEntity
--- @field fluidbox LuaFluidBox
--- @field shape RenderObjectID
--- @field pending_connections ConnectionData[]

--- @class FluidSystemData
--- @field color Color
--- @field entities table<UnitNumber, EntityData>
--- @field id FluidSystemID

--- @class Iterator
--- @field entities table<UnitNumber, EntityData>
--- @field in_overlay boolean
--- @field objects RenderObjectID[]
--- @field player_index PlayerIndex
--- @field queue Queue<LuaEntity>
--- @field systems table<FluidSystemID, FluidSystemData>

--- @param starting_entity LuaEntity
--- @param player_index PlayerIndex
--- @param in_overlay boolean
local function request(starting_entity, player_index, in_overlay)
  if not global.iterator then
    return
  end

  local iterator = global.iterator[player_index]
  if not iterator then
    --- @type Iterator
    iterator = {
      entities = {},
      in_overlay = in_overlay,
      objects = {},
      player_index = player_index,
      queue = flib_queue.new(),
      systems = {},
    }
  end

  local should_iterate = false
  local fluidbox = starting_entity.fluidbox
  for i = 1, #fluidbox do
    --- @cast i uint
    local id = fluidbox.get_fluid_system_id(i)
    if not id then
      goto continue
    end

    local system = iterator.systems[id]
    if system then
      if not system.entities[starting_entity.unit_number] then
        should_iterate = true
      end
      goto continue
    end

    -- TODO: Handle when there's no fluid in the system
    local color = { r = 0.3, g = 0.3, b = 0.3 }
    local contents = fluidbox.get_fluid_system_contents(i)
    if contents and next(contents) then
      color = global.fluid_colors[next(contents)]
    end

    --- @type FluidSystemData
    iterator.systems[id] = {
      color = color,
      entities = {},
      id = id,
    }

    should_iterate = true

    ::continue::
  end

  if should_iterate then
    flib_queue.push_back(iterator.queue, starting_entity)
    global.iterator[player_index] = iterator
  end
end

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

-- 2 pixels; 2/32 of a tile
local line_radius = 0.0625

--- @type table<defines.direction, ScriptRenderVertexTarget>
local starting_box_corners = {
  [defines.direction.north] = { target = { x = -line_radius, y = line_radius } },
  [defines.direction.east] = { target = { x = -line_radius, y = -line_radius } },
  [defines.direction.south] = { target = { x = line_radius, y = -line_radius } },
  [defines.direction.west] = { target = { x = line_radius, y = line_radius } },
}

local pipe_vertices = {
  [defines.direction.north] = {
    -- { target = { x = -line_radius, y = line_radius } },
    { target = { x = -line_radius, y = -0.5 } },
    { target = { x = line_radius, y = -0.5 } },
    { target = { x = line_radius, y = line_radius } },
    { target = { x = -line_radius, y = line_radius } },
  },
  [defines.direction.east] = {
    -- { target = { x = -line_radius, y = -line_radius } },
    { target = { x = 0.5, y = -line_radius } },
    { target = { x = 0.5, y = line_radius } },
    { target = { x = -line_radius, y = line_radius } },
    { target = { x = -line_radius, y = -line_radius } },
  },
  [defines.direction.south] = {
    -- { target = { x = line_radius, y = -line_radius } },
    { target = { x = line_radius, y = 0.5 } },
    { target = { x = -line_radius, y = 0.5 } },
    { target = { x = -line_radius, y = -line_radius } },
    { target = { x = line_radius, y = -line_radius } },
  },
  [defines.direction.west] = {
    -- { target = { x = line_radius, y = line_radius } },
    { target = { x = -0.5, y = line_radius } },
    { target = { x = -0.5, y = -line_radius } },
    { target = { x = line_radius, y = -line_radius } },
    { target = { x = line_radius, y = line_radius } },
  },
}

local pipe_types = {
  ["infinity-pipe"] = true,
  ["pipe-to-ground"] = true,
  ["pipe"] = true,
}

--- @type Color
local default_color = { r = 0.32, g = 0.32, b = 0.32, a = 0.4 }

--- @param iterator Iterator
--- @param entity_data EntityData
local function draw_entity(iterator, entity_data)
  local complex_type = not pipe_types[entity_data.entity.type]
  local fluidbox = entity_data.fluidbox
  --- @type ScriptRenderVertexTarget[]
  local vertices
  if complex_type then
    local box = flib_bounding_box.resize(entity_data.entity.selection_box, -0.1)
    entity_data.shape = rendering.draw_rectangle({
      color = default_color,
      filled = true,
      left_top = box.left_top,
      right_bottom = box.right_bottom,
      surface = entity_data.entity.surface_index,
      players = { iterator.player_index },
    })
  else
    vertices = {}
    entity_data.shape = rendering.draw_polygon({
      color = default_color,
      filled = true,
      target = entity_data.entity.position,
      vertices = { starting_box_corners[defines.direction.west] },
      surface = entity_data.entity.surface_index,
      players = { iterator.player_index },
    })
  end
  --- @type Color?
  local shape_color
  local highest_id = 0
  for fluidbox_index = 1, #fluidbox do
    --- @cast fluidbox_index uint
    local id = fluidbox.get_fluid_system_id(fluidbox_index)
    if not id then
      goto continue
    end
    local system_data = iterator.systems[id]
    if not system_data then
      goto continue
    end
    local color = system_data.color
    if id > highest_id then
      shape_color = color
      highest_id = id
    end
    local pipe_connections = fluidbox.get_pipe_connections(fluidbox_index)
    for connection_index = 1, #pipe_connections do
      --- @cast connection_index uint
      local connection = pipe_connections[connection_index]
      local direction = get_cardinal_direction(connection.position, connection.target_position)
      if vertices then
        vertices[#vertices + 1] = starting_box_corners[direction]
      end

      if not connection.target then
        goto inner_continue
      end

      local boundary_position = {
        x = connection.position.x + (connection.target_position.x - connection.position.x) / 2,
        y = connection.position.y + (connection.target_position.y - connection.position.y) / 2,
      }

      if complex_type then
        if connection.flow_direction == "input" then
          direction = (direction + 4) % 8 -- Opposite
        end
        entity_data.connections[#entity_data.connections + 1] = rendering.draw_polygon({
          color = color,
          vertices = connection.flow_direction == "input-output" and inner_rectangle_points or inner_triangle_points,
          orientation = direction / 8,
          target = boundary_position,
          surface = entity_data.entity.surface_index,
          players = { iterator.player_index },
        })
      elseif vertices then
        -- TODO: Account for selection box instead of using hardcoded numbers
        -- local selection_box = entity_data.entity.prototype.selection_box
        for _, vertex in pairs(pipe_vertices[direction]) do
          vertices[#vertices + 1] = vertex
        end
      end

      if connection.connection_type == "underground" then
        local found = false
        local target_entity_data = iterator.entities[
          connection.target.owner.unit_number --[[@as uint]]
        ]
        if target_entity_data then
          for i, pending in pairs(target_entity_data.pending_connections) do
            if
              pending.fluidbox_index == connection.target_fluidbox_index
              and pending.connection_index == connection.target_pipe_connection_index
            then
              found = true
              target_entity_data.pending_connections[i] = nil
              entity_data.connections[#entity_data.connections + 1] = rendering.draw_line({
                color = color,
                width = 4,
                surface = entity_data.entity.surface_index,
                from = boundary_position,
                to = pending.boundary_position,
                dash_length = 0.25,
                gap_length = 0.75,
                dash_offset = 0.875,
                players = { iterator.player_index },
              })
              break
            end
          end
        end
        if not found then
          entity_data.pending_connections[#entity_data.pending_connections + 1] = {
            fluidbox_index = fluidbox_index,
            connection_index = connection_index,
            boundary_position = boundary_position,
          }
        end
      end

      ::inner_continue::
    end

    ::continue::
  end
  if shape_color then
    if complex_type then
      shape_color = { r = shape_color.r * 0.4, g = shape_color.g * 0.4, b = shape_color.b * 0.4, a = 0.4 }
    end
    rendering.set_color(entity_data.shape, shape_color)
  end
  if vertices then
    vertices[#vertices + 1] = starting_box_corners[defines.direction.north]
    rendering.set_vertices(entity_data.shape, vertices)
  end
end

--- @param iterator Iterator
--- @param entity LuaEntity
local function iterate_entity(iterator, entity)
  local entity_data = iterator.entities[
    entity.unit_number --[[@as uint]]
  ]
  if entity_data then
    return
  end
  entity_data = {
    connections = {},
    entity = entity,
    fluidbox = entity.fluidbox,
    shape = 0, -- Temporary
    pending_connections = {},
  }
  iterator.entities[entity.unit_number] = entity_data

  draw_entity(iterator, entity_data)

  if iterator.in_overlay then
    return
  end

  local fluidbox = entity.fluidbox
  for fluidbox_index = 1, #fluidbox do
    --- @cast fluidbox_index uint
    local id = fluidbox.get_fluid_system_id(fluidbox_index)
    local system = iterator.systems[id]
    if not system then
      goto continue
    end
    system.entities[entity.unit_number] = entity_data
    for _, neighbour_fluidbox in pairs(fluidbox.get_connections(fluidbox_index)) do
      flib_queue.push_back(iterator.queue, neighbour_fluidbox.owner)
    end

    -- local entity_data = system.entities[entity.unit_number]
    -- if not entity_data then
    --   --- @type EntityData
    --   entity_data = {
    --     connections = {},
    --     entity = entity,
    --     position = entity.position,
    --     surface_index = entity.surface_index,
    --     type = entity.type,
    --     unit_number = entity.unit_number,
    --   }
    --   system.entities[entity.unit_number] = entity_data
    -- end

    -- --- @type table<integer, ConnectionData>
    -- local existing_connections = {}
    -- local connections = fluidbox.get_pipe_connections(fluidbox_index)
    -- for connection_index = 1, #connections do
    --   if entity_data.connections[connection_index] then
    --     goto inner_continue
    --   end
    --   local connection = connections[connection_index]
    --   if not connection.target then
    --     goto inner_continue
    --   end

    --   local target_owner = connection.target.owner

    --   local target_data = system.entities[target_owner.unit_number]
    --   if target_data then
    --     local connection_data = target_data.connections[connection.target_pipe_connection_index]
    --     entity_data.connections[connection_index] = connection_data
    --     connection_data.target_flow_direction = connection.flow_direction
    --     existing_connections[connection_index] = connection_data
    --     goto inner_continue
    --   end

    --   renderer.start_connection(iterator, entity_data, connection_index, connection)

    --   if not iterator.in_overlay then
    --     flib_queue.push_back(iterator.queue, target_owner)
    --   end

    --   ::inner_continue::
    -- end

    -- for _, connection_data in pairs(existing_connections) do
    --   renderer.finish_connection(iterator, system, entity_data, connection_data)
    -- end

    ::continue::
  end
end

--- @param iterator Iterator
--- @param entities_per_tick integer
local function iterate(iterator, entities_per_tick)
  for _ = 1, entities_per_tick do
    local entity = flib_queue.pop_front(iterator.queue)
    if not entity then
      return
    end
    iterate_entity(iterator, entity)
  end
end

--- @param iterator Iterator
--- @param system FluidSystemData
local function clear(iterator, system)
  for unit_number, entity_data in pairs(system.entities) do
    rendering.destroy(entity_data.shape)
    for _, shape in pairs(entity_data.connections) do
      rendering.destroy(shape)
    end
    iterator.entities[unit_number] = nil
  end
  iterator.systems[system.id] = nil
  if not next(iterator.systems) then
    global.iterator[iterator.player_index] = nil
  end
end

--- @param player_index PlayerIndex
local function clear_all(player_index)
  if not global.iterator then
    return
  end
  local iterator = global.iterator[player_index]
  if not iterator then
    return
  end
  for _, entity_data in pairs(iterator.entities) do
    rendering.destroy(entity_data.shape)
    for _, shape in pairs(entity_data.connections) do
      rendering.destroy(shape)
    end
  end
  global.iterator[player_index] = nil
end

--- @param starting_entity LuaEntity
--- @param player_index PlayerIndex
local function request_or_clear(starting_entity, player_index)
  if not global.iterator then
    return
  end
  local iterator = global.iterator[player_index]
  if not iterator then
    request(starting_entity, player_index, false)
    return
  end
  local fluidbox = starting_entity.fluidbox
  for fluidbox_index = 1, #fluidbox do
    --- @cast fluidbox_index uint
    local id = fluidbox.get_fluid_system_id(fluidbox_index)
    if id and not iterator.systems[id] then
      request(starting_entity, player_index, false)
      return
    end
  end
  for fluidbox_index = 1, #fluidbox do
    --- @cast fluidbox_index uint
    local id = fluidbox.get_fluid_system_id(fluidbox_index)
    if id and iterator.systems[id] then
      clear(iterator, iterator.systems[id])
    end
  end
end

local function on_tick()
  if not global.iterator then
    return
  end
  local entities_per_tick = math.ceil(100 / table_size(global.iterator))
  -- local entities_per_tick = 1
  for _, iterator in pairs(global.iterator) do
    iterate(iterator, entities_per_tick)
  end
end

--- @param e EventData.CustomInputEvent
local function on_toggle_hover(e)
  local player = game.get_player(e.player_index)
  if not player then
    return
  end
  local entity = player.selected
  if not entity then
    clear_all(e.player_index)
    return
  end
  request_or_clear(entity, e.player_index)
end

local iterator = {}

function iterator.on_init()
  --- @type table<PlayerIndex, Iterator>
  global.iterator = {}

  -- local vertices = {
  --   -- North
  --   { -line_radius, line_radius },
  --   { -line_radius, -0.5 },
  --   { line_radius, -0.5 },
  --   { line_radius, line_radius },
  --   { -line_radius, line_radius },
  --   -- East
  --   { -line_radius, -line_radius },
  --   { 0.5, -line_radius },
  --   { 0.5, line_radius },
  --   { -line_radius, line_radius },
  --   { -line_radius, -line_radius },
  --   -- South
  --   { line_radius, -line_radius },
  --   { line_radius, 0.5 },
  --   { -line_radius, 0.5 },
  --   { -line_radius, -line_radius },
  --   { line_radius, -line_radius },
  --   -- West
  --   { -line_radius, line_radius },
  --   { -0.5, line_radius },
  --   { -0.5, -line_radius },
  --   { line_radius, -line_radius },
  --   { -line_radius, line_radius },
  -- }

  -- local real_vertices = {}
  -- for i, vertex in pairs(vertices) do
  --   real_vertices[i] = { target = vertex }
  -- end

  -- -- 2 pixels; 2/32 of a tile
  -- rendering.draw_polygon({
  --   color = { b = 1, g = 1 },
  --   filled = true,
  --   target = { 0.5, 0.5 },
  --   vertices = real_vertices,
  --   surface = 1,
  -- })
end

iterator.events = {
  [defines.events.on_tick] = on_tick,
  ["pv-visualize-selected"] = on_toggle_hover,
}

iterator.clear_all = clear_all
iterator.request = request

return iterator
