--!strict
-- Shared checkpoints. Each player has a "reached" stage; the run's SharedStage is the lowest of them.
-- You can't claim a checkpoint more than Config.Checkpoints.MaxStagesAhead past your partner,
-- so the faster monkey waits instead of leaving the slower one behind.
--
-- Replicated state the client reads:
--   Player attribute  ReachedStage  (number)
--   Workspace attrs   SharedStage, FinalStage (number), RunComplete (boolean)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)

local CheckpointService = {}

local checkpoints: { [number]: BasePart } = {}
local reached: { [Player]: number } = {}
local lastRespawnAt: { [Player]: number } = {}

local function playerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end
	return Players:GetPlayerFromCharacter(character)
end

local function getRoot(character: Model?): BasePart?
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function CheckpointService.getSharedStage(): number
	local shared: number? = nil
	for _, stage in reached do
		if shared == nil or stage < shared then
			shared = stage
		end
	end
	return shared or 0
end

function CheckpointService.getFinalStage(): number
	local final = 0
	for stage in checkpoints do
		if stage > final then
			final = stage
		end
	end
	return final
end

local function publish()
	local shared = CheckpointService.getSharedStage()
	local final = CheckpointService.getFinalStage()
	Workspace:SetAttribute("SharedStage", shared)
	Workspace:SetAttribute("FinalStage", final)
	Workspace:SetAttribute("RunComplete", final > 0 and shared >= final)
end

local function onCheckpointTouched(stage: number, hit: BasePart)
	local player = playerFromHit(hit)
	if not player then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local current = reached[player] or 0
	-- In order only, so nobody skips a stage by flinging past it. (Day 6 adds timing checks.)
	if stage ~= current + 1 then
		return
	end
	if stage > CheckpointService.getSharedStage() + Config.Checkpoints.MaxStagesAhead then
		return
	end

	reached[player] = stage
	player:SetAttribute("ReachedStage", stage)
	publish()
end

local function registerCheckpoint(instance: Instance)
	if not instance:IsA("BasePart") then
		warn(`[Monkey] {instance:GetFullName()} is tagged Checkpoint but isn't a part.`)
		return
	end
	local stage = instance:GetAttribute("Stage")
	if typeof(stage) ~= "number" then
		warn(`[Monkey] Checkpoint {instance:GetFullName()} needs a number attribute "Stage".`)
		return
	end
	local existing = checkpoints[stage]
	if existing and existing ~= instance then
		warn(`[Monkey] Two checkpoints use Stage {stage}: {existing:GetFullName()} and {instance:GetFullName()}`)
	end
	checkpoints[stage] = instance
	instance.Touched:Connect(function(hit)
		onCheckpointTouched(stage, hit)
	end)
	publish()
end

function CheckpointService.getRespawnCFrame(player: Player): CFrame
	local stage = if Config.Checkpoints.RespawnAt == "Shared"
		then CheckpointService.getSharedStage()
		else (reached[player] or 0)

	-- Fall back to the nearest lower checkpoint if this one is missing.
	local part = checkpoints[stage]
	while not part and stage > 0 do
		stage -= 1
		part = checkpoints[stage]
	end

	if part then
		local position = part.Position + Vector3.new(0, part.Size.Y / 2 + Config.Checkpoints.RespawnHeight, 0)
		local look = part.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.01 then
			flat = Vector3.new(0, 0, -1)
		end
		return CFrame.lookAt(position, position + flat.Unit)
	end

	local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn and spawn:IsA("SpawnLocation") then
		return spawn.CFrame + Vector3.new(0, 4, 0)
	end
	return CFrame.new(0, 100, 0)
end

local function sendRespawn(player: Player)
	local now = os.clock()
	if now - (lastRespawnAt[player] or -math.huge) < 0.75 then
		return
	end
	lastRespawnAt[player] = now
	Remotes.Respawn:FireClient(player, CheckpointService.getRespawnCFrame(player))
end

local function registerFloor(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	instance.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		if player then
			sendRespawn(player)
		end
	end)
end

local function onPlayerAdded(player: Player)
	reached[player] = 0
	player:SetAttribute("ReachedStage", 0)
	publish()

	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			return
		end
		task.defer(function()
			if character.Parent then
				character:PivotTo(CheckpointService.getRespawnCFrame(player))
			end
		end)
	end)
end

function CheckpointService.start()
	for _, instance in CollectionService:GetTagged(Tags.Checkpoint) do
		registerCheckpoint(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Checkpoint):Connect(registerCheckpoint)

	for _, instance in CollectionService:GetTagged(Tags.ForestFloor) do
		registerFloor(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.ForestFloor):Connect(registerFloor)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		reached[player] = nil
		lastRespawnAt[player] = nil
		publish()
	end)

	local respawnLimiter = RateLimiter.new(4, 2)
	Remotes.RequestRespawn.OnServerEvent:Connect(function(player: Player)
		if respawnLimiter:allow(player) then
			sendRespawn(player)
		end
	end)

	-- Backstop: anyone below KillY is sent back even if their client never asked.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then
			return
		end
		elapsed = 0
		for player in reached do
			local root = getRoot(player.Character)
			if root and root.Position.Y < Config.Checkpoints.KillY then
				sendRespawn(player)
			end
		end
	end)
end

return CheckpointService
