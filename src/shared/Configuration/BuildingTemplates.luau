--!strict

-- Semantic replacement seams for future imported environment modules. The
-- graybox currently resolves these to Parts, never to hard-coded asset IDs.
return table.freeze({
	"BuildingCore",
	"WorkshopExtension",
	"HousingAddition",
	"StairTower",
	"Balcony",
	"BridgeRoom",
	"Catwalk",
	"RepairStructure",
	"UpperHabitation",
	"DestructibleWallSection",
})
