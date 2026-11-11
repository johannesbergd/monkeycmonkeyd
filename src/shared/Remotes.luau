--!strict
-- One place that lists every RemoteEvent. The server creates them; clients wait for them.
-- Works with or without Rojo, because nothing has to exist in the place file beforehand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local folder: Instance
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function event(name: string): RemoteEvent
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return {
	-- client -> server: (on: boolean) "I started / stopped ragdolling"
	RagdollRequest = event("RagdollRequest"),
	-- server -> client: (duration: number) "ragdoll now" (0 or less = get up now)
	ForceRagdoll = event("ForceRagdoll"),
	-- client -> server: (hanging: boolean)
	HangState = event("HangState"),
	-- client -> server: () "I fell off the world"
	RequestRespawn = event("RequestRespawn"),
	-- server -> client: (target: CFrame) "move your monkey here"
	Respawn = event("Respawn"),
}
