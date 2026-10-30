--!strict
-- Pure rules for spells reacting with the world (Phase 11f): Wet characters
-- conduct Lightning, Fire burns Flammable parts, Ice freezes water. Points are
-- anything with X/Y/Z (Vector3 in Roblox, plain tables in tests).
local Spec = {}

local function distance(a: any, b: any): number
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- A character is Wet with a Water mark, while swimming, or standing in water
-- (a Water-tagged part or Terrain water).
function Spec.isWet(state: any): boolean
	return type(state) == "table" and (state.Marked == true or state.Swimming == true or state.InWater == true)
end

-- The hops of a Lightning hit through Wet characters.
--   origin     = { Id, Position }  the character the hit landed on
--   candidates = { { Id, Position, Wet, Allowed, PvP = { MaxJumps, MaxFraction }? } }
--   opts       = { Hit, Radius, Fraction, Jumps }
-- Each hop goes to the nearest Wet, allowed character not hit yet in this
-- chain, within Radius of the last one struck, for Fraction of the original
-- hit. PvP candidates count toward their own MaxJumps and take at most
-- MaxFraction. Returns { { Target = candidate, Amount } } in hop order.
function Spec.chain(origin: any, candidates: { any }, opts: any): { any }
	local struck = { [origin.Id] = true }
	local current = origin.Position
	local hops = {}
	local pvpHops = 0
	for _ = 1, opts.Jumps do
		local best, bestDistance = nil, math.huge
		for _, candidate in candidates do
			local pvpOk = candidate.PvP == nil or pvpHops < candidate.PvP.MaxJumps
			if not struck[candidate.Id] and candidate.Wet and candidate.Allowed and pvpOk then
				local gap = distance(current, candidate.Position)
				if gap <= opts.Radius and gap < bestDistance then
					best, bestDistance = candidate, gap
				end
			end
		end
		if not best then
			break
		end
		struck[best.Id] = true
		current = best.Position
		local fraction = opts.Fraction
		if best.PvP then
			pvpHops += 1
			fraction = math.min(fraction, best.PvP.MaxFraction)
		end
		table.insert(hops, { Target = best, Amount = opts.Hit * fraction })
	end
	return hops
end

-- Which world reaction an impact causes: "Burn" (Fire on something
-- Flammable), "Freeze" (Ice on water) or nil. `surface` = { Flammable, Water }.
function Spec.reactionFor(element: string?, surface: any): string?
	if element == "Fire" and surface.Flammable then
		return "Burn"
	elseif element == "Ice" and surface.Water then
		return "Freeze"
	end
	return nil
end

-- A part ignites at most once every `cooldown` seconds.
function Spec.igniteAllowed(lastAt: number?, now: number, cooldown: number): boolean
	return lastAt == nil or now - lastAt >= cooldown
end

-- Per-caster limit: adds `record` to `list` (oldest first) and returns the
-- oldest record to end when the list is over `cap`, else nil.
function Spec.admit(list: { any }, record: any, cap: number): any?
	table.insert(list, record)
	if #list > cap then
		return table.remove(list, 1)
	end
	return nil
end

-- One line for editor previews: how a spell of `element` reacts with the
-- world, or nil when it does not.
function Spec.previewLine(element: string?, ignore: boolean?): string?
	local line = if element == "Lightning"
		then "Chains through wet targets"
		elseif element == "Fire" then "Sets Flammable things alight"
		elseif element == "Ice" then "Freezes water into platforms"
		else nil
	if line and ignore == true then
		return "Ignores the world"
	end
	return line
end

-- Removes a record that ended on its own (melted, broken, expired).
function Spec.forget(list: { any }, record: any)
	local index = table.find(list, record)
	if index then
		table.remove(list, index)
	end
end

return Spec
