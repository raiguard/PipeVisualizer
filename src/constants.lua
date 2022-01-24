local table = require("__flib__.table")

local constants = {}

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
