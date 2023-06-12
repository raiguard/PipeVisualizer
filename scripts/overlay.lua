local flib_bounding_box = require("__flib__/bounding-box")
local flib_position = require("__flib__/position")

-- In the source code, 200 is defined as the maximum viewable distance, but in reality it's around 220
-- Map editor is 3x that, but we will ignore that for now
-- Add five for a comfortable margin
local overlay_size = 220 + 5

--- @alias RenderObjectID uint64

--- @class Overlay
--- @field background RenderObjectID
--- @field box BoundingBox
--- @field last_position MapPosition
--- @field player LuaPlayer

--- @param self Overlay
local function update_overlay(self)
  local position = flib_position.floor(self.player.position)
  if flib_position.eq(position, self.last_position) then
    return
  end
  self.last_position = position
  self.box = flib_bounding_box.from_dimensions(position, overlay_size, overlay_size)
  rendering.set_left_top(self.background, self.box.left_top)
  rendering.set_right_bottom(self.background, self.box.right_bottom)
end

--- @param player LuaPlayer
local function create_overlay(player)
  -- TODO: Minimize area based on current display_resolution
  local position = flib_position.floor(player.position)
  local box = flib_bounding_box.from_dimensions(position, overlay_size, overlay_size)
  local opacity = player.mod_settings["pv-overlay-opacity"].value --[[@as float]]
  local background = rendering.draw_rectangle({
    color = { a = opacity },
    filled = true,
    left_top = box.left_top,
    right_bottom = box.right_bottom,
    surface = player.surface,
    players = { player },
  })
  global.overlay[player.index] = {
    background = background,
    box = box,
    last_position = position,
    player = player,
  }
end

--- @param self Overlay
local function destroy_overlay(self)
  rendering.destroy(self.background)
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

local overlay = {}

function overlay.on_init()
  global.overlay = {}
end

overlay.events = {
  [defines.events.on_lua_shortcut] = on_toggle_overlay,
  [defines.events.on_player_changed_position] = on_player_changed_position,
  ["pv-toggle-overlay"] = on_toggle_overlay,
}

return overlay
