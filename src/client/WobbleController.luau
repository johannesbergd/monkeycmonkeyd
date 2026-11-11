--!strict
-- The goofy look: every monkey leans into its run, waddles, lets its head lag behind, and flails its
-- arms in the air. This is drawn locally on every client for every monkey, from replicated speed and the
-- "Hanging"/"Ragdolled" attributes, so it costs no network traffic.
--
-- It works by offsetting each joint's frame (Motor6D.C0 on classic rigs, the joint's first attachment on
-- upgraded rigs; see RigJoints) on top of whatever the Animator is playing. Changes made on a client
-- don't replicate, which is exactly what we want here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local RigJoints = require(ReplicatedStorage.Shared.RigJoints)
local Spring = require(ReplicatedStorage.Shared.Spring)

type Joint = {
	joint: Instance, -- Motor6D or AnimationConstraint
	base: CFrame, -- the frame the rig was built with
	written: CFrame, -- the frame we last wrote; if it differs, someone else changed the rig
}

type Wobbler = {
	character: Model,
	root: BasePart,
	joints: { [string]: Joint },
	lean: Spring.Spring, -- X = pitch, Z = roll
	head: Spring.Spring, -- X = pitch, Z = roll
	arms: Spring.Spring, -- X: 0 = rest, 1 = flailing, 2 = reaching overhead
	lastVelocity: Vector3,
	stepPhase: number,
	seed: number,
	resting: boolean,
}

local JOINT_NAMES = { "Root", "Waist", "Neck", "LeftShoulder", "RightShoulder" }

local WobbleController = {}

local wobblers: { [Model]: Wobbler } = {}

local function differs(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude > 1e-3
		or a.LookVector:Dot(b.LookVector) < 0.99999
		or a.UpVector:Dot(b.UpVector) < 0.99999
end

local function apply(wobbler: Wobbler, name: string, offset: CFrame)
	local joint = wobbler.joints[name]
	if not joint or not joint.joint.Parent then
		return
	end
	local current = RigJoints.readFrame(joint.joint)
	if not current then
		return
	end
	if differs(current, joint.written) then
		-- The rig was rescaled or rebuilt (e.g. avatar loaded): adopt the new rest pose.
		joint.base = current
	end
	local value = joint.base * offset
	RigJoints.writeFrame(joint.joint, value)
	joint.written = value
end

local function restore(wobbler: Wobbler)
	if wobbler.resting then
		return
	end
	wobbler.resting = true
	for _, joint in wobbler.joints do
		local current = joint.joint.Parent and RigJoints.readFrame(joint.joint)
		if current and not differs(current, joint.written) then
			RigJoints.writeFrame(joint.joint, joint.base)
			joint.written = joint.base
		end
	end
end

local function track(character: Model)
	if wobblers[character] then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") then
		return
	end
	character:WaitForChild("UpperTorso", 10)

	local joints: { [string]: Joint } = {}
	for _, name in JOINT_NAMES do
		local joint = RigJoints.find(character, name)
		local frame = joint and RigJoints.readFrame(joint)
		if joint and frame then
			joints[name] = { joint = joint, base = frame, written = frame }
		end
	end

	wobblers[character] = {
		character = character,
		root = root,
		joints = joints,
		lean = Spring.new(),
		head = Spring.new(),
		arms = Spring.new(),
		lastVelocity = Vector3.zero,
		stepPhase = 0,
		seed = math.random() * 10,
		resting = true,
	}

	character.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			wobblers[character] = nil
		end
	end)
end

