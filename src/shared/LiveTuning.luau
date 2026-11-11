--!strict
-- Mirrors every number/boolean/string in Config as an attribute (e.g. "Grab_SwingAccel") on a holder
-- instance, and writes attribute edits back into Config. Code reads Config each time it needs a value,
-- so edits made in the Properties panel during Play take effect immediately.
--
-- Edit in the Server view: the change replicates and applies on the server and every client.
-- Edit in a Client view: it applies to that client only.
-- When something feels right, copy the value back into Config.luau; attributes don't save.

local LiveTuning = {}

local mirrored: { [Instance]: boolean } = {}

function LiveTuning.mirror(config: { [string]: any }, holder: Instance)
	if mirrored[holder] then
		return
	end
	mirrored[holder] = true

	for sectionName, section in config do
		if typeof(section) == "table" then
			for key, value in section do
				local kind = typeof(value)
				if kind == "number" or kind == "boolean" or kind == "string" then
					local attribute = `{sectionName}_{key}`
					local existing = holder:GetAttribute(attribute)
					if existing ~= nil and typeof(existing) == kind then
						-- Someone already tuned this (e.g. the server, before this client joined): adopt it.
						section[key] = existing
					else
						holder:SetAttribute(attribute, value)
					end
				end
			end
		end
	end

	holder.AttributeChanged:Connect(function(attribute: string)
		local sectionName, key = string.match(attribute, "^(%w+)_(%w+)$")
		if not sectionName or not key then
			return
		end
		local section = config[sectionName]
		if typeof(section) ~= "table" then
			return
		end
		local current = section[key]
		local value = holder:GetAttribute(attribute)
		if current ~= nil and typeof(value) == typeof(current) then
			section[key] = value
		end
	end)
end

return LiveTuning
