--!strict
-- Small bounded clone pool for reusable visual templates. DestroyAll releases pooled assets.
local Pool = {}
Pool.__index = Pool

function Pool.new(maxPerKey: number?)
	return setmetatable({ MaxPerKey = maxPerKey or 12, Available = {} }, Pool)
end

function Pool:Acquire(key: string, template: Instance): Instance
	local bucket = self.Available[key]
	local instance = bucket and table.remove(bucket)
	if not instance then
		instance = template:Clone()
	end
	return instance
end

function Pool:Release(key: string, instance: Instance)
	instance.Parent = nil
	local bucket = self.Available[key] or {}
	self.Available[key] = bucket
	if #bucket >= self.MaxPerKey then
		instance:Destroy()
	else
		table.insert(bucket, instance)
	end
end

function Pool:DestroyAll()
	for _, bucket in self.Available do
		for _, instance in bucket do
			instance:Destroy()
		end
	end
	table.clear(self.Available)
end

return Pool
