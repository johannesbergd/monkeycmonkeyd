--!strict
-- Falling off the world: the client notices first and asks; the server decides where you go back to
-- (your checkpoint), and this client moves its own monkey there.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CharacterContext = require(script.Parent.CharacterContext)
local MovementController = require(script.Parent.MovementController)
local RagdollController = require(script.Parent.RagdollController)

local RespawnController = {}

function RespawnController.init()
	Remotes.Respawn.OnClientEvent:Connect(function(target: unknown)
		if typeof(target) ~= "CFrame" then
			return
		end
		local rig = CharacterContext.get()
		if not rig then
			return
		end
		RagdollController.stop()
		MovementController.reset()
		rig.root.AssemblyLinearVelocity = Vector3.zero
		rig.root.AssemblyAngularVelocity = Vector3.zero
		rig.character:PivotTo(target)
	end)

	local lastAskedAt = -math.huge
	RunService.Heartbeat:Connect(function()
		local rig = CharacterContext.get()
		if not rig then
			return
		end
		local now = os.clock()
		if rig.root.Position.Y < Config.Checkpoints.KillY and now - lastAskedAt > 1 then
			lastAskedAt = now
			Remotes.RequestRespawn:FireServer()
		end
	end)
end

return RespawnController
