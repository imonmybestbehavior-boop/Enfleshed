--!strict

export type ValidationResult = "VALID" | "UNSAFE" | "IMPOSSIBLE"

export type CastIntent = {
	SpellId: string,
	AimDirection: Vector3,
	WorldPoint: Vector3?,
}

export type ActiveSpell = {
	SpellId: string,
	Caster: Model,
	Age: number,
	CurrentPhase: string,
	TargetsHit: { [Humanoid]: boolean },
	RemainingLifetime: number,
}

return {}
