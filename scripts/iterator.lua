local flib_queue = require("__flib__/queue")

local renderer = require("__PipeVisualizer__/scripts/renderer")

--- @alias PlayerIndex uint
--- @alias FluidSystemID uint

--- @class Iterator
--- @field entities table<UnitNumber, UnifiedEntityData>
--- @field in_overlay boolean
--- @field objects RenderObjectID[]
--- @field player_index PlayerIndex
--- @field queue Queue<LuaEntity>
--- @field systems table<FluidSystemID, FluidSystemData>

--- @class FluidSystemData
--- @field color Color
--- @field entities table<UnitNumber, EntityData>
--- @field id FluidSystemID

--- @class UnifiedEntityData
--- @field box_border RenderObjectID
--- @field box RenderObjectID
--- @field systems table<FluidSystemID, EntityData>

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

--- @param iterator Iterator
--- @param entity LuaEntity
local function iterate_entity(iterator, entity)
  local fluidbox = entity.fluidbox
  for fluidbox_index = 1, #fluidbox do
    --- @cast fluidbox_index uint
    local id = fluidbox.get_fluid_system_id(fluidbox_index)
    local system = iterator.systems[id]
    if not system then
      goto continue
    end

    local entity_data = system.entities[entity.unit_number]
    if not entity_data then
      --- @type EntityData
      entity_data = {
        connections = {},
        entity = entity,
        position = entity.position,
        surface_index = entity.surface_index,
        type = entity.type,
        unit_number = entity.unit_number,
      }
      system.entities[entity.unit_number] = entity_data
    end

    --- @type table<integer, ConnectionData>
    local existing_connections = {}
    local connections = fluidbox.get_pipe_connections(fluidbox_index)
    for connection_index = 1, #connections do
      if entity_data.connections[connection_index] then
        goto inner_continue
      end
      local connection = connections[connection_index]
      if not connection.target then
        goto inner_continue
      end

      local target_owner = connection.target.owner

      local target_data = system.entities[target_owner.unit_number]
      if target_data then
        local connection_data = target_data.connections[connection.target_pipe_connection_index]
        entity_data.connections[connection_index] = connection_data
        connection_data.target_flow_direction = connection.flow_direction
        existing_connections[connection_index] = connection_data
        goto inner_continue
      end

      renderer.start_connection(iterator, entity_data, connection_index, connection)

      if not iterator.in_overlay then
        flib_queue.push_back(iterator.queue, target_owner)
      end

      ::inner_continue::
    end

    for _, connection_data in pairs(existing_connections) do
      renderer.finish_connection(iterator, system, entity_data, connection_data)
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
      return
    end
    iterate_entity(iterator, entity)
  end
end

--- @param iterator Iterator
--- @param system FluidSystemData
local function clear(iterator, system)
  renderer.clear(system)
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
  for _, system in pairs(iterator.systems) do
    clear(iterator, system)
  end
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
  local entities_per_tick = game.is_multiplayer() and 100 or 20
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
end

iterator.events = {
  [defines.events.on_tick] = on_tick,
  ["pv-visualize-selected"] = on_toggle_hover,
}

iterator.clear_all = clear_all
iterator.request = request

return iterator
