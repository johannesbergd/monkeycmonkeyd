--!strict
-- The local monkey's special moves: grab, hang, swing, let go, air-dash, and hard-landing flops.
--
-- Networking rule: everything here only ever moves THIS player's own monkey. Constraints are created on
-- this client and the result replicates through normal character physics, so moves feel instant at any ping.
--
-- States:
--   normal  the Humanoid is in control
--   hang    PlatformStand on; a rope from the root part to the grip point; a push force for swinging
--   carry   PlatformStand on for a moment after a dash or a release, so momentum isn't eaten by air control

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tags = require(ReplicatedStorage.Shared.Tags)
local CharacterContext = require(script.Parent.CharacterContext)
local RagdollController = require(script.Parent.RagdollController)

type Rig = CharacterContext.Rig

type Hang = {
	part: BasePart,
	grip: Attachment,
	rope: RopeConstraint,
	align: AlignOrientation,
	push: VectorForce,
	startedAt: number,
}

type Carry = {
	align: AlignOrientation,
	startedAt: number,
	endsAt: number,
}

local MovementController = {}

local grabHeld = false
local grabUntil = 0
local hang: Hang? = nil
local carry: Carry? = nil
local dashesLeft = Config.Dash.PerAirtime
local lastDashAt = -math.huge
local lastReleasedPart: BasePart? = nil
local lastReleasedAt = -math.huge
local fallSpeed = 0 -- fastest downward speed this airtime, for hard landings
local stateConnection: RBXScriptConnection? = nil

local grabbables: { Instance } = CollectionService:GetTagged(Tags.Grabbable)
local function refreshGrabbables()
	grabbables = CollectionService:GetTagged(Tags.Grabbable)
end

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide = true

--[[ helpers ]]

local function getAttachment(root: BasePart, name: string, position: Vector3): Attachment
	local existing = root:FindFirstChild(name)
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = root
	return attachment
end

