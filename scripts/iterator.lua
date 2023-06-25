local flib_bounding_box = require("__flib__/bounding-box")
local flib_direction = require("__flib__/direction")
local flib_position = require("__flib__/position")
local flib_queue = require("__flib__/queue")

--- @alias PlayerIndex uint
--- @alias FluidSystemID uint
--- @alias PlayerIterators table<PlayerIndex, table<FluidSystemID, Iterator>>

--- @class Iterator
--- @field color Color?
--- @field completed table<uint, boolean>
--- @field id FluidSystemID
--- @field in_overlay boolean
--- @field objects RenderObjectID[]
--- @field player LuaPlayer
--- @field queue Queue<LuaEntity>

--- @param starting_entity LuaEntity
--- @param player LuaPlayer
--- @param in_overlay boolean
local function request(starting_entity, player, in_overlay)
  if not global.iterator then
    return
  end

  local fluidbox = starting_entity.fluidbox
  for i = 1, #fluidbox do
    --- @cast i uint
    local id = fluidbox.get_fluid_system_id(i)
    if not id then
      goto continue
    end

    local player_iterators = global.iterator[player.index]
    if not player_iterators then
      player_iterators = {}
      global.iterator[player.index] = player_iterators
    end
    local iterator = player_iterators[id]
    if iterator then
      if in_overlay and not iterator.completed[starting_entity.unit_number] then
        flib_queue.push_back(iterator.queue, starting_entity)
      end
      goto continue
    end

    local queue = flib_queue.new()
    flib_queue.push_back(queue, starting_entity)

    local color = { r = 0.3, g = 0.3, b = 0.3 }
    local contents = fluidbox.get_fluid_system_contents(i)
    if contents and next(contents) then
      color = global.fluid_colors[next(contents)]
    end

    --- @type Iterator
    player_iterators[id] = {
      completed = {},
      color = color,
      id = id,
      in_overlay = in_overlay,
      objects = {},
      player = player,
      queue = queue,
    }

    ::continue::
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

--- @param connection PipeConnection
--- @param color Color
--- @param surface_index uint
--- @param players PlayerIndex[]
--- @param objects RenderObjectID[]
local function draw_arrow(connection, color, surface_index, players, objects)
  local arrow_target = flib_position.lerp(connection.position, connection.target_position, 0.5)
  local direction = flib_direction.from_positions(connection.position, connection.target_position, true)
  if connection.type == "input" then
    direction = flib_direction.opposite(direction)
  end
  objects[#objects + 1] = rendering.draw_polygon({
    color = {},
    vertices = connection.type == "input-output" and outer_rectangle_points or outer_triangle_points,
    orientation = direction / 8,
    target = arrow_target,
    surface = surface_index,
    players = players,
  })
  objects[#objects + 1] = rendering.draw_polygon({
    color = color,
    vertices = connection.type == "input-output" and inner_rectangle_points or inner_triangle_points,
    orientation = direction / 8,
    target = arrow_target,
    surface = surface_index,
    players = players,
  })
end

local pipe_types = {
  ["pipe"] = true,
  ["pipe-to-ground"] = true,
}

