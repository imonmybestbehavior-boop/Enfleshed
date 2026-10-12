--!strict
-- Fixed identities keep slot replacement from resetting cooldowns.
local Slots = { Count = 9 }
function Slots.id(slot)
	if type(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 or slot < 1 or slot > Slots.Count then
		return nil
	end
	return "MagicLabSlot" .. slot
end
return Slots
