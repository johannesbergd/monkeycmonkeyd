--!strict
-- R15 characters come with one of two kinds of joints, and Roblox may give players either:
--   classic   Motor6D joints. The joint's frame on its first part is Motor6D.C0.
--   upgraded  AnimationConstraint joints between "RigAttachment"s, plus built-in BallSocketConstraints
--             (named e.g. "WaistBallSocket"). The joint's frame on its first part is Attachment0.CFrame.
-- This module hides the difference so the ragdoll and the wobble work on both.

local RigJoints = {}

function RigJoints.isJoint(instance: Instance): boolean
	return instance:IsA("Motor6D") or instance:IsA("AnimationConstraint")
end

-- Finds a joint by its R15 name ("Waist", "RightShoulder", ...).
function RigJoints.find(character: Model, name: string): Instance?
	for _, descendant in character:GetDescendants() do
		if descendant.Name == name and RigJoints.isJoint(descendant) then
			return descendant
		end
	end
	return nil
end

-- The joint's frame on its first part (Motor6D.C0, or AnimationConstraint.Attachment0.CFrame).
function RigJoints.readFrame(joint: Instance): CFrame?
	if joint:IsA("Motor6D") then
		return joint.C0
	elseif joint:IsA("AnimationConstraint") then
		local attachment = joint.Attachment0
		if attachment then
			return attachment.CFrame
		end
	end
	return nil
end

function RigJoints.writeFrame(joint: Instance, frame: CFrame)
	if joint:IsA("Motor6D") then
		joint.C0 = frame
	elseif joint:IsA("AnimationConstraint") then
		local attachment = joint.Attachment0
		if attachment then
			attachment.CFrame = frame
		end
	end
end

-- The two parts a joint connects.
function RigJoints.parts(joint: Instance): (BasePart?, BasePart?)
	if joint:IsA("Motor6D") then
		return joint.Part0, joint.Part1
	elseif joint:IsA("AnimationConstraint") then
		local a0, a1 = joint.Attachment0, joint.Attachment1
		local p0 = a0 and a0.Parent
		local p1 = a1 and a1.Parent
		return if p0 and p0:IsA("BasePart") then p0 else nil, if p1 and p1:IsA("BasePart") then p1 else nil
	end
	return nil, nil
end

return RigJoints
