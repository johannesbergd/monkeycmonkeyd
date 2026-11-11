--!strict
-- Sets up every monkey when it spawns: movement stats, collision group, ragdoll joints.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RagdollRig = require(ReplicatedStorage.Shared.RagdollRig)

local MONKEY_GROUP = "Monkeys"

local CharacterService = {}

local function setupCollisionGroup()
	if not PhysicsService:IsCollisionGroupRegistered(MONKEY_GROUP) then
		PhysicsService:RegisterCollisionGroup(MONKEY_GROUP)
	end
	-- Monkeys pass through each other, and a monkey's own limbs don't collide with each other while
	-- ragdolled. Two players' physics pushing each other is laggy and flings people; co-op moves like
	-- boosts are scripted instead (Day 2).
	PhysicsService:CollisionGroupSetCollidable(MONKEY_GROUP, MONKEY_GROUP, false)
end

local function applyGroup(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = MONKEY_GROUP
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		warn(`[Monkey] {player.Name} spawned as R6. Set Avatar Type to R15 in Game Settings > Avatar.`)
	end

	humanoid.WalkSpeed = Config.Movement.WalkSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = Config.Movement.JumpHeight
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false

	for _, descendant in character:GetDescendants() do
		applyGroup(descendant)
	end
	character.DescendantAdded:Connect(applyGroup)

	-- R15 limbs can arrive a moment after the character; wait for the last ones before building joints.
	character:WaitForChild("UpperTorso", 10)
	character:WaitForChild("RightFoot", 10)
	character:WaitForChild("LeftFoot", 10)
	if character.Parent then
		RagdollRig.build(character)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	-- Avatar appearance can swap body parts after spawn; build() skips joints that already exist.
	player.CharacterAppearanceLoaded:Connect(function(character)
		RagdollRig.build(character)
		for _, descendant in character:GetDescendants() do
			applyGroup(descendant)
		end
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function CharacterService.start()
	setupCollisionGroup()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CharacterService
