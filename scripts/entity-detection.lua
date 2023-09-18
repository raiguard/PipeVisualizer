local flib_bounding_box = require("__flib__/bounding-box")

local entity_data = require("__PipeVisualizer__/scripts/entity-data")
local iterator = require("__PipeVisualizer__/scripts/iterator")
local util = require("__PipeVisualizer__/scripts/util")

--- @alias BuiltEvent EventData.on_built_entity|EventData.on_robot_built_entity|EventData.on_entity_cloned|EventData.script_raised_built|EventData.script_raised_revive
--- @alias DestroyedEvent EventData.on_player_mined_entity|EventData.on_robot_mined_entity|EventData.on_entity_died|EventData.script_raised_destroy

--- @param iterator Iterator
--- @param entity LuaEntity
--- @return boolean
local function is_relevant(iterator, entity)
  if iterator.in_overlay then
    local overlay = global.overlay[iterator.player_index]
    if not overlay or not overlay.last_position then
      return false
    end
    local box =
      flib_bounding_box.from_dimensions(overlay.last_position, overlay.dimensions.width, overlay.dimensions.height)
    return flib_bounding_box.contains_position(box, entity.position)
  end

  local fluidbox = entity.fluidbox
  for _, fluid_system_id in util.iterate_fluid_systems(fluidbox) do
    if iterator.systems[fluid_system_id] then
      return true
    end
  end
  return false
end

--- @param it Iterator
--- @param data EntityData
local function update_neighbours(it, data)
  for _, connections in pairs(data.connections) do
    for _, connection in pairs(connections) do
      if connection.target_owner then
        iterator.push(it, connection.target_owner)
      end
    end
  end
end

--- @param e BuiltEvent
local function on_entity_built(e)
  if not global.iterator then
    return
  end

  local entity = e.entity or e.created_entity or e.destination
  if not entity.valid then
    return
  end

  local unit_number = entity.unit_number
  if not unit_number then
    return
  end

  for _, it in pairs(global.iterator) do
    if is_relevant(it, entity) then
      iterator.push(it, entity, true)
    end
  end
end

--- @param e DestroyedEvent
local function on_entity_destroyed(e)
  if not global.iterator then
    return
  end

  local entity = e.entity
  if not entity.valid then
    return
  end

  local unit_number = entity.unit_number
  if not unit_number then
    return
  end

  for _, it in pairs(global.iterator) do
    local data = it.entities[unit_number]
    if not data then
      goto continue
    end

    update_neighbours(it, data)
    entity_data.remove(it, data)

    ::continue::
  end
end

--- @param e EventData.on_player_rotated_entity|EventData.on_entity_settings_pasted
local function on_entity_updated(e)
  if not global.iterator then
    return
  end

  local entity = e.entity or e.destination
  if not entity.valid then
    return
  end

  local unit_number = entity.unit_number
  if not unit_number then
    return
  end

  for _, it in pairs(global.iterator) do
    local data = it.entities[unit_number]
    if not data then
      if is_relevant(it, entity) then
        iterator.push(it, entity)
      end
      return
    end
    update_neighbours(it, data)
    iterator.push(it, entity, true)
  end
end

local entity_detection = {}

entity_detection.events = {
  [defines.events.on_built_entity] = on_entity_built,
  [defines.events.on_entity_cloned] = on_entity_built,
  [defines.events.on_entity_died] = on_entity_destroyed,
  [defines.events.on_entity_settings_pasted] = on_entity_updated,
  [defines.events.on_player_mined_entity] = on_entity_destroyed,
  [defines.events.on_player_rotated_entity] = on_entity_updated,
  [defines.events.on_robot_built_entity] = on_entity_built,
  [defines.events.on_robot_mined_entity] = on_entity_destroyed,
  [defines.events.script_raised_built] = on_entity_built,
  [defines.events.script_raised_destroy] = on_entity_destroyed,
  [defines.events.script_raised_revive] = on_entity_built,
}

return entity_detection
