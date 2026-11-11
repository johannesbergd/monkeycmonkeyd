--!strict
-- Builds and toggles ragdoll joints on an R15 character. Handles both joint kinds (see RigJoints):
--   classic Motor6D rigs   build() adds a disabled BallSocketConstraint next to each Motor6D;
--                          ragdolling swaps the Motor6D off and the socket on.
--   upgraded rigs          Roblox already adds enabled BallSocketConstraints ("WaistBallSocket", ...);
--                          ragdolling just switches the AnimationConstraints off. build() only fills gaps.
-- The server calls build() once per character. Both server and the owning client call setRagdolled():
-- the client so it feels instant, the server so everyone else sees it.

local RigJoints = require(script.Parent.RigJoints)

local RagdollRig = {}

local SOCKET_PREFIX = "RagdollSocket_"
local A0_PREFIX = "RagdollA0_"
local A1_PREFIX = "RagdollA1_"

-- The Root joint keeps the HumanoidRootPart attached to the body so the camera and physics owner stay sane.
local KEEP_RIGID: { [string]: boolean } = {
	Root = true,
}

type Limits = { upper: number, twistLower: number, twistUpper: number }

local DEFAULT_LIMITS: Limits = { upper = 45, twistLower = -30, twistUpper = 30 }

local LIMITS: { [string]: Limits } = {
	Neck = { upper = 35, twistLower = -45, twistUpper = 45 },
	Waist = { upper = 25, twistLower = -25, twistUpper = 25 },
	LeftShoulder = { upper = 95, twistLower = -70, twistUpper = 70 },
	RightShoulder = { upper = 95, twistLower = -70, twistUpper = 70 },
	LeftElbow = { upper = 80, twistLower = -10, twistUpper = 10 },
	RightElbow = { upper = 80, twistLower = -10, twistUpper = 10 },
	LeftHip = { upper = 70, twistLower = -30, twistUpper = 30 },
	RightHip = { upper = 70, twistLower = -30, twistUpper = 30 },
	LeftKnee = { upper = 80, twistLower = -5, twistUpper = 5 },
	RightKnee = { upper = 80, twistLower = -5, twistUpper = 5 },
}

local function eachRagdollJoint(character: Model, callback: (joint: Instance) -> ())
	for _, descendant in character:GetDescendants() do
		if RigJoints.isJoint(descendant) and not KEEP_RIGID[descendant.Name] then
			callback(descendant)
		end
	end
end

-- The socket that holds this joint together while ragdolled: Roblox's own ("<Name>BallSocket")
-- on upgraded rigs, or the one build() made.
local function socketFor(joint: Instance): BallSocketConstraint?
	local _, part1 = RigJoints.parts(joint)
	for _, container in { joint.Parent, part1 } do
		if container then
			local builtIn = container:FindFirstChild(joint.Name .. "BallSocket")
			if builtIn and builtIn:IsA("BallSocketConstraint") then
				return builtIn
			end
			local ours = container:FindFirstChild(SOCKET_PREFIX .. joint.Name)
			if ours and ours:IsA("BallSocketConstraint") then
				return ours
			end
		end
	end
	return nil
end

-- Server only: make sure every joint has a socket.
function RagdollRig.build(character: Model)
	eachRagdollJoint(character, function(joint)
		if socketFor(joint) then
			return
		end
		local part0, part1 = RigJoints.parts(joint)
		if not part0 or not part1 then
			return
		end

		local limits = LIMITS[joint.Name] or DEFAULT_LIMITS
		local socket = Instance.new("BallSocketConstraint")
		socket.Name = SOCKET_PREFIX .. joint.Name
		socket.LimitsEnabled = true
		socket.TwistLimitsEnabled = true
		socket.UpperAngle = limits.upper
		socket.TwistLowerAngle = limits.twistLower
		socket.TwistUpperAngle = limits.twistUpper

		if joint:IsA("Motor6D") then
			local a0 = Instance.new("Attachment")
			a0.Name = A0_PREFIX .. joint.Name
			a0.CFrame = joint.C0
			a0.Parent = part0

			local a1 = Instance.new("Attachment")
			a1.Name = A1_PREFIX .. joint.Name
			a1.CFrame = joint.C1
			a1.Parent = part1

			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.Enabled = false -- classic rigs: only on while ragdolled
		elseif joint:IsA("AnimationConstraint") then
			socket.Attachment0 = joint.Attachment0
			socket.Attachment1 = joint.Attachment1
			socket.Enabled = true -- upgraded rigs: sockets stay on, like Roblox's own
		end
		socket.Parent = part1
	end)
end

-- Go limp (on = true) or get back up (on = false).
function RagdollRig.setRagdolled(character: Model, on: boolean)
	eachRagdollJoint(character, function(joint)
		local socket = socketFor(joint)
		if not socket then
			return -- never let go of a joint that has nothing to hold it together
		end
		if joint:IsA("Motor6D") then
			joint.Enabled = not on
			socket.Enabled = on
		elseif joint:IsA("AnimationConstraint") then
			joint.Enabled = not on
		end
	end)
end

function RagdollRig.isBuilt(character: Model): boolean
	local waist = RigJoints.find(character, "Waist")
	return waist ~= nil and socketFor(waist) ~= nil
end

return RagdollRig
