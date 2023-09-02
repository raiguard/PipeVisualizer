local flib_bounding_box = require("__flib__/bounding-box")
local flib_position = require("__flib__/position")
local flib_queue = require("__flib__/queue")

--- @alias FlowDirection "input"|"output"|"input-output"
--- @alias FluidSystemID uint
--- @alias PlayerIndex uint

--- @class ConnectionData
--- @field position MapPosition
--- @field connection_index uint
--- @field fluidbox_index uint

--- @class EntityData
--- @field connections table<FluidSystemID, RenderObjectID[]>
--- @field entity LuaEntity
--- @field fluidbox LuaFluidBox
--- @field shape RenderObjectID?
--- @field unit_number UnitNumber

--- @class Iterator
--- @field entities table<UnitNumber, EntityData>
--- @field in_overlay boolean
--- @field player_index PlayerIndex
--- @field queue Queue<LuaEntity>
--- @field systems table<FluidSystemID, Color>

--- @param entity LuaEntity
--- @param player_index PlayerIndex
--- @param in_overlay boolean
--- @param update_neighbours boolean
--- @return boolean accepted
local function request(entity, player_index, in_overlay, update_neighbours)
  if not global.iterator then
    return false
  end

  local iterator = global.iterator[player_index]
  if not iterator then
    --- @type Iterator
    iterator = {
      entities = {},
      in_overlay = in_overlay,
      player_index = player_index,
      queue = flib_queue.new(),
      systems = {},
    }
  end

  local fluidbox = entity.fluidbox
  local should_iterate = false
  for i = 1, #fluidbox do
    --- @cast i uint
    local id = fluidbox.get_fluid_system_id(i)
    if not id then
      goto continue
    end

    local system = iterator.systems[id]
    if system and not in_overlay and not update_neighbours then
      goto continue
    end

    if not system then
      -- TODO: Handle when there's no fluid in the system
      local color = { r = 0.3, g = 0.3, b = 0.3 }
      local contents = fluidbox.get_fluid_system_contents(i)
      if contents and next(contents) then
        color = global.fluid_colors[next(contents)]
      end

      iterator.systems[id] = color
    end

    should_iterate = true

    ::continue::
  end

  if should_iterate then
    flib_queue.push_back(iterator.queue, entity)
    global.iterator[player_index] = iterator
  end

  return should_iterate
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

local layers = {
  arrow = "195",
  line = "194",
  underground = "193",
  entity = "192",
}

local pipe_types = {
  ["infinity-pipe"] = true,
  ["pipe-to-ground"] = true,
  ["pipe"] = true,
}

local encoded_directions = {
  [defines.direction.north] = 1,
  [defines.direction.east] = 2,
  [defines.direction.south] = 4,
  [defines.direction.west] = 8,
}

--- @type Color
local default_color = { r = 0.32, g = 0.32, b = 0.32, a = 0.4 }

