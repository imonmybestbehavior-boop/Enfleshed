local source = workspace.single_flame_transport.Flame_00
local statuses = {}
local ok, err = pcall(function()
	game:GetService("ContentProvider"):PreloadAsync({source},function(content,status)
		table.insert(statuses,{Content=content,Status=status.Name})
	end)
end)
local loaded, mesh = pcall(function()
	return game:GetService("AssetService"):CreateMeshPartAsync(source.MeshId)
end)
local result = {PreloadOK=ok,Statuses=statuses,MeshFetchOK=loaded}
if not ok then result.PreloadError=tostring(err) end
if loaded then result.FetchedSize={mesh.Size.X,mesh.Size.Y,mesh.Size.Z};mesh:Destroy() else result.MeshFetchError=tostring(mesh) end
return game:GetService("HttpService"):JSONEncode(result)
