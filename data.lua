data:extend({
  {
    type = "custom-input",
    name = "pv-visualize-selected",
    key_sequence = "H",
    action = "lua",
  },
  {
    type = "custom-input",
    name = "pv-toggle-overlay",
    key_sequence = "SHIFT + H",
    action = "lua",
  },
  {
    type = "custom-input",
    name = "pv-toggle-hover",
    key_sequence = "",
    action = "lua",
  },
  {
    type = "shortcut",
    name = "pv-toggle-hover",
    icon = {
      filename = "__PipeVisualizer__/graphics/hover-dark-x32.png",
      size = 32,
      mipmap_count = 2,
      flags = { "gui-icon" },
    },
    disabled_icon = {
      filename = "__PipeVisualizer__/graphics/hover-light-x32.png",
      size = 32,
      mipmap_count = 2,
      flags = { "gui-icon" },
    },
    small_icon = {
      filename = "__PipeVisualizer__/graphics/hover-dark-x24.png",
      size = 24,
      mipmap_count = 2,
      flags = { "gui-icon" },
    },
    disabled_small_icon = {
      filename = "__PipeVisualizer__/graphics/hover-light-x24.png",
      size = 24,
      mipmap_count = 2,
      flags = { "gui-icon" },
    },
    associated_control_input = "pv-toggle-hover",
    action = "lua",
    toggleable = true,
  },
  {
    type = "shortcut",
    name = "pv-toggle-overlay",
    icon = {
      filename = "__PipeVisualizer__/graphics/overlay-dark-x32.png",
      size = 32,
      mipmap_count = 2,
      flags = { "gui-icon" },
    },
    disabled_icon = {
      filename = "__PipeVisualizer__/graphics/overlay-light-x32.png",
      size = 32,
      mipmap_count = 2,
      flags = { "gui-icon" },
    },
    small_icon = {
      filename = "__PipeVisualizer__/graphics/overlay-dark-x24.png",
      size = 24,
      mipmap_count = 2,
      flags = { "gui-icon" },
    },
    disabled_small_icon = {
      filename = "__PipeVisualizer__/graphics/overlay-light-x24.png",
      size = 24,
      mipmap_count = 2,
      flags = { "gui-icon" },
    },
    associated_control_input = "pv-toggle-overlay",
    action = "lua",
    toggleable = true,
  },
})

local storage_tank = table.deepcopy(data.raw["storage-tank"]["storage-tank"])
storage_tank.name = "cursed-storage-tank"
storage_tank.fluid_box.pipe_connections[1].max_underground_distance = 5
storage_tank.fluid_box.pipe_connections[3].max_underground_distance = 5
data:extend({ storage_tank })
