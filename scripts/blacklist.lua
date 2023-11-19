local blacklist = {}

blacklist.add_remote_interface = function()
	remote.add_interface("PipeVisualizer", {
		--- @param entity_names string[]
		blacklist = function(entity_names)
			if type(entity_names) ~= "table" then
				return
			end
			for _, entity_name in pairs(entity_names) do
				global.blacklist[entity_name] = true
			end
		end,
	})
end

---@param e ConfigurationChangedData?
local function reset(e)
	-- Blacklist has to be rebuilt on every config change
	--- @type table<UnitNumber, boolean>
	global.blacklist = {}
end

blacklist.on_init = reset
blacklist.on_configuration_changed = reset

return blacklist
