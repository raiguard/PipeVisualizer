local constants = {}

constants.default_color = { r = 0.3, g = 0.3, b = 0.3 }

-- In the source code, 200 is defined as the maximum viewable distance, but in reality it's around 220
-- Map editor is 3x that, but we will ignore that for now
-- Add five for a comfortable margin
constants.max_viewable_radius = 110 + 5

constants.entity_types = {
  "assembling-machine",
  "boiler",
  "fluid-turret",
  "furnace",
  "generator",
  "infinity-pipe",
  "inserter",
  "mining-drill",
  "offshore-pump",
  "pipe",
  "pipe-to-ground",
  "pump",
  "rocket-silo",
  "storage-tank",
}

constants.type_to_shape = {
  ["assembling-machine"] = "square",
  ["boiler"] = "square",
  ["fluid-turret"] = "square",
  ["furnace"] = "square",
  ["generator"] = "square",
  ["infinity-pipe"] = "circle",
  ["inserter"] = "square",
  ["mining-drill"] = "square",
  ["offshore-pump"] = "square",
  ["pipe"] = "circle",
  ["pipe-to-ground"] = "circle",
  ["pump"] = "circle",
  ["rocket-silo"] = "circle",
  ["storage-tank"] = "diamond",
}

return constants
