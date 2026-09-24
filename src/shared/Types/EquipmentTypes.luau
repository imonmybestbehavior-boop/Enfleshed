--!strict

export type Slot = "PrimaryWeapon" | "SecondaryWeapon" | "Utility"

export type State = {
	PrimaryWeapon: string?,
	SecondaryWeapon: string?,
	Utility: string?,
	ActiveSlot: Slot,
}

return {}
