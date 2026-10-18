--!strict
-- Default feature flags. Live overrides come from the "EnfleshedFeatureFlags_v1"
-- DataStore (see FeatureFlagService) and are merged over these at runtime.
--   Enabled         false = off for everyone (kill switch)
--   PublicReleaseAt unix seconds; before it only early-access players get the feature
-- Spell kill switches disable a Form, payload Kind or behavior Kind live without a publish.
return {
	RefreshSeconds = 60,
	-- Every feature listed here is checked somewhere; add the check with the flag.
	Features = {
		DefendTheWalls = { Enabled = true }, -- DefendTheWallsService: starting/joining a run
		LootDrops = { Enabled = true }, -- InventoryService.dropLoot
	},
	DisabledForms = {},
	DisabledPayloads = {},
	DisabledBehaviors = {},
}
