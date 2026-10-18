-- Studio Command Bar (Edit mode is fine): reads the real Mesh ids out of uploaded VFX Model
-- packages. Paste the printed block back to Claude; it goes into assets/vfx/asset_ids.json.
-- Model ids transcribed from Asset Manager screenshots (2026-10-15).
local models = {
	chain_link_ink = 81504973153621,
	chrono_gear = 82714605010185,
	comet_spike_ink = 78037480706759,
	debris_rock_a_ink = 70390827954228,
	debris_rock_b_ink = 129130015021118,
	debris_rock_c_ink = 76427551510832,
	earth_boulder = 109402033472490,
	earth_boulder_ink = 77851159212533,
	earth_slab = 116920637522740,
	earth_slab_ink = 88031464073751,
	earth_spire_ink = 126259655810463,
	flame_tongue_ink = 94732918597004,
	hourglass = 89494984192098,
	hourglass_ink = 140396528481779,
	ice_cluster = 84507414108104,
	ice_shard_a = 114380249161712,
	ice_shard_a_ink = 87879512313019,
	ice_shard_b_ink = 137828537838703,
	ice_spike = 134572412943775,
	ice_spike_ink = 82068738762371,
	lightning_fork = 77491592832693,
	lightning_fork_ink = 109531784659764,
	poison_bubbles_ink = 116459437751941,
	poison_thorn = 99474023079975,
	rift_frame = 85386108417462,
	sinew_tendril_ink = 102132732046583,
	soul_skull = 70834730945680,
	void_shard_ink = 72825602213055,
	ward_dome = 81363178467721,
	water_crown = 123683108134156,
	water_curl = 86511475613291,
	wind_funnel = 73924220355980,
}
local InsertService = game:GetService("InsertService")
local lines, failed = {}, {}
for name, modelId in models do
	local ok, result = pcall(function()
		return InsertService:LoadAsset(modelId)
	end)
	local meshPart = ok and result and result:FindFirstChildWhichIsA("MeshPart", true)
	local digits = meshPart and string.match(meshPart.MeshId, "(%d+)")
	if digits then
		table.insert(lines, string.format('"mesh:%s": %s,', name, digits))
	else
		table.insert(failed, name .. " (" .. tostring(if ok then "no MeshPart in model" else result) .. ")")
	end
	if ok and result then
		result:Destroy()
	end
end
table.sort(lines)
print("---- VFX mesh ids (" .. #lines .. ") ----\n" .. table.concat(lines, "\n"))
for _, line in failed do
	warn("[VFX mesh ids] failed: " .. line)
end
