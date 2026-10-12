--!strict
-- This module is mapped ONLY by KitBlock/review.project.json.
-- The normal city opening, appearance and progression services remain untouched.
local Equipment = require(script.Parent.EquipmentService)
local Opening = {}
local feedback: RemoteEvent

function Opening.start(_folder: Folder, remote: RemoteEvent)
	feedback = remote
end

function Opening.bind(player: Player)
	player:SetAttribute("OpeningComplete", true)
end

function Opening.prepareCharacter(player: Player, _character: Model)
	Equipment.chooseStarter(player, "Melee", feedback)
end

function Opening.remove(_player: Player) end

return Opening
