local table = require("__flib__.table")

local constants = {}

-- In the source code, 200 is defined as the maximum viewable distance, but in reality it's around 220
-- Map editor is 3x that, but we will ignore that for now
-- Add five for a comfortable margin
constants.max_viewable_radius = 110 + 5

constants.search_types = {
  "infinity-pipe",
  "offshore-pump",
  "pipe",
  "pipe-to-ground",
  "pump",
  "storage-tank",
}

constants.search_types_lookup = table.invert(constants.search_types)

return constants
