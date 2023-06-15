local flib_bounding_box = require("__flib__/bounding-box")
local flib_position = require("__flib__/position")

-- In the source code, 200 is defined as the maximum viewable distance, but in reality it's around 220
-- Map editor is 3x that, but we will ignore that for now
-- Add five for a comfortable margin
local max_overlay_size = 220 + 5

--- @alias RenderObjectID uint64
--- @alias UnitNumber uint

--- @class Overlay
--- @field background RenderObjectID
--- @field dimensions DisplayResolution
--- @field entity_objects table<UnitNumber, RenderObjectID[]>
--- @field last_position MapPosition
--- @field player LuaPlayer

--- @param self Overlay
--- @param position MapPosition
local function get_areas(self, position)
  local dimensions = self.dimensions
  local last_position = self.last_position
  if not last_position then
    return { flib_bounding_box.from_dimensions(position, dimensions.width, dimensions.height) }
  end
  local position_x = position.x
  local position_y = position.y
  local radius_x = dimensions.width / 2
  local radius_y = dimensions.height / 2

  local delta = flib_position.sub(position, last_position)
  --- @type BoundingBox[]
  local areas = {}

  if delta.x < 0 then
    areas[#areas + 1] = {
      left_top = {
        x = position_x - radius_x,
        y = position_y - radius_y,
      },
      right_bottom = {
        x = last_position.x - radius_x,
        y = position_y + radius_y,
      },
    }
  elseif delta.x > 0 then
    areas[#areas + 1] = {
      left_top = {
        x = last_position.x + radius_x,
        y = position_y - radius_y,
      },
      right_bottom = {
        x = position_x + radius_x,
        y = position_y + radius_y,
      },
    }
  end

  if delta.y < 0 then
    areas[#areas + 1] = {
      left_top = {
        x = position_x - radius_x,
        y = position_y - radius_y,
      },
      right_bottom = {
        x = position_x + radius_x,
        y = last_position.y - radius_y,
      },
    }
  elseif delta.y > 0 then
    areas[#areas + 1] = {
      left_top = {
        x = position_x - radius_x,
        y = last_position.y + radius_y,
      },
      right_bottom = {
        x = position_x + radius_x,
        y = position_y + radius_y,
      },
    }
  end

  return areas
end

--- @param fluidbox LuaFluidBox
--- @param index uint
--- @param colors table<uint, Color>
--- @return Color
local function get_color(fluidbox, index, colors)
  local id = fluidbox.get_fluid_system_id(index)
  local color = colors[id]
  if color then
    return color
  end

  local fluid = fluidbox[index]
  local filter = fluidbox.get_filter(index)
  --- @type string?
  local fluid_name
  if fluid then
    fluid_name = fluid.name
  elseif filter then
    fluid_name = filter.name
  else
    fluid_name = fluidbox.get_locked_fluid(index)
  end

  if fluid_name then
    local color = global.fluid_colors[fluid_name]
    colors[id] = color
    return color
  end

  return { r = 0.3, g = 0.3, b = 0.3 }
end

--- @param player LuaPlayer
--- @return DisplayResolution
local function get_dimensions(player)
  local resolution = player.display_resolution
  local divisor = math.max(resolution.width, resolution.height) / max_overlay_size
  resolution.width = resolution.width / divisor
  resolution.height = resolution.height / divisor
  return resolution
end

--- @param self Overlay
--- @param entity LuaEntity
--- @param colors table<uint, Color>
local function visualize_entity(self, entity, colors)
  if self.entity_objects[entity.unit_number] then
    return
  end
  local entity_box = entity.prototype.collision_box
  if entity.direction - 2 % 4 == 0 then
    entity_box = flib_bounding_box.rotate(entity_box)
  end
  if flib_bounding_box.width(entity_box) > 1 or flib_bounding_box.height(entity_box) > 1 then
    entity_box = flib_bounding_box.recenter_on(entity_box, entity.position)
    rendering.draw_rectangle({
      color = { r = 0.8, g = 0.8 },
      filled = false,
      width = 2,
      left_top = entity_box.left_top,
      right_bottom = entity_box.right_bottom,
      surface = entity.surface,
      players = { self.player },
    })
    return
  end
  --- @type RenderObjectID[]
  local objects = {}
  local fluidbox = entity.fluidbox
  for i = 1, #fluidbox do
    --- @cast i uint
    local color = get_color(fluidbox, i, colors)
    objects[#objects + 1] = rendering.draw_circle({
      color = color,
      filled = true,
      radius = 0.15,
      surface = entity.surface,
      target = entity,
    })
    local pipe_connections = fluidbox.get_prototype(i).pipe_connections
    for _, connection in pairs(fluidbox.get_connections(i)) do
      local owner = connection.owner
      local connection_box = flib_bounding_box.recenter_on(owner.prototype.collision_box, owner.position)
      if connection.owner.direction - 2 % 4 == 0 then
        connection_box = flib_bounding_box.rotate(connection_box)
      end
      for _, pe in pairs(pipe_connections) do
        local vector = pe.positions[entity.direction / 2 + 1]
        if flib_bounding_box.contains_position(connection_box, flib_position.add(entity.position, vector)) then
          objects[#objects + 1] = rendering.draw_line({
            color = color,
            width = 2,
            surface = entity.surface,
            from = entity,
            to = entity,
            to_offset = vector,
          })
          objects[#objects + 1] = rendering.draw_circle({
            color = color,
            filled = true,
            radius = 0.15,
            surface = entity.surface,
            target = entity,
            target_offset = vector,
          })
        end
      end
    end
  end
  self.entity_objects[entity.unit_number] = objects
