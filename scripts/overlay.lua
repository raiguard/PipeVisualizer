local flib_bounding_box = require("__flib__/bounding-box")
local flib_position = require("__flib__/position")

-- In the source code, 200 is defined as the maximum viewable distance, but in reality it's around 220
-- Map editor is 3x that, but we will ignore that for now
-- Add five for a comfortable margin
local overlay_size = 220 + 5

--- @alias RenderObjectID uint64

--- @class Overlay
--- @field background RenderObjectID
--- @field entity_objects RenderObjectID[]
--- @field last_position MapPosition
--- @field player LuaPlayer

--- @param self Overlay
--- @param entity LuaEntity
--- @param colors table<uint, Color>
local function visualize_entity(self, entity, colors)
  local fluidbox = entity.fluidbox
  for i = 1, #fluidbox do
    --- @cast i uint
    local connection = fluidbox[i]
    if connection then
      local id = fluidbox.get_fluid_system_id(i)
      local color = colors[id]
      if not color then
        color = global.fluid_colors[connection.name]
        colors[id] = color
      end
      self.entity_objects[#self.entity_objects + 1] = rendering.draw_circle({
        color = color,
        filled = true,
        radius = 0.2,
        surface = entity.surface,
        target = entity.position,
      })
    end
  end
end

--- @param self Overlay
local function update_overlay(self)
  local position = flib_position.floor(self.player.position)
  if flib_position.eq(position, self.last_position) then
    return
  end
  self.last_position = position
  local box = flib_bounding_box.from_dimensions(position, overlay_size, overlay_size)
  rendering.set_left_top(self.background, box.left_top)
  rendering.set_right_bottom(self.background, box.right_bottom)

  for _, id in pairs(self.entity_objects) do
    rendering.destroy(id)
  end
  self.entity_objects = {}

  local entities = self.player.surface.find_entities_filtered({
    area = box,
    force = self.player.force,
    type = { "pipe", "pipe-to-ground", "storage-tank", "infinity-pipe" },
  })
  local colors = {}
  for _, entity in pairs(entities) do
    visualize_entity(self, entity, colors)
  end
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
    entity_objects = {},
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