--- @param iterator Iterator
--- @param entity LuaEntity
local function iterate_entity(iterator, entity)
  if iterator.completed[entity.unit_number] then
    return
  end

  local players_array = { iterator.player.index }

  if entity.type == "storage-tank" or entity.type == "pump" then
    -- TODO: Cache these ahead of time
    local box = flib_bounding_box.move(entity.prototype.collision_box, entity.position)
    if (entity.direction - 2) % 4 == 0 then
      box = flib_bounding_box.rotate(box)
    end
    box = flib_bounding_box.resize(flib_bounding_box.ceil(box), -0.15)

    iterator.objects[#iterator.objects + 1] = rendering.draw_rectangle({
      color = {},
      left_top = box.left_top,
      right_bottom = box.right_bottom,
      width = 3,
      surface = entity.surface_index,
      players = players_array,
    })
    iterator.objects[#iterator.objects + 1] = rendering.draw_rectangle({
      color = { r = iterator.color.r * 0.4, g = iterator.color.g * 0.4, b = iterator.color.b * 0.4, a = 0.4 },
      left_top = box.left_top,
      right_bottom = box.right_bottom,
      filled = true,
      surface = entity.surface_index,
      players = players_array,
    })
  end

  local fluidbox = entity.fluidbox
  for i = 1, #fluidbox do
    --- @cast i uint
    local id = fluidbox.get_fluid_system_id(i)
    if id ~= iterator.id then
      goto continue
    end

    local connections = fluidbox.get_pipe_connections(i)
    for _, connection in pairs(connections) do
      if not connection.target then
        goto inner_continue
      end

      local owner = connection.target.owner
      if iterator.completed[owner.unit_number] then
        if not pipe_types[entity.type] then
          draw_arrow(connection, iterator.color, entity.surface_index, players_array, iterator.objects)
        end
        goto inner_continue
      end

      local from = connection.is_underground and entity or connection.position
      local to = connection.is_underground and owner or connection.target_position
      if not pipe_types[entity.type] then
        from = flib_position.lerp(connection.position, connection.target_position, 0.5)
      end
      if not pipe_types[owner.type] then
        to = flib_position.lerp(connection.position, connection.target_position, 0.5)
      end

      iterator.objects[#iterator.objects + 1] = rendering.draw_line({
        color = {},
        width = 6,
        surface = entity.surface_index,
        from = from,
        to = to,
        players = players_array,
        dash_length = connection.is_underground and 0.25 or 0,
        gap_length = connection.is_underground and 0.25 or 0,
      })

      if not pipe_types[entity.type] then
        draw_arrow(connection, iterator.color, entity.surface_index, players_array, iterator.objects)
      end

      iterator.objects[#iterator.objects + 1] = rendering.draw_line({
        color = iterator.color,
        width = 3,
        surface = entity.surface_index,
        from = from,
        to = to,
        dash_length = connection.is_underground and 0.25 or 0,
        gap_length = connection.is_underground and 0.25 or 0,
        players = players_array,
      })

      if not iterator.in_overlay then
        flib_queue.push_back(iterator.queue, owner)
      end

      ::inner_continue::
    end

    ::continue::
  end

  iterator.completed[entity.unit_number] = true
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
local function clear(iterator)
  for _, id in pairs(iterator.objects) do
    rendering.destroy(id)
  end
  local player_iterators = global.iterator[iterator.player.index]
  player_iterators[iterator.id] = nil
  if not next(player_iterators) then
    global.iterator[iterator.player.index] = nil
  end
end

--- @param player LuaPlayer
local function clear_all(player)
  if not global.iterator then
    return
  end
  local player_iterators = global.iterator[player.index]
  if not player_iterators then
    return
  end
  for _, iterator in pairs(player_iterators) do
    clear(iterator)
  end
end

--- @param iterator Iterator
local function bring_to_front(iterator)
  for _, id in pairs(iterator.objects) do
    rendering.bring_to_front(id)
  end
end

--- @param player LuaPlayer
local function bring_all_to_front(player)
  if not global.iterator then
    return
  end
  local player_iterators = global.iterator[player.index]
  if not player_iterators then
    return
  end
  for _, iterator in pairs(player_iterators) do
    bring_to_front(iterator)
  end
end

--- @param starting_entity LuaEntity
--- @param player LuaPlayer
local function request_or_clear(starting_entity, player)
  if not global.iterator then
    return
  end
  local player_iterators = global.iterator[player.index]
  if not player_iterators then
    request(starting_entity, player, false)
    return
  end
  local did_clear = false
  for _, iterator in pairs(player_iterators) do
    if iterator.completed[starting_entity.unit_number] then
      did_clear = true
      clear(iterator)
    end
  end
  if not did_clear then
    request(starting_entity, player, false)
  end
end

local function on_tick()
  if not global.iterator then
    return
  end
  local entities_per_tick = game.is_multiplayer() and 5 or 10
  for _, iterators in pairs(global.iterator) do
    for _, iterator in pairs(iterators) do
      iterate(iterator, entities_per_tick)
    end
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
    clear_all(player)
    return
  end
  request_or_clear(entity, player)
end

local iterator = {}

function iterator.on_init()
  --- @type PlayerIterators
  global.iterator = {}
end

iterator.events = {
  [defines.events.on_tick] = on_tick,
  ["pv-toggle-hover"] = on_toggle_hover,
}

iterator.bring_all_to_front = bring_all_to_front
iterator.clear_all = clear_all
iterator.request = request

return iterator
