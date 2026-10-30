-- Roblox shims for inventory specs. `sources` is supplied by the runner.
local base = getfenv()
local function vector(x, y, z)
	return { X = x or 0, Y = y or 0, Z = z or 0 }
end
local frame = setmetatable({}, {
	__mul = function(self)
		return self
	end,
})
base.Vector3 = { new = vector }
base.Color3 = {
	fromRGB = function(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end,
}
base.CFrame = {
	new = function()
		return frame
	end,
	Angles = function()
		return frame
	end,
}
base.Enum = { Material = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
}) }
-- Deterministic stand-in for Roblox Random.
base.Random = {
	new = function(seed)
		local state = seed or 1
		local rng = {}
		function rng:NextNumber(min, max)
			state = (state * 1103515245 + 12345) % 2147483648
			local unit = state / 2147483648
			return if min then min + (max - min) * unit else unit
		end
		function rng:NextInteger(min, max)
			return math.min(max, min + math.floor(self:NextNumber() * (max - min + 1)))
		end
		return rng
	end,
}

local tree = { Configuration = {}, Modules = {} }
for name in sources do
	local folder, leaf = string.match(name, "^(%w+)/(%w+)$")
	tree[folder][leaf] = name
end
tree.Configuration.Parent = tree
tree.Modules.Parent = tree
local cache = {}
local function load(name)
	if cache[name] == nil then
		local fn = assert(loadstring(sources[name], name))
		local folder = string.match(name, "^(%w+)/")
		local env = setmetatable({ script = { Parent = tree[folder] }, require = load }, { __index = base })
		setfenv(fn, env)
		cache[name] = fn()
	end
	return cache[name]
end
base.loadModule = load
