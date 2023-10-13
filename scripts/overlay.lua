local flib_bounding_box = require("__flib__/bounding-box")
local flib_math = require("__flib__/math")
local flib_position = require("__flib__/position")

local iterator = require("__PipeVisualizer__/scripts/iterator")

-- In the source code, 200 is defined as the maximum viewable distance, but in reality it's around 220
-- Map editor is 3x that, but we will ignore that for now
-- Add five for a comfortable margin
local max_overlay_size = 220 + 5

--- @alias UnitNumber uint

--- @class Overlay
--- @field background RenderObjectID
--- @field dimensions DisplayResolution
--- @field last_position MapPosition?
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
      left_top = { x = position_x - radius_x, y = position_y - radius_y },
      right_bottom = { x = last_position.x - radius_x, y = position_y + radius_y },
    }
  elseif delta.x > 0 then
    areas[#areas + 1] = {
      left_top = { x = last_position.x + radius_x, y = position_y - radius_y },
      right_bottom = { x = position_x + radius_x, y = position_y + radius_y },
    }
  end

  if delta.y < 0 then
    areas[#areas + 1] = {
      left_top = { x = position_x - radius_x - math.min(delta.x, 0), y = position_y - radius_y },
      right_bottom = { x = position_x + radius_x - math.max(delta.x, 0), y = last_position.y - radius_y },
    }
  elseif delta.y > 0 then
    areas[#areas + 1] = {
      left_top = { x = position_x - radius_x - math.min(delta.x, 0), y = last_position.y + radius_y },
      right_bottom = { x = position_x + radius_x - math.max(delta.x, 0), y = position_y + radius_y },
    }
  end

  return areas
end

--- @param player LuaPlayer
--- @return DisplayResolution
local function get_dimensions(player)
  -- return { width = 32, height = 32 }
  -- return { width = 96, height = 96 }
  local resolution = player.display_resolution
  local divisor = math.max(resolution.width, resolution.height) / max_overlay_size
  resolution.width = flib_math.ceiled(resolution.width / divisor, 64) + 32
  resolution.height = flib_math.ceiled(resolution.height / divisor, 64) + 32
  return resolution
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
      "fluid-turret",
      "furnace",
      "generator",
      "infinity-pipe",
      "inserter",
      "lab",
      "loader",
      "loader-1x1",
      "mining-drill",
      "offshore-pump",
      "pipe",
      "pipe-to-ground",
      "pump",
      "reactor",
      "rocket-silo",
      "storage-tank",
    },
  })
  for _, entity in pairs(entities) do
    iterator.request(entity, self.player.index, true)
  end
end

--- @param self Overlay
local function update_overlay(self)
  local pos = self.player.position
  local position = {
    x = flib_math.floored(pos.x, 32) + 16,
    y = flib_math.floored(pos.y, 32) + 16,
  }
  if self.last_position and flib_position.eq(position, self.last_position) then
    return
  end
  rendering.set_target(self.background, position)
  rendering.set_x_scale(self.background, self.dimensions.width)
  rendering.set_y_scale(self.background, self.dimensions.height)

  local areas = get_areas(self, position)

  self.last_position = position

  for _, area in pairs(areas) do
    rendering.draw_rectangle({
      color = { r = 0.1, a = 0.1 },
      filled = true,
      left_top = area.left_top,
      right_bottom = area.right_bottom,
      surface = self.player.surface_index,
      time_to_live = 60,
    })
    visualize_area(self, area)
  end
end

--- @param player LuaPlayer
--- @return Overlay
local function create_overlay(player)
  local background = rendering.draw_sprite({
    sprite = "pv-entity-box",
    tint = {},
    render_layer = "191",
    target = player.position,
    surface = player.surface,
    players = { player },
  })
  --- @type Overlay
  local self = {
    background = background,
    dimensions = get_dimensions(player),
    player = player,
  }
  global.overlay[player.index] = self
  iterator.clear_all(player.index)
  update_overlay(self)
  return self
end

--- @param self Overlay
local function destroy_overlay(self)
  rendering.destroy(self.background)
  iterator.clear_all(self.player.index)
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
  local entity = player.selected
  if entity and entity.prototype.belt_speed and script.active_mods["belt-visualizer"] then
    return
  end
  local cursor_stack = player.cursor_stack
  if cursor_stack and cursor_stack.valid_for_read and (cursor_stack.is_blueprint_book or cursor_stack.is_blueprint) then
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
  if not global.overlay then
    return
  end
  local self = global.overlay[e.player_index]
  if not self then
    return
  end
  self.dimensions = get_dimensions(self.player)
  self.last_position = nil
  update_overlay(self)
end

--- @param e EventData.CustomInputEvent
local function on_color_by_system_pressed(e)
  local self = global.overlay[e.player_index]
  if not self then
    return
  end
  destroy_overlay(self)
  create_overlay(game.get_player(e.player_index) --[[@as LuaPlayer]])
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
  ["pv-color-by-fluid-system"] = on_color_by_system_pressed,
}

return overlay
