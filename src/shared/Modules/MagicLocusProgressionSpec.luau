--!strict

-- Derives a bounded Locus profile from validated successful-cast practice.
local Spec = {}

local metricKeys = { "Capacity", "Efficiency", "Potency", "StrainTolerance", "ComplexityCapacity" }

local function finiteNonnegative(value)
	return type(value) == "number" and value == value and value >= 0 and value < math.huge
end

function Spec.profile(baseProfile, config, successfulCasts)
	local metrics = {}
	for _, key in ipairs(metricKeys) do
		metrics[key] = baseProfile[key]
	end

	local rank = 0
	local castsPerRank = config and config.PracticeCastsPerRank
	local maximumRank = config and config.MaximumRank
	local validConfig = type(config) == "table"
		and config.Enabled == true
		and finiteNonnegative(castsPerRank)
		and castsPerRank >= 1
		and castsPerRank % 1 == 0
		and finiteNonnegative(maximumRank)
		and maximumRank % 1 == 0
		and type(config.PerRank) == "table"
	if not validConfig then
		return { Rank = 0, Progress = 0, CastsToNextRank = nil, Metrics = metrics }
	end

	local practice = 0
	if finiteNonnegative(successfulCasts) then
		practice = math.floor(successfulCasts)
	end
	rank = math.min(maximumRank, math.floor(practice / castsPerRank))
	for _, key in ipairs(metricKeys) do
		local increase = config.PerRank[key]
		if finiteNonnegative(increase) then
			metrics[key] = metrics[key] + increase * rank
		end
	end

	local progress, castsToNextRank = 1, nil
	if rank < maximumRank then
		local withinRank = practice % castsPerRank
		progress = withinRank / castsPerRank
		castsToNextRank = castsPerRank - withinRank
	end
	return {
		Rank = rank,
		Progress = progress,
		CastsToNextRank = castsToNextRank,
		Metrics = metrics,
	}
end

function Spec.maximumProfile(baseProfile, config)
	local maximumRank = 0
	if config and config.Enabled == true and finiteNonnegative(config.MaximumRank) then
		maximumRank = math.floor(config.MaximumRank)
	end
	local metrics = {}
	for _, key in ipairs(metricKeys) do
		local increase = config and config.PerRank and config.PerRank[key]
		metrics[key] = baseProfile[key]
		if finiteNonnegative(increase) then
			metrics[key] = metrics[key] + increase * maximumRank
		end
	end
	return metrics
end

return Spec