end

--- @param self Overlay
--- @param area BoundingBox
local function visualize_area(self, area)
  local entities = self.player.surface.find_entities_filtered({
    area = area,
    force = self.player.force,
    type = {
      "assembling-machine",
      "boiler",
      "furnace",
      "generator",
      "infinity-pipe",
      "pipe",
      "pipe-to-ground",
      "pump",
      "pump-to-ground",
      "rocket-silo",
      "storage-tank",
    },
  })
  local colors = {}
  for _, entity in pairs(entities) do
    visualize_entity(self, entity, colors)
  end
end

--- @param self Overlay
local function update_overlay(self)
  local position = flib_position.floor(self.player.position)
  if self.last_position and flib_position.eq(position, self.last_position) then
    return
  end
  local areas = get_areas(self, position)
  self.last_position = position
  local box = flib_bounding_box.from_dimensions(position, self.dimensions.width, self.dimensions.height)
  rendering.set_left_top(self.background, box.left_top)
  rendering.set_right_bottom(self.background, box.right_bottom)

  for _, area in pairs(areas) do
    visualize_area(self, area)
  end
end

--- @param player LuaPlayer
local function create_overlay(player)
  local opacity = player.mod_settings["pv-overlay-opacity"].value --[[@as float]]
  local background = rendering.draw_rectangle({
    color = { a = opacity },
    filled = true,
    left_top = { 0, 0 },
    right_bottom = { 0, 0 },
    surface = player.surface,
    players = { player },
  })
  --- @type Overlay
  local self = {
    background = background,
    dimensions = get_dimensions(player),
    entity_objects = {},
    player = player,
  }
  global.overlay[player.index] = self
  update_overlay(self)
end

--- @param self Overlay
local function destroy_overlay(self)
  rendering.destroy(self.background)
  for _, objects in pairs(self.entity_objects) do
    for _, id in pairs(objects) do
      rendering.destroy(id)
    end
  end
  global.overlay[self.player.index] = nil
end

--- @param e EventData.CustomInputEvent|EventData.on_lua_shortcut
local function on_toggle_overlay(e)
  if (e.input_name or e.prototype_name) ~= "pv-toggle-overlay" then
    return
  end
  local player = game.get_player(e.player_index)
  if not player then
    return
  end
  local self = global.overlay[e.player_index]
  if self then
    destroy_overlay(self)
  else
    create_overlay(player)
  end
  player.set_shortcut_toggled("pv-toggle-overlay", global.overlay[e.player_index] ~= nil)
end

--- @param e EventData.on_player_changed_position
local function on_player_changed_position(e)
  local self = global.overlay[e.player_index]
  if self then
    update_overlay(self)
  end
end

--- @param e EventData.on_player_display_resolution_changed
local function on_player_display_resolution_changed(e)
  local self = global.overlay[e.player_index]
  if not self then
    return
  end
  self.dimensions = get_dimensions(self.player)
  self.last_position = nil
  update_overlay(self)
end

local overlay = {}

function overlay.on_init()
  --- @type table<uint, Overlay>
  global.overlay = {}
end

overlay.events = {
  [defines.events.on_lua_shortcut] = on_toggle_overlay,
  [defines.events.on_player_changed_position] = on_player_changed_position,
  [defines.events.on_player_display_resolution_changed] = on_player_display_resolution_changed,
  ["pv-toggle-overlay"] = on_toggle_overlay,
}

return overlay
