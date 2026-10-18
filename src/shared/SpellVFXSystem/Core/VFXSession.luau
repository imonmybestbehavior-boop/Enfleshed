--!strict
-- Owns all transient objects and asynchronous work for one cosmetic playback.
local Session = {}
Session.__index = Session

function Session.new(target: any, context: any, parent: Instance)
	local holder = Instance.new("Folder")
	holder.Name = "SpellVFXSession"
	holder.Parent = parent
	return setmetatable({
		Target = target,
		Context = context or {},
		Active = true,
		Holder = holder,
		Connections = {},
		Tweens = {},
		Tasks = {},
		CleanupCallbacks = {},
	}, Session)
end

function Session:AddConnection(connection: RBXScriptConnection)
	if self.Active then
		table.insert(self.Connections, connection)
	else
		connection:Disconnect()
	end
	return connection
end

function Session:AddTween(tween: Tween)
	if self.Active then
		table.insert(self.Tweens, tween)
	else
		tween:Cancel()
	end
	return tween
end

function Session:AddCleanup(callback: () -> ())
	if self.Active then
		table.insert(self.CleanupCallbacks, callback)
	else
		callback()
	end
end

function Session:Await(duration: number): boolean
	local deadline = os.clock() + math.max(0, duration)
	while self.Active and os.clock() < deadline do
		task.wait(math.min(0.05, deadline - os.clock()))
	end
	return self.Active
end

function Session:Stop()
	if not self.Active then
		return
	end
	self.Active = false
	for _, connection in self.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self.Connections)
	for _, tween in self.Tweens do
		pcall(function()
			tween:Cancel()
		end)
	end
	table.clear(self.Tweens)
	for _, callback in self.CleanupCallbacks do
		pcall(callback)
	end
	table.clear(self.CleanupCallbacks)
	for _, thread in self.Tasks do
		pcall(task.cancel, thread)
	end
	table.clear(self.Tasks)
	if self.Holder.Parent then
		self.Holder:Destroy()
	end
end

Session.Cancel = Session.Stop
return Session
