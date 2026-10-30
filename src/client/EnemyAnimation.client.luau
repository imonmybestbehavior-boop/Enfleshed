--!strict
-- Independent enemy presentation bootstrap; no magic/player controller dependency.
local controller = require(script.Parent.Controllers.EnemyAnimationController)
controller.start()
script.Destroying:Connect(controller.stop)
