--!strict
-- Reusable set dressing. Small props are decorative (no collision/query) so they
-- never snag enemy pathing; anything that blocks movement says so by name.
local Kit = require(script.Parent.Kit)

local Props = {}
local C, M = Kit.Color, Kit.Material

function Props.well(parent: Instance, at: Vector3)
	local model = Instance.new("Model")
	model.Name = "Well"
	local ring = Kit.part(
		model,
		"WellRing",
		Vector3.new(3, 7, 7),
		CFrame.new(at + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		M.Rock,
		C.SlateWet
	)
	ring.Shape = Enum.PartType.Cylinder
	for _, side in { -1, 1 } do
		Kit.detail(
			model,
			"WellPost",
			Vector3.new(0.6, 6, 0.6),
			CFrame.new(at + Vector3.new(side * 3, 5, 0)),
			M.Timber,
			C.Oak
		)
	end
	Kit.detail(model, "WellBeam", Vector3.new(7, 0.6, 0.6), CFrame.new(at + Vector3.new(0, 8, 0)), M.Timber, C.Oak)
	Kit.lantern(model, at + Vector3.new(0, 6.5, 0))
	model.Parent = parent
end

function Props.gallows(parent: Instance, at: Vector3)
	local model = Instance.new("Model")
	model.Name = "Gallows"
	Kit.part(model, "Platform", Vector3.new(12, 4, 8), CFrame.new(at + Vector3.new(0, 2, 0)), M.Wood, C.Oak)
	Kit.detail(model, "Upright", Vector3.new(0.9, 10, 0.9), CFrame.new(at + Vector3.new(-4, 9, 0)), M.Timber, C.Oak)
	Kit.detail(model, "Arm", Vector3.new(7, 0.8, 0.8), CFrame.new(at + Vector3.new(-1, 13.6, 0)), M.Timber, C.Oak)
	for _, x in { 0, 2 } do
		Kit.detail(
			model,
			"Noose",
			Vector3.new(0.15, 3, 0.15),
			CFrame.new(at + Vector3.new(x, 11.8, 0)),
			Enum.Material.Fabric,
			C.OakPale
		)
	end
	Props.crow(model, at + Vector3.new(1, 14.3, 0))
	model.Parent = parent
end

function Props.cart(parent: Instance, at: Vector3, yaw: number)
	local model = Instance.new("Model")
	model.Name = "BrokenCart"
	local base = CFrame.new(at) * CFrame.Angles(0, yaw, 0.18)
	Kit.part(model, "Bed", Vector3.new(5, 1, 8), base * CFrame.new(0, 2.2, 0), M.Wood, C.OakPale)
	for _, side in { -1, 1 } do
		Kit.detail(model, "Side", Vector3.new(0.3, 1.5, 8), base * CFrame.new(side * 2.4, 3.2, 0), M.Wood, C.Oak)
	end
	local wheel = Kit.detail(model, "Wheel", Vector3.new(0.5, 4, 4), base * CFrame.new(2.8, 2, -1.5), M.Timber, C.Oak)
	wheel.Shape = Enum.PartType.Cylinder
	Kit.detail(model, "LooseWheel", Vector3.new(4, 0.5, 4), CFrame.new(at + Vector3.new(-4, 0.3, 2)), M.Timber, C.Oak)
	model.Parent = parent
end

function Props.fenceLoop(parent: Instance, center: Vector3, width: number, depth: number)
	local corners = {
		center + Vector3.new(-width / 2, 0, -depth / 2),
		center + Vector3.new(width / 2, 0, -depth / 2),
		center + Vector3.new(width / 2, 0, depth / 2),
		center + Vector3.new(-width / 2, 0, depth / 2),
	}
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local length = (b - a).Magnitude
		for d = 0, length, 4 do
			-- Leave a gate gap in the middle of the front run, and gaps where posts rotted.
			if not (i == 1 and math.abs(d - length / 2) < 4) and (d * 7 + i) % 11 ~= 0 then
				local p = a + (b - a).Unit * d
				Kit.detail(
					parent,
					"FencePost",
					Vector3.new(0.4, 3.4, 0.4),
					CFrame.new(p + Vector3.new(0, 1.7, 0)),
					Enum.Material.Metal,
					C.Iron
				)
			end
		end
		Kit.detail(
			parent,
			"FenceRail",
			Vector3.new(0.25, 0.25, length),
			CFrame.lookAt((a + b) / 2 + Vector3.new(0, 2.8, 0), b + Vector3.new(0, 2.8, 0)),
			Enum.Material.Metal,
			C.Iron
		)
	end
end

function Props.deadTree(parent: Instance, at: Vector3, seed: number)
	local model = Instance.new("Model")
	model.Name = "DeadTree"
	local lean = ((seed * 37) % 10 - 5) * 0.02
	Kit.part(
		model,
		"Trunk",
		Vector3.new(2, 16, 2),
		CFrame.new(at + Vector3.new(0, 8, 0)) * CFrame.Angles(lean, 0, -lean),
		Enum.Material.Wood,
		Color3.fromRGB(38, 32, 28)
	)
	for i = 1, 3 do
		local angle = seed + i * 2.1
		Kit.detail(
			model,
			"Branch",
			Vector3.new(0.7, 0.7, 7),
			CFrame.new(at + Vector3.new(0, 9 + i * 2, 0)) * CFrame.Angles(0.5, angle, 0) * CFrame.new(0, 0, -3.5),
			Enum.Material.Wood,
			Color3.fromRGB(38, 32, 28)
		)
	end
	Props.crow(model, at + Vector3.new(0, 16.4, 0))
	model.Parent = parent
end

function Props.crow(parent: Instance, at: Vector3)
	Kit.detail(
		parent,
		"Crow",
		Vector3.new(0.6, 0.7, 1.1),
		CFrame.new(at),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(14, 14, 16)
	)
end

function Props.spikes(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local dir = (to - from).Unit
	for d = 1, length, 3 do
		local p = from + dir * d
		Kit.detail(
			parent,
			"Stake",
			Vector3.new(0.6, 5, 0.6),
			CFrame.lookAt(p, p + dir) * CFrame.Angles(-0.7, 0, 0) * CFrame.new(0, 1.8, 0),
			M.Timber,
			C.Oak
		)
	end
end

function Props.chains(parent: Instance, top: Vector3, length: number)
	Kit.detail(
		parent,
		"Chain",
		Vector3.new(0.3, length, 0.3),
		CFrame.new(top - Vector3.new(0, length / 2, 0)),
		Enum.Material.Metal,
		C.Iron
	)
end

return Props
