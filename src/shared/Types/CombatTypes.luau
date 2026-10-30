--!strict

export type Attack = {
	Startup: number,
	Active: number,
	Recovery: number,
	Damage: number,
	Size: Vector3,
	Offset: number,
	Reach: number,
	Reaction: string?,
}

export type ActionOptions = {
	Sprinting: boolean?,
	Direction: Vector3?,
	SpellId: string?,
	AimDirection: Vector3?,
	WorldPoint: Vector3?,
	TargetModel: Model?,
	TargetInstance: Instance?,
	CastOrigin: Vector3?,
	EquipmentSlot: string?,
	EquipmentAction: string?,
	SummonMode: string?,
	SummonId: number?,
	AllowsTargetedSpells: boolean?,
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
	TargetModel: Model?,
	TargetInstance: Instance?,
	CastOrigin: Vector3?,
	EquipmentSlot: string?,
	EquipmentAction: string?,
	SummonMode: string?,
	SummonId: number?,
	AllowsTargetedSpells: boolean?,
}

export type HitResult = { Target: Model, Damage: number, Health: number }

-- Type information only: the actual state is created and retained exclusively on the server.
export type PlayerState = {
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Sprinting: boolean,
	MagicWalkSpeedBonus: number,
	MagicSpeedMultiplier: number,
	MagicSlowMultiplier: number,
	MagicCastingMultiplier: number,
	MagicRotationLocked: boolean,
	MagicCastingDirection: Vector3?,
	MagicBaseJumpHeight: number,
	MagicPreviousMultiplier: number?,
	MagicSpeedGraceUntil: number?,
	MagicJumpPowerBonus: number,
	MagicAerialSpeed: number,
	MagicAerialInput: Vector3,
	MagicAerialInputExpiresAt: number,
	MagicAerialAttachment: Attachment?,
	MagicAerialVelocity: LinearVelocity?,
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
	MagicRushUntil: number?, -- server-driven Rush (Dash/Blink) in progress, plus grace
	Combo: number,
	ReadyAt: number,
	ComboExpires: number,
	Attack: Attack?,
	ActiveAt: number,
	ActiveUntil: number,
	HitTargets: { [Humanoid]: boolean },
	HitConstructs: { [any]: boolean }?, -- Construct records hit by this swing
	Heavy: boolean,
	Blocking: boolean,
	AttackFacing: Vector3?, -- Flat facing the client swung toward, once checked against the server's.
	DamageScale: number, -- Multiplier for the current swing (a parry bonus raises it).
	ParryBonusUntil: number,
}

return {}
