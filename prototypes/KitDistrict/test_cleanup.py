"""Execute the harness's actual cleanup callbacks using small Lua engine doubles."""
from pathlib import Path
import subprocess

source = Path(__file__).with_name('Server.server.luau').read_text()
clear = source[source.index('local function clear()'):source.index('-- EnemyRuntime retires')]
clear = clear.replace('in handles do', 'in ipairs(handles) do').replace('in folder:GetChildren() do', 'in ipairs(folder:GetChildren()) do')
heartbeat = source[source.index('local cleanupElapsed = 0'):source.index('prompt.Triggered:Connect')]
heartbeat = heartbeat.replace('cleanupElapsed += delta', 'cleanupElapsed = cleanupElapsed + delta')
setup = '''
local function model(alive)
 return {Parent = alive and true or nil, IsA = function(_, kind) return kind == 'Model' end,
 Destroy = function(self) self.Parent = nil end}
end
local alive, dead, removed = model(true), model(true), model(false)
local console = {IsA = function() return false end}
local function handle(m, isAlive)
 return {Model=m, IsAlive=function() return isAlive end, Destroy=function() m:Destroy() end}
end
local handles = {handle(alive,true),handle(dead,false),handle(removed,false)}
local folder = {GetChildren=function() return {alive,dead,console} end, SetAttribute=function(self,k,v) self[k]=v end}
local scheduled = {}
local Debris = {AddItem=function(_, m, seconds) table.insert(scheduled,{m,seconds}) end}
local callback
local RunService = {Heartbeat={Connect=function(_, fn) callback=fn end}}
local corpseLifetime = 2
function table.clear(t) for k in pairs(t) do t[k]=nil end end
'''
checks = '''
callback(.1)
assert(#handles == 3 and #scheduled == 0, 'Tick must be bounded')
callback(.1)
assert(#handles == 1 and handles[1].Model == alive, 'Retire dead and externally removed handles')
assert(#scheduled == 1 and scheduled[1][1] == dead and scheduled[1][2] == 2, 'Dead corpse receives two-second removal')
callback(.3)
assert(#scheduled == 1, 'Never schedule the same corpse repeatedly')
assert(folder.Living == 1)
clear()
assert(#handles == 0 and folder.Living == 0, 'Manual clear resets living state')
assert(not alive.Parent and not dead.Parent, 'Manual clear removes live and pending dead models')
print('Corpse retirement, delay, deduplication and manual-clear checks passed')
'''
subprocess.run(['lua', '-'], input=setup + clear + heartbeat + checks, text=True, check=True)