local function updateWobbler(wobbler: Wobbler, dt: number, now: number, cameraPosition: Vector3)
	local cfg = Config.Wobble
	local root = wobbler.root
	local character = wobbler.character

	if not cfg.Enabled
		or character:GetAttribute("Ragdolled") == true
		or (root.Position - cameraPosition).Magnitude > cfg.MaxDistance
	then
		restore(wobbler)
		return
	end
	wobbler.resting = false

	local hanging = character:GetAttribute("Hanging") == true
	local velocity = root.AssemblyLinearVelocity
	local accel = (velocity - wobbler.lastVelocity) / math.max(dt, 1 / 240)
	wobbler.lastVelocity = velocity

	local localVelocity = root.CFrame:VectorToObjectSpace(velocity)
	local localAccel = root.CFrame:VectorToObjectSpace(accel)
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local airborne = math.abs(velocity.Y) > 6

	-- Body: lean forward into the run, sideways into strafes, and waddle while walking.
	wobbler.stepPhase += horizontalSpeed * cfg.WaddleStepsPerStud * dt * math.pi
	local walking = if airborne or hanging then 0 else math.clamp(horizontalSpeed / 16, 0, 1)
	local waddle = math.sin(wobbler.stepPhase) * cfg.WaddleAmount * walking
	-- Negative pitch tips the top of the body forward (-Z); negative roll tips it right (+X).
	local forwardSpeed = -localVelocity.Z
	local sideSpeed = localVelocity.X
	local pitch = math.clamp(-forwardSpeed * cfg.LeanPerSpeed, -cfg.MaxLean, cfg.MaxLean)
	local roll = math.clamp(-sideSpeed * cfg.LeanPerSpeed, -cfg.MaxLean, cfg.MaxLean) + waddle
	if hanging then
		pitch, roll = 0, 0
	end
	wobbler.lean.target = Vector3.new(pitch, 0, roll)
	Spring.step(wobbler.lean, dt, cfg.SpringSpeed, cfg.SpringDamping)

	-- Head: lags behind acceleration, then overshoots and settles.
	local headPitch = math.clamp(-localAccel.Z * cfg.HeadLagPerAccel, -cfg.MaxHeadLag, cfg.MaxHeadLag)
	local headRoll = math.clamp(localAccel.X * cfg.HeadLagPerAccel, -cfg.MaxHeadLag, cfg.MaxHeadLag)
	wobbler.head.target = Vector3.new(headPitch, 0, headRoll)
	Spring.step(wobbler.head, dt, cfg.SpringSpeed * 0.8, cfg.SpringDamping * 0.7)

	-- Arms: rest, flail in the air, or reach overhead while hanging.
	local armMode = if hanging then 2 elseif airborne then 1 else 0
	wobbler.arms.target = Vector3.new(armMode, 0, 0)
	Spring.step(wobbler.arms, dt, cfg.SpringSpeed, 0.6)
	local mode = wobbler.arms.position.X
	local flail = math.clamp(1 - math.abs(mode - 1), 0, 1) * cfg.ArmFlailAmount
	local overhead = math.clamp(mode - 1, 0, 1)
	local flap = math.sin(now * cfg.ArmFlailSpeed + wobbler.seed)
	local flapOther = math.sin(now * cfg.ArmFlailSpeed * 1.13 + wobbler.seed * 2)
	local rightPitch = flail * (1.5 + flap * 0.8) + overhead * 2.8
	local leftPitch = flail * (1.5 + flapOther * 0.8) + overhead * 2.8
	local spread = flail * 0.6 + overhead * 0.15

	-- Positive X rotation raises an arm forward and up; positive Z on the right arm (negative on the left) swings it out.
	local lean = wobbler.lean.position
	local head = wobbler.head.position
	apply(wobbler, "Root", CFrame.Angles(lean.X * 0.6, 0, lean.Z * 0.6))
	apply(wobbler, "Waist", CFrame.Angles(lean.X * 0.6, 0, lean.Z * 0.6))
	apply(wobbler, "Neck", CFrame.Angles(head.X, 0, head.Z))
	apply(wobbler, "RightShoulder", CFrame.Angles(rightPitch, 0, spread))
	apply(wobbler, "LeftShoulder", CFrame.Angles(leftPitch, 0, -spread))
end

function WobbleController.init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(track, character)
		end)
		if player.Character then
			task.spawn(track, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	RunService.PreRender:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPosition = camera.CFrame.Position
		local now = os.clock()
		for _, wobbler in wobblers do
			updateWobbler(wobbler, dt, now, cameraPosition)
		end
	end)
end

return WobbleController
