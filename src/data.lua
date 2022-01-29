data:extend({
  {
    type = "custom-input",
    name = "pv-toggle-hover",
    key_sequence = "CONTROL + SHIFT + P",
    action = "lua",
  },
  {
    type = "custom-input",
    name = "pv-toggle-overlay",
    key_sequence = "CONTROL + P",
    action = "lua",
  },
  {
    type = "shortcut",
    name = "pv-toggle-hover",
    icon = util.empty_sprite(),
    associated_control_input = "pv-toggle-hover",
    action = "lua",
    toggleable = true,
  },
  {
    type = "shortcut",
    name = "pv-toggle-overlay",
    icon = util.empty_sprite(),
    associated_control_input = "pv-toggle-overlay",
    action = "lua",
    toggleable = true,
  },
})
