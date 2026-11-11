--!strict
-- Ragdolls the local monkey: instantly on this client, then tells the server so everyone else sees it.
-- Triggers: the flop button, hard landings (MovementController), and the server (hazards, Day 2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local RagdollRig = require(ReplicatedStorage.Shared.RagdollRig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Signal = require(ReplicatedStorage.Shared.Signal)
local CharacterContext = require(script.Parent.CharacterContext)

local RagdollController = {}

-- Fires right before the monkey goes limp, so movement can drop any hang or dash first.
RagdollController.Started = Signal.new()

local active = false
local endsAt = 0
local lastFlopAt = -math.huge
local savedCollision: { [BasePart]: boolean } = {}

local function setBodyCollision(character: Model, ragdolled: boolean)
	if ragdolled then
		table.clear(savedCollision)
		for _, descendant in character:GetDescendants() do
			if descendant:IsA("BasePart") and not descendant:FindFirstAncestorOfClass("Accessory") then
				savedCollision[descendant] = descendant.CanCollide
				-- Limbs need to hit the ground; the invisible root box would prop the body up, so it goes through.
				descendant.CanCollide = descendant.Name ~= "HumanoidRootPart"
			end
		end
	else
		for part, canCollide in savedCollision do
			if part.Parent then
				part.CanCollide = canCollide
			end
		end
		table.clear(savedCollision)
	end
end

function RagdollController.isActive(): boolean
	return active
end

function RagdollController.start(duration: number)
	local rig = CharacterContext.get()
	if not rig or rig.humanoid.Health <= 0 then
		return
	end
	if active then
		endsAt = math.max(endsAt, os.clock() + duration)
		return
	end
	if not RagdollRig.isBuilt(rig.character) then
		return -- joints haven't replicated yet (first second after spawning)
	end

	active = true
	endsAt = os.clock() + duration
	RagdollController.Started:Fire()

	RagdollRig.setRagdolled(rig.character, true)
	setBodyCollision(rig.character, true)
	rig.character:SetAttribute("Ragdolled", true)
	rig.humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	Remotes.RagdollRequest:FireServer(true)

	-- A random tumble so no two flops look the same.
	local spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	rig.root:ApplyAngularImpulse(spin * (Config.Ragdoll.SpinImpulse * rig.root.AssemblyMass))
end

function RagdollController.stop()
	if not active then
		return
	end
	active = false
	local rig = CharacterContext.get()
	if not rig then
		table.clear(savedCollision)
		return
	end
	RagdollRig.setRagdolled(rig.character, false)
	setBodyCollision(rig.character, false)
	rig.character:SetAttribute("Ragdolled", false)
	Remotes.RagdollRequest:FireServer(false)
	if rig.humanoid.Health > 0 then
		rig.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

function RagdollController.flop()
	if active then
		return
	end
	local now = os.clock()
	if now - lastFlopAt < Config.Ragdoll.FlopCooldown then
		return
	end
	lastFlopAt = now
	RagdollController.start(Config.Ragdoll.FlopTime)
end

function RagdollController.init()
	Remotes.ForceRagdoll.OnClientEvent:Connect(function(duration: unknown)
		if typeof(duration) ~= "number" then
			return
		end
		if duration <= 0 then
			RagdollController.stop()
		else
			RagdollController.start(math.min(duration, Config.Ragdoll.MaxTime))
		end
	end)

	RunService.Heartbeat:Connect(function()
		if active and os.clock() >= endsAt then
			RagdollController.stop()
		end
	end)

	CharacterContext.Changed:Connect(function()
		active = false
		table.clear(savedCollision)
	end)
end

return RagdollController
