local flib_bounding_box = require("__flib__/bounding-box")

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

  local unit_number = entity.unit_number --[[@as UnitNumber]]
  return iterator.entities[unit_number] and true or false
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

  for _, it in pairs(global.iterator) do
    for _, fluid_system_id in util.iterate_fluid_systems(entity.fluidbox) do
      if it.in_overlay or it.systems[fluid_system_id] then
        it.scheduled[fluid_system_id] = { entity = entity, tick = game.tick + 60 }
      end
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
    for _, fluid_system_id in util.iterate_fluid_systems(entity.fluidbox) do
      if it.systems[fluid_system_id] then
        -- TODO: This will just nuke all of these systems instead of update them
        it.scheduled[fluid_system_id] = { tick = game.tick + 60 }
      end
    end
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
    if data then
      for fluid_system_id in data.connections do
        if it.systems[fluid_system_id] then
          it.scheduled[fluid_system_id] = { tick = game.tick + 60 }
        end
      end
    end
    for _, fluid_system_id in util.iterate_fluid_systems(entity.fluidbox) do
      if it.systems[fluid_system_id] then
        it.scheduled[fluid_system_id] = { entity = entity, tick = game.tick + 60 }
      end
    end
  end
end

local function initialize()
  --- @type uint
  global.update_systems_on = 0
end

local entity_detection = {}

entity_detection.on_init = initialize
entity_detection.on_configuration_changed = initialize

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

-- Check the systems that its data says it's connected to
-- Mark those systems for clearing in 60 ticks
-- If entity was destroyed, stop here
-- Check the systems it is NOW connected to
-- Mark those systems for drawing in 60 ticks
