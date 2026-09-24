--!strict

export type Attack = {
	Startup: number,
	Active: number,
	Recovery: number,
	Damage: number,
	Size: Vector3,
	Offset: number,
	Reach: number,
}

export type ActionOptions = {
	Sprinting: boolean?,
	Direction: Vector3?,
	SpellId: string?,
	AimDirection: Vector3?,
	WorldPoint: Vector3?,
	EquipmentSlot: string?,
	EquipmentAction: string?,
}

export type ActionRequest = {
	Action: string,
	Sequence: number,
	Character: Model,
	Sprinting: boolean?,
	Direction: Vector3?,
	SpellId: string?,
	AimDirection: Vector3?,
	WorldPoint: Vector3?,
	EquipmentSlot: string?,
	EquipmentAction: string?,
}

export type HitResult = { Target: Model, Damage: number, Health: number }

-- Type information only: the actual state is created and retained exclusively on the server.
export type PlayerState = {
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Sprinting: boolean,
	DashUntil: number,
	DashReadyAt: number,
	DashOrigin: Vector3?,
	DashCheckUntil: number,
	LastPosition: Vector3,
	LastFramePosition: Vector3,
	LastCheck: number,
	DashAllowance: number,
	CorrectionUntil: number,
	SpawnGraceUntil: number,
	Combo: number,
	ReadyAt: number,
	ComboExpires: number,
	Attack: Attack?,
	ActiveAt: number,
	ActiveUntil: number,
	HitTargets: { [Humanoid]: boolean },
}

return {}