--- @param iterator Iterator
--- @param entity_data EntityData
--- @param ignore_unit_number UnitNumber?
local function draw_entity(iterator, entity_data, ignore_unit_number)
  local is_complex_type = not pipe_types[entity_data.entity.type]
  local fluidbox = entity_data.fluidbox
  if is_complex_type then
    local box = flib_bounding_box.resize(entity_data.entity.selection_box, -0.1)
    entity_data.shape = rendering.draw_sprite({
      sprite = "pv-entity-box",
      tint = default_color,
      x_scale = flib_bounding_box.width(box),
      y_scale = flib_bounding_box.height(box),
      render_layer = layers.entity,
      target = entity_data.entity.position,
      surface = entity_data.entity.surface_index,
      players = { iterator.player_index },
    })
  else
    local box = flib_bounding_box.ceil(entity_data.entity.selection_box)
    entity_data.shape = rendering.draw_sprite({
      sprite = "pv-pipe-connections-0",
      tint = default_color,
      x_scale = flib_bounding_box.width(box),
      y_scale = flib_bounding_box.height(box),
      render_layer = layers.line,
      target = entity_data.entity.position,
      surface = entity_data.entity.surface_index,
      players = { iterator.player_index },
    })
  end
  --- @type Color?
  local shape_color
  local highest_id = 0
  local encoded_connections = 0
  for fluidbox_index = 1, #fluidbox do
    --- @cast fluidbox_index uint
    local id = fluidbox.get_fluid_system_id(fluidbox_index)
    if not id then
      goto continue
    end
    local color = iterator.systems[id]
    if not color then
      goto continue
    end
    if id > highest_id then
      shape_color = color
      highest_id = id
    end
    local shapes = entity_data.connections[id]
    if not shapes then
      shapes = {}
      entity_data.connections[id] = shapes
    end
    local pipe_connections = fluidbox.get_pipe_connections(fluidbox_index)
    for connection_index = 1, #pipe_connections do
      --- @cast connection_index uint
      local connection = pipe_connections[connection_index]
      local direction = get_cardinal_direction(connection.position, connection.target_position)

      if not connection.target or connection.target.owner.unit_number == ignore_unit_number then
        goto inner_continue
      end

      if is_complex_type then
        if connection.flow_direction == "input" then
          direction = (direction + 4) % 8 -- Opposite
        end
        local sprite = "pv-fluid-arrow-" .. connection.flow_direction
        if connection.flow_direction ~= "input-output" and not pipe_types[connection.target.owner.type] then
          sprite = "pv-fluid-arrow"
        end
        shapes[#shapes + 1] = rendering.draw_sprite({
          sprite = sprite,
          tint = color,
          render_layer = layers.arrow,
          orientation = direction / 8,
          target = {
            x = connection.position.x + (connection.target_position.x - connection.position.x) / 2,
            y = connection.position.y + (connection.target_position.y - connection.position.y) / 2,
          },
          surface = entity_data.entity.surface_index,
          players = { iterator.player_index },
        })
      else
        encoded_connections = bit32.bor(encoded_connections, encoded_directions[direction])
      end

      if connection.connection_type == "underground" then
        if iterator.entities[connection.target.owner.unit_number] then
          goto inner_continue
        end
        local target_connection_data =
          connection.target.get_pipe_connections(connection.target_fluidbox_index)[connection.target_pipe_connection_index]
        local target_position = target_connection_data.position
        local distance = flib_position.distance(connection.position, target_connection_data.position)
        if distance > 1 then
          for i = 1, distance - 1 do
            local target = flib_position.lerp(connection.position, target_position, i / distance)
            shapes[#shapes + 1] = rendering.draw_sprite({
              sprite = "pv-underground-connection",
              tint = color,
              render_layer = layers.underground,
              orientation = direction / 8,
              target = target,
              surface = entity_data.entity.surface_index,
              players = { iterator.player_index },
            })
          end
          break
        end
      end

      ::inner_continue::
    end

    ::continue::
  end
  if entity_data.shape and shape_color then
    rendering.set_color(entity_data.shape, shape_color)
  end
  if encoded_connections > 0 then
    rendering.set_sprite(entity_data.shape, "pv-pipe-connections-" .. encoded_connections)
  end
end

--- @param entity_data EntityData
--- @param fluid_system_id FluidSystemID?
local function clear_entity(entity_data, fluid_system_id)
  if fluid_system_id then
    for _, shape in pairs(entity_data.connections[fluid_system_id]) do
      rendering.destroy(shape)
    end
    entity_data.connections[fluid_system_id] = nil
  else
    for id, shapes in pairs(entity_data.connections) do
      for _, shape in pairs(shapes) do
        rendering.destroy(shape)
      end
      entity_data.connections[id] = nil
    end
  end
  if entity_data.shape then
    rendering.destroy(entity_data.shape)
  end
end

--- @param iterator Iterator
--- @param entity_data EntityData
--- @param fluid_system_id FluidSystemID?
local function delete_entity(iterator, entity_data, fluid_system_id)
  clear_entity(entity_data, fluid_system_id)
  if next(entity_data.connections) then
    draw_entity(iterator, entity_data)
  else
    iterator.entities[entity_data.unit_number] = nil
  end
end

