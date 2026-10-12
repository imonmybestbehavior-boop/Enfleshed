--!strict
-- Geometry-review startup only; no population, missions or chase test starts here.
local city = workspace:WaitForChild("CitySaferSide")
local envelope = city:WaitForChild("AncientEnvelope") :: Model
envelope.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
require(script.Services.EnemyRuntime).start()
require(script.Networking.ActionRouter).start()
print("City safer-side assembly ready: internal opening and E/F neighborhoods.")
