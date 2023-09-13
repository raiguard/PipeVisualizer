local util = {}

--- Iterates the fluid system IDs of the given fluidbox.
--- @param fluidbox LuaFluidBox
--- @return fun(): uint?, FluidSystemID?
function util.iterate_fluid_systems(fluidbox)
  --- @type uint
  local fluidbox_index = 0
  --- @type uint
  local limit = #fluidbox
  local get_id = fluidbox.get_fluid_system_id
  return function()
    --- @type FluidSystemID
    local id
    while not id do
      if fluidbox_index == limit then
        return
      end
      fluidbox_index = fluidbox_index + 1
      id = get_id(fluidbox_index)
    end
    return fluidbox_index, id
  end
end

return util
