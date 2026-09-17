-- Installer: lives at the root of TheWarehouse.rbxmx. When you press Play it moves each service folder's
-- contents into the real service (ReplicatedStorage, ServerScriptService, StarterPlayer...), enables the
-- server scripts, hands client scripts to players who already joined, then deletes itself.
-- Nothing here runs in edit mode, so inserting the model does not touch your place until Play.
local Players = game:GetService("Players")

local root = script.Parent
if not root or root == game or root:IsA("DataModel") then return end

local function enableScripts(inst: Instance)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("Script") then d.Disabled = false end
	end
	if inst:IsA("Script") then inst.Disabled = false end
end

-- Merge `folder`'s children into `container`. Same-named Folders merge recursively; anything else replaces.
local function installInto(container: Instance, folder: Instance)
	for _, child in ipairs(folder:GetChildren()) do
		local existing = container:FindFirstChild(child.Name)
		if existing and child:IsA("Folder") and existing:IsA("Folder") then
			installInto(existing, child)
		elseif existing and child:IsA("Folder") and not existing:IsA("Folder") then
			-- e.g. our Folder "StarterPlayerScripts" merging into the real StarterPlayerScripts
			installInto(existing, child)
		else
			if existing then existing:Destroy() end
			child.Parent = container
			enableScripts(child)
		end
	end
end

for _, serviceFolder in ipairs(root:GetChildren()) do
	if serviceFolder:IsA("Folder") then
		local ok, service = pcall(function() return game:GetService(serviceFolder.Name) end)
		if ok and service then
			installInto(service, serviceFolder)
		else
			warn("[Warehouse installer] unknown service " .. serviceFolder.Name)
		end
	end
end

-- Players who joined before the install happened never received the LocalScripts; give them a copy.
local starterScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if starterScripts then
	for _, player in ipairs(Players:GetPlayers()) do
		local ps = player:FindFirstChild("PlayerScripts")
		if ps then
			for _, s in ipairs(starterScripts:GetChildren()) do
				-- Folders too: Rojo puts the LocalScripts inside a "Client" folder, and LocalScripts run anywhere under PlayerScripts.
				if not ps:FindFirstChild(s.Name) then s:Clone().Parent = ps end
			end
		end
	end
end

print("[Warehouse] installed. Edit files in the repo, rebuild, re-insert TheWarehouse.rbxmx to update.")
root:Destroy()
