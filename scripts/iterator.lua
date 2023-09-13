local flib_queue = require("__flib__/queue")

local entity_data = require("__PipeVisualizer__/scripts/entity-data")
local renderer = require("__PipeVisualizer__/scripts/renderer")
local util = require("__PipeVisualizer__/scripts/util")

--- @alias FlowDirection "input"|"output"|"input-output"
--- @alias FluidSystemID uint
--- @alias PlayerIndex uint

--- @class Iterator
--- @field entities table<UnitNumber, EntityData>
--- @field in_overlay boolean
--- @field player_index PlayerIndex
--- @field queue Queue<{entity: LuaEntity, update_neighbours: boolean}>
--- @field systems table<FluidSystemID, Color>

--- @param entity LuaEntity
--- @param player_index PlayerIndex
--- @param in_overlay boolean
--- @return boolean accepted
local function request(entity, player_index, in_overlay)
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
  for fluidbox_index, fluid_system_id in util.iterate_fluid_systems(fluidbox) do
    local system = iterator.systems[fluid_system_id]
    if system and not in_overlay then
      goto continue
    end

    if not system then
      -- TODO: Handle when there's no fluid in the system
      local color = { r = 0.3, g = 0.3, b = 0.3 }
      local contents = fluidbox.get_fluid_system_contents(fluidbox_index)
      if contents and next(contents) then
        color = global.fluid_colors[next(contents)]
      end

      iterator.systems[fluid_system_id] = color
    end

    should_iterate = true

    ::continue::
  end

  if should_iterate then
    flib_queue.push_back(iterator.queue, { entity = entity })
    global.iterator[player_index] = iterator
  end

  return should_iterate
end

--- @param iterator Iterator
--- @param entity LuaEntity
--- @param update_neighbours boolean?
local function request2(iterator, entity, update_neighbours)
  update_neighbours = update_neighbours or false
  flib_queue.push_back(iterator.queue, { entity = entity, update_neighbours = update_neighbours })
end

--- @param iterator Iterator
--- @param entities_per_tick integer
local function iterate(iterator, entities_per_tick)
  for _ = 1, entities_per_tick do
    local to_iterate = flib_queue.pop_front(iterator.queue)
    if not to_iterate then
      break
    end
    local entity, update_neighbours = to_iterate.entity, to_iterate.update_neighbours
    if not entity.valid then
      goto continue
    end

    -- If the entity data already existed, this entity was requested to be redrawn
    local data = entity_data.create(iterator, entity)
    if not data then
      return
    end

    renderer.draw(iterator, data)

    if iterator.in_overlay and not update_neighbours then
      goto continue
    end

    -- Propagate to undrawn neighbours
    for fluid_system_id, connections in pairs(data.connections) do
      if iterator.systems[fluid_system_id] then
        for _, connection in pairs(connections) do
          local owner = connection.target_owner
          if owner then
            local data = entity_data.get(iterator, owner)
            if
              update_neighbours
              or not data
              or (data.connections[fluid_system_id] and not data.connection_objects[fluid_system_id])
            then
              flib_queue.push_back(iterator.queue, { entity = owner })
            end
          end
        end
      end
    end

    ::continue::
  end
end

--- @param iterator Iterator
--- @param fluid_system_id FluidSystemID
local function clear_system(iterator, fluid_system_id)
  iterator.systems[fluid_system_id] = nil
  for _, data in pairs(iterator.entities) do
    if data.connections[fluid_system_id] then
      entity_data.remove_system(iterator, data, fluid_system_id)
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
  local it = global.iterator[player_index]
  if not it then
    return
  end
  for _, entity_data in pairs(it.entities) do
    renderer.clear(entity_data)
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
  -- TODO: Rewrite this
  local fluidbox = entity.fluidbox
  for fluidbox_index = 1, #fluidbox do
    --- @cast fluidbox_index uint
    local id = fluidbox.get_fluid_system_id(fluidbox_index)
    if id and iterator.systems[id] then
      clear_system(iterator, id)
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

--- @class iterator
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
iterator.request2 = request2

return iterator