local function flatDirection(direction: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude > 0.05 then
		return flat.Unit
	end
	local back = Vector3.new(fallback.X, 0, fallback.Z)
	if back.Magnitude > 0.05 then
		return back.Unit
	end
	return Vector3.new(0, 0, -1)
end

local function uprightFacing(direction: Vector3, root: BasePart): CFrame
	return CFrame.lookAt(Vector3.zero, flatDirection(direction, root.CFrame.LookVector))
end

local function makeUprightAlign(root: BasePart): AlignOrientation
	local align = Instance.new("AlignOrientation")
	align.Name = "MonkeyUpright"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = getAttachment(root, "MonkeyRootAttachment", Vector3.zero)
	align.Responsiveness = Config.Grab.TurnResponsiveness
	align.MaxTorque = math.huge
	align.CFrame = uprightFacing(root.CFrame.LookVector, root)
	align.Parent = root
	return align
end

local function isGrounded(rig: Rig): boolean
	if not rig.humanoid.PlatformStand and rig.humanoid.FloorMaterial ~= Enum.Material.Air then
		return true
	end
	groundParams.FilterDescendantsInstances = { rig.character }
	local result = Workspace:Raycast(rig.root.Position, Vector3.new(0, -Config.Carry.GroundCheckDistance, 0), groundParams)
	return result ~= nil
end

local function moveDirection(rig: Rig): Vector3
	local move = rig.humanoid.MoveDirection
	return Vector3.new(move.X, 0, move.Z)
end

--[[ carry ]]

local function endCarry(rig: Rig?)
	local current = carry
	if not current then
		return
	end
	carry = nil
	current.align:Destroy()
	if rig and not hang and not RagdollController.isActive() then
		rig.humanoid.PlatformStand = false
		rig.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function startCarry(rig: Rig, duration: number)
	if duration <= 0 then
		return
	end
	local now = os.clock()
	local current = carry
	if current then
		current.endsAt = math.max(current.endsAt, now + duration)
		return
	end
	carry = {
		align = makeUprightAlign(rig.root),
		startedAt = now,
		endsAt = now + duration,
	}
	rig.humanoid.PlatformStand = true
end

--[[ hang ]]

local function findGrip(rig: Rig): (BasePart?, Vector3?)
	if #grabbables == 0 then
		return nil, nil
	end
	overlapParams.FilterDescendantsInstances = grabbables

	local forward = flatDirection(rig.root.CFrame.LookVector, Vector3.new(0, 0, -1))
	local reach = rig.root.Position + Vector3.new(0, Config.Grab.ReachUp, 0) + forward * Config.Grab.ReachForward
	local now = os.clock()

	local bestPart: BasePart? = nil
	local bestPoint: Vector3? = nil
	local bestDistance = math.huge
	for _, part in Workspace:GetPartBoundsInRadius(reach, Config.Grab.Radius, overlapParams) do
		if part == lastReleasedPart and now - lastReleasedAt < Config.Grab.SamePartCooldown then
			continue
		end
		local point = part:GetClosestPointOnSurface(reach)
		local distance = (point - reach).Magnitude
		if distance <= Config.Grab.Radius and distance < bestDistance then
			bestPart, bestPoint, bestDistance = part, point, distance
		end
	end
	return bestPart, bestPoint
end

local function startHang(rig: Rig, part: BasePart, point: Vector3)
	endCarry(nil)

	local grip = Instance.new("Attachment")
	grip.Name = "MonkeyGrip"
	grip.Position = part.CFrame:PointToObjectSpace(point)
	grip.Parent = part

	local top = getAttachment(rig.root, "MonkeyHangTop", Vector3.new(0, rig.root.Size.Y / 2, 0))

	local rope = Instance.new("RopeConstraint")
	rope.Name = "MonkeyHangRope"
	rope.Attachment0 = top
	rope.Attachment1 = grip
	rope.Length = math.max((point - top.WorldPosition).Magnitude, Config.Grab.HangLength)
	rope.WinchEnabled = true
	rope.WinchTarget = Config.Grab.HangLength
	rope.WinchSpeed = Config.Grab.WinchSpeed
	rope.WinchResponsiveness = Config.Grab.WinchResponsiveness
	rope.WinchForce = rig.root.AssemblyMass * Workspace.Gravity * 4
	rope.Visible = false
	rope.Parent = rig.root

	local push = Instance.new("VectorForce")
	push.Name = "MonkeySwingPush"
	push.Attachment0 = getAttachment(rig.root, "MonkeyRootAttachment", Vector3.zero)
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.ApplyAtCenterOfMass = true
	push.Force = Vector3.zero
	push.Parent = rig.root

	rig.humanoid.PlatformStand = true
	hang = {
		part = part,
		grip = grip,
		rope = rope,
		align = makeUprightAlign(rig.root),
		push = push,
		startedAt = os.clock(),
	}
	dashesLeft = Config.Dash.PerAirtime
	fallSpeed = 0
	grabUntil = 0

	rig.character:SetAttribute("Hanging", true)
	Remotes.HangState:FireServer(true)
end

local function destroyHang(): Hang?
	local current = hang
	if not current then
		return nil
	end
	hang = nil
	current.rope:Destroy()
	current.align:Destroy()
	current.push:Destroy()
	current.grip:Destroy()
	lastReleasedPart = current.part
	lastReleasedAt = os.clock()
	Remotes.HangState:FireServer(false)
	return current
end

local function releaseHang(rig: Rig, jumped: boolean)
	if not destroyHang() then
		return
	end
	rig.character:SetAttribute("Hanging", false)

	local velocity = rig.root.AssemblyLinearVelocity
	local boost = Config.Grab.ReleaseBoost
	local launch = Vector3.new(velocity.X * boost, if velocity.Y > 0 then velocity.Y * boost else velocity.Y, velocity.Z * boost)
	if jumped then
		local forward = flatDirection(moveDirection(rig), rig.root.CFrame.LookVector)
		launch = Vector3.new(launch.X, math.max(launch.Y, 0) + Config.Grab.ReleaseJumpUp, launch.Z)
			+ forward * Config.Grab.ReleaseJumpForward
	end

	-- Stay in "carry" for a moment so the Humanoid's air control doesn't cancel the swing momentum.
	startCarry(rig, Config.Carry.AfterRelease)
	rig.root.AssemblyLinearVelocity = launch
end

--[[ reset: used by ragdoll, respawn and character changes ]]

function MovementController.reset()
	local rig = CharacterContext.get()
	if destroyHang() and rig then
		rig.character:SetAttribute("Hanging", false)
	end
	local current = carry
	if current then
		carry = nil
		current.align:Destroy()
	end
	if rig then
		rig.humanoid.PlatformStand = false
	end
	grabUntil = 0
	fallSpeed = 0
	dashesLeft = Config.Dash.PerAirtime
end

--[[ input entry points (InputController calls these) ]]

function MovementController.grabPressed()
	grabHeld = true
	local rig = CharacterContext.get()
	if hang and rig then
		releaseHang(rig, false) -- grab again while hanging = drop
		grabHeld = false
		return
	end
	grabUntil = os.clock() + Config.Grab.Buffer
end

function MovementController.grabReleased()
	grabHeld = false
end

function MovementController.jumpPressed()
	local current = hang
	local rig = CharacterContext.get()
	if not current or not rig then
		return
	end
	if os.clock() - current.startedAt < Config.Grab.JumpReleaseDelay then
		return
	end
	releaseHang(rig, true)
end

function MovementController.dash()
	local rig = CharacterContext.get()
	if not rig or RagdollController.isActive() or rig.humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now - lastDashAt < Config.Dash.Cooldown or dashesLeft <= 0 then
		return
	end

	if hang then
		releaseHang(rig, false) -- dashing out of a hang
	elseif isGrounded(rig) then
		return -- the dash is an air move
	end

	dashesLeft -= 1
	lastDashAt = now
	local direction = flatDirection(moveDirection(rig), rig.root.CFrame.LookVector)
	local velocity = rig.root.AssemblyLinearVelocity
	startCarry(rig, Config.Carry.AfterDash)
	rig.root.AssemblyLinearVelocity = direction * Config.Dash.Speed
		+ Vector3.new(0, math.max(velocity.Y, 0) + Config.Dash.Up, 0)
end

function MovementController.isHanging(): boolean
	return hang ~= nil
end

--[[ per-frame ]]

local function update()
	local rig = CharacterContext.get()
	if not rig or RagdollController.isActive() or rig.humanoid.Health <= 0 then
		return
	end
	local now = os.clock()

	local current = hang
	if current then
		local tooFar = (current.grip.WorldPosition - rig.root.Position).Magnitude > Config.Grab.BreakDistance
		if not current.part:IsDescendantOf(Workspace) or tooFar then
			releaseHang(rig, false)
			return
		end
		local move = moveDirection(rig)
		current.push.Force = move * (Config.Grab.SwingAccel * rig.root.AssemblyMass)
		current.align.Responsiveness = Config.Grab.TurnResponsiveness
		if move.Magnitude > 0.1 then
			current.align.CFrame = uprightFacing(move, rig.root)
		end
		return
	end

	if grabHeld or now < grabUntil then
		local part, point = findGrip(rig)
		if part and point then
			startHang(rig, part, point)
			return
		end
	end

	local currentCarry = carry
	if currentCarry then
		local move = moveDirection(rig)
		if move.Magnitude > 0.1 then
			currentCarry.align.CFrame = uprightFacing(move, rig.root)
		end
		local landed = now - currentCarry.startedAt > 0.1 and isGrounded(rig)
		if now >= currentCarry.endsAt or landed then
			endCarry(rig)
		end
	end

	-- Airtime bookkeeping for dashes and hard landings.
	if carry == nil and rig.humanoid.FloorMaterial ~= Enum.Material.Air then
		dashesLeft = Config.Dash.PerAirtime
	else
		fallSpeed = math.max(fallSpeed, -rig.root.AssemblyLinearVelocity.Y)
	end
end

local function onRigChanged()
	if stateConnection then
		stateConnection:Disconnect()
		stateConnection = nil
	end
	-- The old grip attachment lives on the branch, not the character, so clean it up explicitly.
	local old = hang
	if old then
		hang = nil
		old.grip:Destroy()
	end
	carry = nil
	grabUntil = 0
	fallSpeed = 0
	dashesLeft = Config.Dash.PerAirtime

	local rig = CharacterContext.get()
	if not rig then
		return
	end
	-- Roblox's ladder climbing grabs onto stacked branches and vines on its own. Monkeys climb by grabbing.
	rig.humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	stateConnection = rig.humanoid.StateChanged:Connect(function(_old, new)
		if new == Enum.HumanoidStateType.Landed then
			local speed = fallSpeed
			fallSpeed = 0
			if speed > Config.Ragdoll.HardLandingSpeed then
				RagdollController.start(Config.Ragdoll.HardLandingTime)
			end
		end
	end)
end

function MovementController.init()
	CollectionService:GetInstanceAddedSignal(Tags.Grabbable):Connect(refreshGrabbables)
	CollectionService:GetInstanceRemovedSignal(Tags.Grabbable):Connect(refreshGrabbables)

	RagdollController.Started:Connect(MovementController.reset)
	CharacterContext.Changed:Connect(onRigChanged)
	onRigChanged()

	RunService.Heartbeat:Connect(update)
end

return MovementController