--- @param iterator Iterator
--- @param entity_data EntityData
--- @param ignore_unit_number UnitNumber?
local function update_entity(iterator, entity_data, ignore_unit_number)
  clear_entity(entity_data)
  draw_entity(iterator, entity_data, ignore_unit_number)
end

--- @param iterator Iterator
--- @param entity LuaEntity
--- @param force_iterate_neighbours boolean?
local function iterate_entity(iterator, entity, force_iterate_neighbours)
  if not entity.valid then
    return
  end
  local entity_data = iterator.entities[
    entity.unit_number --[[@as uint]]
  ]
  if entity_data then
    delete_entity(iterator, entity_data)
  end
  --- @type EntityData
  entity_data = {
    connections = {},
    entity = entity,
    fluidbox = entity.fluidbox,
    unit_number = entity.unit_number,
  }
  iterator.entities[entity.unit_number] = entity_data

  draw_entity(iterator, entity_data)

  if iterator.in_overlay and not force_iterate_neighbours then
    return
  end

  local fluidbox = entity.fluidbox
  for fluidbox_index, neighbours in pairs(entity.neighbours) do
    --- @cast fluidbox_index uint
    local id = fluidbox.get_fluid_system_id(fluidbox_index)
    if not id then
      goto continue
    end
    local system = iterator.systems[id]
    if not system then
      goto continue
    end
    for _, neighbour in pairs(neighbours) do
      local neighbour_unit_number = neighbour.unit_number
      if neighbour_unit_number then
        local neighbour_data = iterator.entities[neighbour_unit_number]
        if force_iterate_neighbours or not neighbour_data or not neighbour_data.connections[id] then
          flib_queue.push_back(iterator.queue, neighbour)
        end
      end
    end

    ::continue::
  end
end

--- @param iterator Iterator
--- @param entities_per_tick integer
local function iterate(iterator, entities_per_tick)
  for _ = 1, entities_per_tick do
    local entity = flib_queue.pop_front(iterator.queue)
    if not entity then
      break
    end
    iterate_entity(iterator, entity)
  end
end

--- @param iterator Iterator
--- @param system_id FluidSystemID
local function clear(iterator, system_id)
  iterator.systems[system_id] = nil
  for _, entity_data in pairs(iterator.entities) do
    if entity_data.connections[system_id] then
      delete_entity(iterator, entity_data, system_id)
    end
  end
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
    if entity_data.shape then
      rendering.destroy(entity_data.shape)
    end
    for _, shapes in pairs(entity_data.connections) do
      for _, shape in pairs(shapes) do
        rendering.destroy(shape)
      end
    end
  end
  global.iterator[player_index] = nil
end

--- @param entity LuaEntity
--- @param player_index PlayerIndex
local function request_or_clear(entity, player_index)
  if not global.iterator then
    return
  end
  local iterator = global.iterator[player_index]
  if not iterator then
    request(entity, player_index, false, false)
    return
  end
  if iterator.in_overlay then
    return
  end
  if request(entity, player_index, false, false) then
    return
  end
  local fluidbox = entity.fluidbox
  for fluidbox_index = 1, #fluidbox do
    --- @cast fluidbox_index uint
    local id = fluidbox.get_fluid_system_id(fluidbox_index)
    if id and iterator.systems[id] then
      clear(iterator, id)
    end
  end
end

local function on_tick()
  if not global.iterator then
    return
  end
  local entities_per_tick = math.ceil(30 / table_size(global.iterator))
  for _, iterator in pairs(global.iterator) do
    iterate(iterator, entities_per_tick)
  end
end

--- @param e EventData.CustomInputEvent
local function on_toggle_hover(e)
  local iterator = global.iterator[e.player_index]
  if iterator and iterator.in_overlay then
    return
  end
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
end

iterator.events = {
  [defines.events.on_tick] = on_tick,
  ["pv-visualize-selected"] = on_toggle_hover,
}

iterator.clear_all = clear_all
iterator.clear_entity = clear_entity
iterator.delete_entity = delete_entity
iterator.draw_entity = draw_entity
iterator.iterate_entity = iterate_entity
iterator.request = request
iterator.update_entity = update_entity

return iterator
